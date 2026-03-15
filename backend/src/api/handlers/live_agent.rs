use actix_web::web::ReqData;
use actix_web::{http::StatusCode, web, Error as ActixError, HttpRequest, HttpResponse, Responder};
use actix_ws::Message;
use futures_util::{SinkExt, StreamExt};
use iso_currency::Currency;
use serde::Serialize;
use serde_json::{json, Map, Value};
use std::sync::OnceLock;
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message as WsMessage};

use crate::api::middlewares::auth::AuthDeviceId;
use crate::api::response::{json_error, json_ok};
use crate::api::state::AppState;
use crate::models::ShopProfile;

#[derive(Debug, Serialize)]
pub struct LiveAgentSessionResponse {
    pub model: String,
    pub ephemeral_auth_token: String,
    pub session_expires_at: String,
    pub new_session_expires_at: String,
    pub reserved_token_budget: i64,
    pub tokens_used: i64,
    pub tokens_available: i64,
    pub system_instruction: String,
    pub contract: LiveAgentContract,
}

#[derive(Debug, Serialize, Clone)]
pub struct LiveAgentContract {
    pub pages: Vec<LiveAgentPage>,
    pub forms: Vec<LiveAgentForm>,
    pub actions: Vec<LiveAgentAction>,
    pub guardrails: Vec<String>,
}

#[derive(Debug, Serialize, Clone)]
pub struct LiveAgentPage {
    pub id: &'static str,
    pub title: &'static str,
    pub notes: &'static str,
}

#[derive(Debug, Serialize, Clone)]
pub struct LiveAgentForm {
    pub id: &'static str,
    pub title: &'static str,
    pub required_fields: Vec<&'static str>,
}

#[derive(Debug, Serialize, Clone)]
pub struct LiveAgentAction {
    pub name: &'static str,
    pub description: &'static str,
    pub required_fields: Vec<&'static str>,
}

static LIVE_AGENT_CONTRACT: OnceLock<LiveAgentContract> = OnceLock::new();
static LIVE_AGENT_FUNCTION_DECLARATIONS: OnceLock<Vec<Value>> = OnceLock::new();

pub async fn create_live_agent_session(
    state: web::Data<AppState>,
    shop_id: ReqData<i64>,
    device_id: ReqData<AuthDeviceId>,
) -> impl Responder {
    if state.gemini_api_key.trim().is_empty() {
        return json_error(
            StatusCode::SERVICE_UNAVAILABLE,
            "Live cashier is not configured yet.",
        );
    }
    if state.gemini_live_model.trim().is_empty() {
        return json_error(
            StatusCode::SERVICE_UNAVAILABLE,
            "Live cashier model is not configured yet.",
        );
    }
    if let Some(message) = unsupported_live_model_message(state.gemini_live_model.trim()) {
        return json_error(StatusCode::SERVICE_UNAVAILABLE, message);
    }

    let balance =
        match ShopProfile::live_agent_balance_authorized(&state.pool, *shop_id, (*device_id).0)
            .await
        {
            Ok(Some(balance)) => balance,
            Ok(None) => return json_error(StatusCode::UNAUTHORIZED, "unauthorized"),
            Err(err) => {
                tracing::error!("live_agent session balance error: {}", err);
                return json_error(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "Server error. Please try again.",
                );
            }
        };
    let currency_code = ShopProfile::currency_code_by_id(&state.pool, *shop_id)
        .await
        .unwrap_or_else(|_| "NGN".to_string());

    json_ok(LiveAgentSessionResponse {
        model: state.gemini_live_model.clone(),
        ephemeral_auth_token: String::new(),
        session_expires_at: String::new(),
        new_session_expires_at: String::new(),
        reserved_token_budget: 0,
        tokens_used: balance.tokens_used,
        tokens_available: balance.tokens_available,
        system_instruction: live_agent_system_instruction(&currency_code),
        contract: cached_live_agent_contract().clone(),
    })
}

pub async fn connect_live_agent_socket(
    req: HttpRequest,
    body: web::Payload,
    state: web::Data<AppState>,
    shop_id: ReqData<i64>,
    device_id: ReqData<AuthDeviceId>,
) -> Result<HttpResponse, ActixError> {
    if state.gemini_api_key.trim().is_empty() {
        return Ok(json_error(
            StatusCode::SERVICE_UNAVAILABLE,
            "Live cashier is not configured yet.",
        ));
    }
    if state.gemini_live_model.trim().is_empty() {
        return Ok(json_error(
            StatusCode::SERVICE_UNAVAILABLE,
            "Live cashier model is not configured yet.",
        ));
    }
    if let Some(message) = unsupported_live_model_message(state.gemini_live_model.trim()) {
        return Ok(json_error(StatusCode::SERVICE_UNAVAILABLE, message));
    }

    match ShopProfile::live_agent_balance_authorized(&state.pool, *shop_id, (*device_id).0).await {
        Ok(Some(_)) => {}
        Ok(None) => return Ok(json_error(StatusCode::UNAUTHORIZED, "unauthorized")),
        Err(err) => {
            tracing::error!("live_agent socket balance error: {}", err);
            return Ok(json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Server error. Please try again.",
            ));
        }
    }

    let (response, session, msg_stream) = actix_ws::handle(&req, body)?;
    let app_state = state.get_ref().clone();
    let current_shop_id = *shop_id;
    let current_device_id = (*device_id).0;

    actix_web::rt::spawn(async move {
        if let Err(err) = run_live_agent_proxy(
            session,
            msg_stream,
            app_state,
            current_shop_id,
            current_device_id,
        )
        .await
        {
            tracing::error!("live_agent proxy error: {}", err);
        }
    });

    Ok(response)
}

async fn run_live_agent_proxy(
    mut client_session: actix_ws::Session,
    mut client_stream: actix_ws::MessageStream,
    state: AppState,
    shop_id: i64,
    device_id: i64,
) -> Result<(), String> {
    let gemini_url = format!(
        "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key={}",
        state.gemini_api_key.trim()
    );

    tracing::info!(
        "live_agent proxy connect shop_id={} device_id={}",
        shop_id,
        device_id
    );

    let (gemini_socket, _) = connect_async(&gemini_url)
        .await
        .map_err(|err| format!("gemini websocket connect error: {err}"))?;
    let (mut gemini_write, mut gemini_read) = gemini_socket.split();

    let currency_code = ShopProfile::currency_code_by_id(&state.pool, shop_id)
        .await
        .unwrap_or_else(|_| "NGN".to_string());
    let setup_payload = live_gemini_setup_payload(&state, &currency_code);
    gemini_write
        .send(WsMessage::Text(setup_payload.to_string().into()))
        .await
        .map_err(|err| format!("gemini setup send error: {err}"))?;

    loop {
        tokio::select! {
            client_msg = client_stream.next() => {
                match client_msg {
                    Some(Ok(Message::Text(text))) => {
                        if is_client_setup_message(text.as_ref()) {
                            tracing::debug!("live_agent proxy ignored client setup message");
                            continue;
                        }
                        gemini_write
                            .send(WsMessage::Text(text.to_string().into()))
                            .await
                            .map_err(|err| format!("client->gemini text relay error: {err}"))?;
                    }
                    Some(Ok(Message::Binary(bin))) => {
                        gemini_write
                            .send(WsMessage::Binary(bin.to_vec().into()))
                            .await
                            .map_err(|err| format!("client->gemini binary relay error: {err}"))?;
                    }
                    Some(Ok(Message::Ping(bytes))) => {
                        let _ = client_session.pong(&bytes).await;
                    }
                    Some(Ok(Message::Pong(_))) => {}
                    Some(Ok(Message::Continuation(_))) => {}
                    Some(Ok(Message::Nop)) => {}
                    Some(Ok(Message::Close(reason))) => {
                        let _ = gemini_write.send(WsMessage::Close(None)).await;
                        let _ = client_session.close(reason).await;
                        break;
                    }
                    Some(Err(err)) => {
                        return Err(format!("client websocket error: {err}"));
                    }
                    None => {
                        let _ = gemini_write.send(WsMessage::Close(None)).await;
                        break;
                    }
                }
            }
            gemini_msg = gemini_read.next() => {
                match gemini_msg {
                    Some(Ok(WsMessage::Text(text))) => {
                        apply_usage_from_message(&state, shop_id, device_id, text.as_ref()).await;
                        client_session
                            .text(text.to_string())
                            .await
                            .map_err(|err| format!("gemini->client text relay error: {err}"))?;
                    }
                    Some(Ok(WsMessage::Binary(bin))) => {
                        if let Ok(text) = std::str::from_utf8(&bin) {
                            apply_usage_from_message(&state, shop_id, device_id, text).await;
                            client_session
                                .binary(bin.to_vec())
                                .await
                                .map_err(|err| format!("gemini->client binary relay error: {err}"))?;
                        } else {
                            tracing::warn!(
                                "live_agent gemini binary frame was not valid utf8 shop_id={} device_id={} bytes={}",
                                shop_id,
                                device_id,
                                bin.len()
                            );
                            client_session
                                .binary(bin.to_vec())
                                .await
                                .map_err(|err| format!("gemini->client binary relay error: {err}"))?;
                        }
                    }
                    Some(Ok(WsMessage::Ping(bytes))) => {
                        let _ = gemini_write.send(WsMessage::Pong(bytes)).await;
                    }
                    Some(Ok(WsMessage::Pong(_))) => {}
                    Some(Ok(WsMessage::Close(reason))) => {
                        tracing::info!("live_agent gemini close shop_id={} device_id={} reason={:?}", shop_id, device_id, reason);
                        let _ = client_session.close(None).await;
                        break;
                    }
                    Some(Ok(WsMessage::Frame(_))) => {}
                    Some(Err(err)) => {
                        return Err(format!("gemini websocket error: {err}"));
                    }
                    None => {
                        let _ = client_session.close(None).await;
                        break;
                    }
                }
            }
        }
    }

    Ok(())
}

async fn apply_usage_from_message(state: &AppState, shop_id: i64, device_id: i64, raw: &str) {
    let Ok(decoded) = serde_json::from_str::<Value>(raw) else {
        return;
    };

    let turn_complete = decoded
        .get("serverContent")
        .and_then(|value| value.get("turnComplete"))
        .and_then(Value::as_bool)
        .unwrap_or(false);
    let total_token_count = decoded
        .get("usageMetadata")
        .and_then(|value| value.get("totalTokenCount"))
        .and_then(Value::as_i64)
        .unwrap_or(0);

    if !turn_complete || total_token_count <= 0 {
        return;
    }

    match ShopProfile::apply_live_agent_usage_authorized(
        &state.pool,
        shop_id,
        device_id,
        total_token_count,
    )
    .await
    {
        Ok(Some(balance)) => {
            tracing::info!(
                "live_agent usage applied shop_id={} device_id={} tokens={} used={} available={}",
                shop_id,
                device_id,
                total_token_count,
                balance.tokens_used,
                balance.tokens_available
            );
        }
        Ok(None) => {
            tracing::warn!(
                "live_agent usage skipped for unauthorized shop_id={} device_id={} tokens={}",
                shop_id,
                device_id,
                total_token_count
            );
        }
        Err(err) => {
            tracing::error!(
                "live_agent usage apply error shop_id={} device_id={} tokens={} error={}",
                shop_id,
                device_id,
                total_token_count,
                err
            );
        }
    }
}

fn is_client_setup_message(raw: &str) -> bool {
    serde_json::from_str::<Value>(raw)
        .ok()
        .and_then(|value| value.get("setup").cloned())
        .is_some()
}

fn live_gemini_setup_payload(state: &AppState, currency_code: &str) -> Value {
    json!({
        "setup": {
            "model": format!("models/{}", state.gemini_live_model.trim()),
            "generationConfig": {
                "responseModalities": ["AUDIO"],
                "thinkingConfig": {
                    "thinkingBudget": 0
                },
                "mediaResolution": "MEDIA_RESOLUTION_MEDIUM",
                "speechConfig": {
                    "voiceConfig": {
                        "prebuiltVoiceConfig": {
                            "voiceName": "Zephyr"
                        }
                    }
                },
            },
            "contextWindowCompression": {
                "triggerTokens": 104857,
                "slidingWindow": {
                    "targetTokens": 52428
                }
            },
            "inputAudioTranscription": {},
            "outputAudioTranscription": {},
            "systemInstruction": {
                "parts": [
                    {
                        "text": live_agent_system_instruction(currency_code)
                    }
                ]
            },
            "tools": [
                {
                    "functionDeclarations": cached_function_declarations().clone()
                }
            ]
        }
    })
}

fn cached_live_agent_contract() -> &'static LiveAgentContract {
    LIVE_AGENT_CONTRACT.get_or_init(live_agent_contract)
}

fn cached_function_declarations() -> &'static Vec<Value> {
    LIVE_AGENT_FUNCTION_DECLARATIONS
        .get_or_init(|| build_function_declarations(cached_live_agent_contract()))
}

fn build_function_declarations(contract: &LiveAgentContract) -> Vec<Value> {
    contract
        .actions
        .iter()
        .map(|action| {
            json!({
                "name": action.name,
                "description": action.description,
                "parameters": {
                    "type": "OBJECT",
                    "properties": tool_properties_for_action(action.name),
                    "required": action.required_fields,
                }
            })
        })
        .collect()
}

fn tool_properties_for_action(action_name: &str) -> Value {
    let mut properties = Map::new();
    match action_name {
        "navigate" => {
            properties.insert(
                "page_id".to_string(),
                json!({"type": "STRING", "description": "Destination page id."}),
            );
        }
        "start_new_draft" => {
            properties.insert(
                "kind".to_string(),
                json!({"type": "STRING", "description": "Draft kind to start: receipt or invoice."}),
            );
        }
        "set_customer" => {
            properties.insert(
                "customer_name_or_phone".to_string(),
                json!({"type": "STRING", "description": "Customer name, phone, or email."}),
            );
            properties.insert(
                "customer_name".to_string(),
                json!({"type": "STRING", "description": "Explicit customer name if known."}),
            );
            properties.insert(
                "customer_contact".to_string(),
                json!({"type": "STRING", "description": "Explicit phone or email if known."}),
            );
        }
        "add_item" => {
            properties.insert(
                "item_id_or_name".to_string(),
                json!({"type": "STRING", "description": "Catalog item name or id."}),
            );
            properties.insert(
                "quantity".to_string(),
                json!({"type": "STRING", "description": "Quantity to add."}),
            );
            properties.insert(
                "unit_price".to_string(),
                json!({"type": "STRING", "description": "Unit price if user stated one."}),
            );
        }
        "update_item" => {
            properties.insert(
                "draft_item_id".to_string(),
                json!({"type": "STRING", "description": "Draft item index or product name."}),
            );
            properties.insert("quantity_or_price".to_string(), json!({"type": "STRING", "description": "Fallback update value if field-specific args are absent."}));
            properties.insert(
                "quantity".to_string(),
                json!({"type": "STRING", "description": "New quantity."}),
            );
            properties.insert(
                "unit_price".to_string(),
                json!({"type": "STRING", "description": "New unit price."}),
            );
            properties.insert(
                "field".to_string(),
                json!({"type": "STRING", "description": "One of quantity or unit_price."}),
            );
        }
        "remove_item" => {
            properties.insert(
                "draft_item_id".to_string(),
                json!({"type": "STRING", "description": "Draft item index or product name."}),
            );
        }
        "select_signature" => {
            properties.insert(
                "signature_id".to_string(),
                json!({"type": "STRING", "description": "Signature id to use."}),
            );
        }
        "select_bank_account" => {
            properties.insert(
                "bank_account_id".to_string(),
                json!({"type": "STRING", "description": "Bank account id to use."}),
            );
        }
        "set_charge" => {
            properties.insert("charge_type".to_string(), json!({"type": "STRING", "description": "One of discount, vat, service_fee, delivery, rounding, or other."}));
            properties.insert(
                "amount".to_string(),
                json!({"type": "STRING", "description": "Charge amount as a number string."}),
            );
            properties.insert("label".to_string(), json!({"type": "STRING", "description": "Optional label when charge_type is other."}));
        }
        "mark_invoice_paid" | "open_sale_preview" => {
            properties.insert(
                "sale_id".to_string(),
                json!({"type": "STRING", "description": "Sale or invoice id."}),
            );
        }
        "search_receipts" | "search_invoices" => {
            properties.insert(
                "customer_query".to_string(),
                json!({"type": "STRING", "description": "Customer, item, or receipt search text."}),
            );
            properties.insert(
                "date".to_string(),
                json!({"type": "STRING", "description": "Exact date in YYYY-MM-DD when provided."}),
            );
            properties.insert(
                "limit".to_string(),
                json!({"type": "STRING", "description": "Maximum matches to return."}),
            );
            properties.insert("open_first_match".to_string(), json!({"type": "BOOLEAN", "description": "Whether to open the best match automatically."}));
        }
        "query_sales_metrics" => {
            properties.insert(
                "start_date".to_string(),
                json!({"type": "STRING", "description": "Range start date in YYYY-MM-DD."}),
            );
            properties.insert(
                "end_date".to_string(),
                json!({"type": "STRING", "description": "Range end date in YYYY-MM-DD."}),
            );
            properties.insert(
                "date".to_string(),
                json!({"type": "STRING", "description": "Single exact date in YYYY-MM-DD when only one date is provided."}),
            );
            properties.insert(
                "status".to_string(),
                json!({"type": "STRING", "description": "Optional filter: all, receipt, paid, or invoice."}),
            );
            properties.insert(
                "customer_query".to_string(),
                json!({"type": "STRING", "description": "Optional customer or general search text."}),
            );
            properties.insert(
                "item_query".to_string(),
                json!({"type": "STRING", "description": "Optional product name or fragment."}),
            );
            properties.insert(
                "limit".to_string(),
                json!({"type": "STRING", "description": "Maximum matching sales to return."}),
            );
        }
        "list_saved_drafts" => {
            properties.insert(
                "kind".to_string(),
                json!({"type": "STRING", "description": "Optional filter: all, receipt, or invoice."}),
            );
            properties.insert(
                "limit".to_string(),
                json!({"type": "STRING", "description": "Maximum drafts to return."}),
            );
        }
        "search_item_sales" => {
            properties.insert(
                "item_query".to_string(),
                json!({"type": "STRING", "description": "Product name or fragment to search."}),
            );
            properties.insert(
                "date".to_string(),
                json!({"type": "STRING", "description": "Exact date in YYYY-MM-DD when provided."}),
            );
        }
        "get_fast_moving_items" | "get_slow_moving_items" => {
            properties.insert(
                "limit".to_string(),
                json!({"type": "STRING", "description": "Maximum items to return."}),
            );
        }
        _ => {}
    }
    Value::Object(properties)
}

fn unsupported_live_model_message(model: &str) -> Option<&'static str> {
    match model {
        "gemini-live-2.5-flash-preview" | "gemini-2.0-flash-live-001" | "gemini-2.5-flash" => Some(
            "Configured Gemini Live model is not supported. Update SALESNOTE__GEMINI_LIVE_MODEL.",
        ),
        _ => None,
    }
}

fn live_agent_system_instruction(currency_code: &str) -> String {
    let normalized_currency_code = currency_code.trim().to_uppercase();
    let currency_name = Currency::from_code(&normalized_currency_code)
        .map(|currency| currency.name().to_string())
        .unwrap_or_else(|| normalized_currency_code.clone());
    [
        "You are SalesNote live cashier.",
        "Speak only the final customer-facing words.",
        "No reasoning, process talk, markdown, labels, bullets, or meta phrases.",
        "Keep replies short, natural, and conversational.",
        "Acknowledge greetings and thanks warmly.",
        &format!(
            "The shop currency is {} ({})",
            currency_name, normalized_currency_code
        ),
        "Never say raw ISO currency codes aloud.",
        &format!(
            "Always pronounce the shop currency naturally as {}.",
            currency_name
        ),
        "When *_display money fields exist, use them.",
        "If a currency symbol is present, pronounce the currency naturally from that symbol.",
        "Never invent products, prices, customers, totals, IDs, dates, signatures, bank accounts, or hidden app state.",
        "Use only client context and tool results.",
        "For dashboard, sales history, item movement, saved drafts, and report questions, call the relevant tool first and answer only from tool results.",
        "Use start_receipt_draft or start_invoice_draft to begin or continue the current draft.",
        "When the user identifies the customer, call set_customer early before item edits or submit steps so the app can reuse the right saved draft.",
        "Keep updating the same draft until the user explicitly asks for a new one or a different draft type.",
        "Never create another draft for the same customer unless the user explicitly asks for a separate or fresh draft.",
        "Use start_new_draft only for an explicitly requested fresh draft.",
        "Use discard_current_draft only on explicit cancel, discard, or delete intent.",
        "After each draft tool call, inspect missing_fields.",
        "Customer phone or email is customer-provided input.",
        "Signature and bank account are shop resources, not customer-provided details.",
        "If the tool returns exactly one available signature or bank account, use it immediately.",
        "If multiple available_signatures or available_bank_accounts are returned, ask the user which one to select from the listed options.",
        "Only ask the user to add a signature or bank account when the tool shows none are available.",
        "If result=needs_input or customer_contact is missing, ask only for the missing fields or choices and wait.",
        "Required before preview or create: customer name, customer contact, at least one item, item prices, signature, and bank account for invoices.",
        "Before submit_receipt, submit_invoice, or confirm_submit_current_preview, ensure those required fields already exist.",
        "Say prepared or drafted until creation or mark-paid succeeds.",
    ]
    .join(" ")
}

fn live_agent_contract() -> LiveAgentContract {
    LiveAgentContract {
        pages: vec![
            LiveAgentPage {
                id: "home",
                title: "Home",
                notes: "Dashboard metrics and shortcuts only.",
            },
            LiveAgentPage {
                id: "sales",
                title: "Receipts",
                notes: "Paid sales history only.",
            },
            LiveAgentPage {
                id: "invoices",
                title: "Invoices",
                notes: "Unpaid invoices only.",
            },
            LiveAgentPage {
                id: "items",
                title: "Items",
                notes: "Read-only item browsing and search.",
            },
            LiveAgentPage {
                id: "settings",
                title: "Settings",
                notes: "Shop profile, signatures, banks, and live cashier tokens.",
            },
            LiveAgentPage {
                id: "new_sale",
                title: "Create",
                notes: "Draft either a receipt or an invoice.",
            },
            LiveAgentPage {
                id: "preview",
                title: "Preview",
                notes: "Final review, export, mark paid, or delete.",
            },
        ],
        forms: vec![
            LiveAgentForm {
                id: "receipt_draft",
                title: "Receipt Draft",
                required_fields: vec![
                    "sale_kind=receipt",
                    "customer_name",
                    "customer_contact",
                    "items",
                    "signature_id",
                ],
            },
            LiveAgentForm {
                id: "invoice_draft",
                title: "Invoice Draft",
                required_fields: vec![
                    "sale_kind=invoice",
                    "customer_name",
                    "customer_contact",
                    "items",
                    "signature_id",
                    "bank_account_id",
                ],
            },
        ],
        actions: vec![
            LiveAgentAction {
                name: "navigate",
                description: "Open a supported page.",
                required_fields: vec!["page_id"],
            },
            LiveAgentAction {
                name: "start_receipt_draft",
                description: "Start or continue the current receipt draft. Reuse the same customer draft whenever possible.",
                required_fields: vec![],
            },
            LiveAgentAction {
                name: "start_invoice_draft",
                description: "Start or continue the current invoice draft. Reuse the same customer draft whenever possible.",
                required_fields: vec![],
            },
            LiveAgentAction {
                name: "start_new_draft",
                description: "Start a fresh receipt or invoice draft only when the user explicitly asks for another separate draft.",
                required_fields: vec!["kind"],
            },
            LiveAgentAction {
                name: "discard_current_draft",
                description: "Discard the current draft.",
                required_fields: vec![],
            },
            LiveAgentAction {
                name: "set_customer",
                description: "Set customer details on the draft as early as possible so matching saved drafts can be reused instead of duplicated.",
                required_fields: vec!["customer_name_or_phone"],
            },
            LiveAgentAction {
                name: "add_item",
                description: "Add an item to the draft.",
                required_fields: vec!["item_id_or_name", "quantity"],
            },
            LiveAgentAction {
                name: "update_item",
                description: "Update draft item quantity or unit price.",
                required_fields: vec!["draft_item_id"],
            },
            LiveAgentAction {
                name: "remove_item",
                description: "Remove an item from the active draft.",
                required_fields: vec!["draft_item_id"],
            },
            LiveAgentAction {
                name: "select_signature",
                description: "Set the draft signature.",
                required_fields: vec!["signature_id"],
            },
            LiveAgentAction {
                name: "select_bank_account",
                description: "Set the invoice bank account.",
                required_fields: vec!["bank_account_id"],
            },
            LiveAgentAction {
                name: "set_charge",
                description: "Set a draft adjustment.",
                required_fields: vec!["charge_type", "amount"],
            },
            LiveAgentAction {
                name: "submit_receipt",
                description: "Prepare the receipt preview.",
                required_fields: vec![],
            },
            LiveAgentAction {
                name: "submit_invoice",
                description: "Prepare the invoice preview.",
                required_fields: vec![],
            },
            LiveAgentAction {
                name: "confirm_submit_current_preview",
                description: "Create the prepared preview after explicit confirmation.",
                required_fields: vec![],
            },
            LiveAgentAction {
                name: "mark_invoice_paid",
                description: "Mark an existing invoice as paid.",
                required_fields: vec!["sale_id"],
            },
            LiveAgentAction {
                name: "search_receipts",
                description: "Search paid receipts.",
                required_fields: vec![],
            },
            LiveAgentAction {
                name: "search_invoices",
                description: "Search unpaid invoices.",
                required_fields: vec![],
            },
            LiveAgentAction {
                name: "query_sales_metrics",
                description: "Fetch sales or invoice metrics for a date or range.",
                required_fields: vec![],
            },
            LiveAgentAction {
                name: "list_saved_drafts",
                description: "List saved receipt and invoice drafts.",
                required_fields: vec![],
            },
            LiveAgentAction {
                name: "open_sale_preview",
                description: "Open a specific receipt or invoice preview by sale id.",
                required_fields: vec!["sale_id"],
            },
            LiveAgentAction {
                name: "query_dashboard_summary",
                description: "Fetch dashboard summary data.",
                required_fields: vec![],
            },
            LiveAgentAction {
                name: "search_item_sales",
                description: "Fetch sales for one item.",
                required_fields: vec!["item_query"],
            },
            LiveAgentAction {
                name: "get_fast_moving_items",
                description: "Return the current fast moving items list.",
                required_fields: vec![],
            },
            LiveAgentAction {
                name: "get_slow_moving_items",
                description: "Return the current slow moving items list.",
                required_fields: vec![],
            },
        ],
        guardrails: vec![
            "Manual mode and live mode must coexist; never overwrite a manual draft silently."
                .to_string(),
            "Do not infer hidden form state. Ask when required fields are missing.".to_string(),
            "Treat preview as review-only until submit or mark-paid succeeds.".to_string(),
            "Use concise confirmations and stop once the requested app action is complete."
                .to_string(),
        ],
    }
}
