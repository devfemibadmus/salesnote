use actix_web::web::ReqData;
use actix_web::{http::StatusCode, web, Responder};
use chrono::{DateTime, NaiveDate, Utc};
use serde::Deserialize;

use crate::api::middlewares::auth::AuthDeviceId;
use crate::api::response::{json_created, json_empty, json_error, json_ok};
use crate::api::state::AppState;
use crate::models::{
    format_currency_amount, AuthorizedSaleCreatePayload, AuthorizedSaleCreateResult,
    AuthorizedSaleDeletePayload, AuthorizedSaleDeleteResult, AuthorizedSaleGetPayload,
    AuthorizedSaleGetResult, AuthorizedSaleListPayload, AuthorizedSaleListResult,
    AuthorizedSaleUpdatePayload, AuthorizedSaleUpdateResult, DeviceSession, Sale, SaleInput,
    SaleStatus, SaleUpdateInput, ShopProfile,
};
use crate::{config::Settings, worker::notification::fcm::send_fcm_notification_with_data};

const MAX_ITEM_NAME_CHARS: usize = 20;
const MAX_SALE_TOTAL: f64 = 9_999_999_999.99;
const MIN_SALE_TOTAL: f64 = 0.0;

fn compute_grand_total(
    subtotal: f64,
    discount_amount: f64,
    vat_amount: f64,
    service_fee_amount: f64,
    delivery_fee_amount: f64,
    rounding_amount: f64,
    other_amount: f64,
) -> f64 {
    subtotal - discount_amount
        + vat_amount
        + service_fee_amount
        + delivery_fee_amount
        + rounding_amount
        + other_amount
}

fn validate_adjustments(
    discount_amount: f64,
    vat_amount: f64,
    service_fee_amount: f64,
    delivery_fee_amount: f64,
    rounding_amount: f64,
    other_amount: f64,
) -> Result<(), &'static str> {
    let values = [
        discount_amount,
        vat_amount,
        service_fee_amount,
        delivery_fee_amount,
        rounding_amount,
        other_amount,
    ];
    if values.iter().any(|v| !v.is_finite()) {
        return Err("invalid adjustment amount");
    }
    if discount_amount < 0.0 {
        return Err("discount must be zero or greater");
    }
    if vat_amount < 0.0 {
        return Err("vat must be zero or greater");
    }
    if service_fee_amount < 0.0 {
        return Err("service fee must be zero or greater");
    }
    if delivery_fee_amount < 0.0 {
        return Err("delivery fee must be zero or greater");
    }
    Ok(())
}

fn validate_sale_items_and_total(input: &SaleInput) -> Result<(), &'static str> {
    if input.items.is_empty() {
        return Err("items required");
    }

    let mut total = 0.0_f64;
    for item in &input.items {
        let name = item.product_name.trim();
        if name.is_empty() {
            return Err("item name required");
        }
        if name.chars().count() > MAX_ITEM_NAME_CHARS {
            return Err("item name must not be more than 20 characters");
        }

        total += item.quantity * item.unit_price;
        if !total.is_finite() || total > MAX_SALE_TOTAL {
            return Err("sale total must not be more than 9,999,999,999.99");
        }
    }

    if let Err(message) = validate_adjustments(
        input.discount_amount,
        input.vat_amount,
        input.service_fee_amount,
        input.delivery_fee_amount,
        input.rounding_amount,
        input.other_amount,
    ) {
        return Err(message);
    }

    let grand_total = compute_grand_total(
        total,
        input.discount_amount,
        input.vat_amount,
        input.service_fee_amount,
        input.delivery_fee_amount,
        input.rounding_amount,
        input.other_amount,
    );
    if !grand_total.is_finite() {
        return Err("sale total must be a valid number");
    }
    if grand_total < MIN_SALE_TOTAL {
        return Err("sale total must be zero or greater");
    }
    if grand_total > MAX_SALE_TOTAL {
        return Err("sale total must not be more than 9,999,999,999.99");
    }

    Ok(())
}

#[derive(Debug, Deserialize)]
pub struct SalesListQuery {
    pub page: Option<i64>,
    pub per_page: Option<i64>,
    pub include_items: Option<bool>,
    pub status: Option<String>,
    pub q: Option<String>,
    pub start_date: Option<String>,
    pub end_date: Option<String>,
}

pub async fn list_sales(
    state: web::Data<AppState>,
    shop_id: ReqData<i64>,
    device_id: ReqData<AuthDeviceId>,
    query: web::Query<SalesListQuery>,
) -> impl Responder {
    let page_value = query.page.unwrap_or(1).max(1);
    let per_page_value = query.per_page.unwrap_or(50).clamp(1, 200);
    let include_items = query.include_items.unwrap_or(false);
    let status = query
        .status
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(|value| match value.to_ascii_lowercase().as_str() {
            "invoice" => SaleStatus::Invoice,
            _ => SaleStatus::Paid,
        });
    let search_query = query.q.as_deref().map(str::trim).and_then(|value| {
        if value.is_empty() {
            None
        } else {
            Some(value.to_string())
        }
    });

    let start_date = query
        .start_date
        .as_deref()
        .and_then(|s| NaiveDate::parse_from_str(s, "%Y-%m-%d").ok());
    let end_date = query
        .end_date
        .as_deref()
        .and_then(|s| NaiveDate::parse_from_str(s, "%Y-%m-%d").ok());

    match Sale::list_authorized_paged(
        &state.pool,
        &AuthorizedSaleListPayload {
            shop_id: *shop_id,
            device_id: (*device_id).0,
            page: page_value,
            per_page: per_page_value,
            include_items,
            status,
            search_query,
            start_date,
            end_date,
        },
    )
    .await
    {
        Ok(AuthorizedSaleListResult::Unauthorized) => {
            json_error(StatusCode::UNAUTHORIZED, "unauthorized")
        }
        Ok(AuthorizedSaleListResult::Sales(sales)) => json_ok(sales),
        Err(e) => {
            tracing::error!("list sales error: {}", e);
            json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Server error. Please try again.",
            )
        }
    }
}

pub async fn create_sale(
    state: web::Data<AppState>,
    shop_id: ReqData<i64>,
    device_id: ReqData<AuthDeviceId>,
    payload: web::Json<SaleInput>,
) -> impl Responder {
    if let Err(message) = validate_sale_items_and_total(&payload) {
        return json_error(StatusCode::BAD_REQUEST, message);
    }

    if payload.customer_name.trim().is_empty() || payload.customer_contact.trim().is_empty() {
        return json_error(
            StatusCode::BAD_REQUEST,
            "customer name and contact are required",
        );
    }

    let input = payload.into_inner();
    let custom_created_at = if let Some(created_at) = input.created_at.as_ref() {
        match DateTime::parse_from_rfc3339(created_at) {
            Ok(dt) => Some(dt.with_timezone(&Utc)),
            Err(_) => {
                return json_error(
                    StatusCode::BAD_REQUEST,
                    "created_at must be RFC3339 (example: 2026-02-08T12:30:00Z)",
                )
            }
        }
    } else {
        None
    };

    match Sale::create_authorized(
        &state.pool,
        &AuthorizedSaleCreatePayload {
            shop_id: *shop_id,
            device_id: (*device_id).0,
            input,
            created_at: custom_created_at,
        },
    )
    .await
    {
        Ok(AuthorizedSaleCreateResult::Unauthorized) => {
            json_error(StatusCode::UNAUTHORIZED, "unauthorized")
        }
        Ok(AuthorizedSaleCreateResult::SignatureNotFound) => {
            json_error(StatusCode::NOT_FOUND, "signature not found")
        }
        Ok(AuthorizedSaleCreateResult::ShopMismatch) => {
            json_error(StatusCode::FORBIDDEN, "shop mismatch")
        }
        Ok(AuthorizedSaleCreateResult::Created(sale)) => {
            let pool = state.pool.clone();
            let shop_id_val = *shop_id;
            let sale_id = sale.id;
            let sale_total = sale.total;
            let sale_status = sale.status;
            let customer_name = sale
                .customer_name
                .as_deref()
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(str::to_owned);
            let item_count = sale.items.len();

            actix_web::rt::spawn(async move {
                let settings = Settings::load();
                let currency_code = match ShopProfile::currency_code_by_id(&pool, shop_id_val).await
                {
                    Ok(code) => code,
                    Err(err) => {
                        tracing::warn!(
                            sale_id,
                            shop_id = shop_id_val,
                            error = %err,
                            "sale notification skipped: missing shop currency code"
                        );
                        return;
                    }
                };
                if let Ok(tokens) = DeviceSession::get_fcm_tokens_for_shop(&pool, shop_id_val).await
                {
                    if !tokens.is_empty() {
                        let (title, body, kind, id_prefix, number_prefix) = match sale_status {
                            SaleStatus::Invoice => (
                                customer_name
                                    .as_deref()
                                    .map(|name| format!("New invoice for {}", name))
                                    .unwrap_or_else(|| String::from("New invoice created")),
                                format!(
                                    "#INV-{} · {} item{} · {}",
                                    sale_id,
                                    item_count,
                                    if item_count == 1 { "" } else { "s" },
                                    format_currency_amount(sale_total, &currency_code),
                                ),
                                "new_invoice",
                                "invoice",
                                "INV",
                            ),
                            SaleStatus::Paid => (
                                customer_name
                                    .as_deref()
                                    .map(|name| format!("New sale from {}", name))
                                    .unwrap_or_else(|| String::from("New sale recorded")),
                                format!(
                                    "#REC-{} · {} item{} · {}",
                                    sale_id,
                                    item_count,
                                    if item_count == 1 { "" } else { "s" },
                                    format_currency_amount(sale_total, &currency_code),
                                ),
                                "new_sale",
                                "sale",
                                "REC",
                            ),
                        };
                        let extra_data = vec![
                            (String::from("id"), format!("{}_{}", id_prefix, sale_id)),
                            (String::from("sale_id"), sale_id.to_string()),
                        ];
                        for token in tokens {
                            if let Err(err) = send_fcm_notification_with_data(
                                &token,
                                title.clone(),
                                body.clone(),
                                kind,
                                extra_data.clone(),
                                &settings,
                            )
                            .await
                            {
                                tracing::warn!(
                                    sale_id,
                                    shop_id = shop_id_val,
                                    status = %number_prefix,
                                    error = %err,
                                    "sale notification send failed"
                                );
                            }
                        }
                    }
                }
            });

            json_created(sale)
        }
        Err(e) => {
            tracing::error!("create sale error: {}", e);
            json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Server error. Please try again.",
            )
        }
    }
}

pub async fn update_sale(
    state: web::Data<AppState>,
    shop_id: ReqData<i64>,
    device_id: ReqData<AuthDeviceId>,
    sale_id: web::Path<i64>,
    payload: web::Json<SaleUpdateInput>,
) -> impl Responder {
    let existing_sale = match Sale::get_authorized(
        &state.pool,
        &AuthorizedSaleGetPayload {
            shop_id: *shop_id,
            device_id: (*device_id).0,
            sale_id: *sale_id,
        },
    )
    .await
    {
        Ok(AuthorizedSaleGetResult::Unauthorized) => {
            return json_error(StatusCode::UNAUTHORIZED, "unauthorized")
        }
        Ok(AuthorizedSaleGetResult::NotFound) => {
            return json_error(StatusCode::NOT_FOUND, "not found")
        }
        Ok(AuthorizedSaleGetResult::Sale(sale)) => sale,
        Err(e) => {
            tracing::error!("get sale before update error: {}", e);
            return json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Server error. Please try again.",
            );
        }
    };

    let input = payload.into_inner();
    if let Some(items) = &input.items {
        if items.is_empty() {
            return json_error(StatusCode::BAD_REQUEST, "items required");
        }
    }
    if let Some(customer_name) = &input.customer_name {
        if customer_name.trim().is_empty() {
            return json_error(StatusCode::BAD_REQUEST, "customer name cannot be empty");
        }
    }
    if let Some(customer_contact) = &input.customer_contact {
        if customer_contact.trim().is_empty() {
            return json_error(StatusCode::BAD_REQUEST, "customer contact cannot be empty");
        }
    }
    if let Some(discount_amount) = input.discount_amount {
        if !discount_amount.is_finite() || discount_amount < 0.0 {
            return json_error(StatusCode::BAD_REQUEST, "discount must be zero or greater");
        }
    }
    if let Some(vat_amount) = input.vat_amount {
        if !vat_amount.is_finite() || vat_amount < 0.0 {
            return json_error(StatusCode::BAD_REQUEST, "vat must be zero or greater");
        }
    }
    if let Some(service_fee_amount) = input.service_fee_amount {
        if !service_fee_amount.is_finite() || service_fee_amount < 0.0 {
            return json_error(
                StatusCode::BAD_REQUEST,
                "service fee must be zero or greater",
            );
        }
    }
    if let Some(delivery_fee_amount) = input.delivery_fee_amount {
        if !delivery_fee_amount.is_finite() || delivery_fee_amount < 0.0 {
            return json_error(
                StatusCode::BAD_REQUEST,
                "delivery fee must be zero or greater",
            );
        }
    }
    if let Some(rounding_amount) = input.rounding_amount {
        if !rounding_amount.is_finite() {
            return json_error(StatusCode::BAD_REQUEST, "invalid adjustment amount");
        }
    }
    if let Some(other_amount) = input.other_amount {
        if !other_amount.is_finite() {
            return json_error(StatusCode::BAD_REQUEST, "invalid adjustment amount");
        }
    }
    match Sale::update_authorized(
        &state.pool,
        &AuthorizedSaleUpdatePayload {
            shop_id: *shop_id,
            device_id: (*device_id).0,
            sale_id: *sale_id,
            input,
        },
    )
    .await
    {
        Ok(AuthorizedSaleUpdateResult::Unauthorized) => {
            json_error(StatusCode::UNAUTHORIZED, "unauthorized")
        }
        Ok(AuthorizedSaleUpdateResult::NotFound) => json_error(StatusCode::NOT_FOUND, "not found"),
        Ok(AuthorizedSaleUpdateResult::WindowExpired) => {
            json_error(StatusCode::FORBIDDEN, "edit window expired")
        }
        Ok(AuthorizedSaleUpdateResult::SignatureNotFound) => {
            json_error(StatusCode::NOT_FOUND, "signature not found")
        }
        Ok(AuthorizedSaleUpdateResult::Updated(sale)) => {
            if existing_sale.status == SaleStatus::Invoice && sale.status == SaleStatus::Paid {
                let pool = state.pool.clone();
                let shop_id_val = *shop_id;
                let sale_id_val = sale.id;
                let sale_total = sale.total;
                let customer_name = sale
                    .customer_name
                    .as_deref()
                    .map(str::trim)
                    .filter(|value| !value.is_empty())
                    .map(str::to_owned);
                let item_count = sale.items.len();

                actix_web::rt::spawn(async move {
                    let settings = Settings::load();
                    let currency_code =
                        match ShopProfile::currency_code_by_id(&pool, shop_id_val).await {
                            Ok(code) => code,
                            Err(err) => {
                                tracing::warn!(
                                    sale_id = sale_id_val,
                                    shop_id = shop_id_val,
                                    error = %err,
                                    "invoice paid notification skipped: missing shop currency code"
                                );
                                return;
                            }
                        };
                    if let Ok(tokens) =
                        DeviceSession::get_fcm_tokens_for_shop(&pool, shop_id_val).await
                    {
                        if !tokens.is_empty() {
                            let title = customer_name
                                .as_deref()
                                .map(|name| format!("Invoice paid by {}", name))
                                .unwrap_or_else(|| String::from("Invoice marked as paid"));
                            let body = format!(
                                "#REC-{} · {} item{} · {}",
                                sale_id_val,
                                item_count,
                                if item_count == 1 { "" } else { "s" },
                                format_currency_amount(sale_total, &currency_code),
                            );
                            let extra_data = vec![
                                (String::from("id"), format!("sale_paid_{}", sale_id_val)),
                                (String::from("sale_id"), sale_id_val.to_string()),
                            ];
                            for token in tokens {
                                if let Err(err) = send_fcm_notification_with_data(
                                    &token,
                                    title.clone(),
                                    body.clone(),
                                    "invoice_paid",
                                    extra_data.clone(),
                                    &settings,
                                )
                                .await
                                {
                                    tracing::warn!(
                                        sale_id = sale_id_val,
                                        shop_id = shop_id_val,
                                        error = %err,
                                        "invoice paid notification send failed"
                                    );
                                }
                            }
                        }
                    }
                });
            }

            json_ok(sale)
        }
        Err(e) => {
            tracing::error!("update sale error: {}", e);
            json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Server error. Please try again.",
            )
        }
    }
}

pub async fn get_sale(
    state: web::Data<AppState>,
    shop_id: ReqData<i64>,
    device_id: ReqData<AuthDeviceId>,
    sale_id: web::Path<i64>,
) -> impl Responder {
    match Sale::get_authorized(
        &state.pool,
        &AuthorizedSaleGetPayload {
            shop_id: *shop_id,
            device_id: (*device_id).0,
            sale_id: *sale_id,
        },
    )
    .await
    {
        Ok(AuthorizedSaleGetResult::Unauthorized) => {
            json_error(StatusCode::UNAUTHORIZED, "unauthorized")
        }
        Ok(AuthorizedSaleGetResult::NotFound) => json_error(StatusCode::NOT_FOUND, "not found"),
        Ok(AuthorizedSaleGetResult::Sale(sale)) => json_ok(sale),
        Err(e) => {
            tracing::error!("get sale error: {}", e);
            json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Server error. Please try again.",
            )
        }
    }
}

pub async fn delete_sale(
    state: web::Data<AppState>,
    shop_id: ReqData<i64>,
    device_id: ReqData<AuthDeviceId>,
    sale_id: web::Path<i64>,
) -> impl Responder {
    match Sale::delete_authorized(
        &state.pool,
        &AuthorizedSaleDeletePayload {
            shop_id: *shop_id,
            device_id: (*device_id).0,
            sale_id: *sale_id,
        },
    )
    .await
    {
        Ok(AuthorizedSaleDeleteResult::Unauthorized) => {
            json_error(StatusCode::UNAUTHORIZED, "unauthorized")
        }
        Ok(AuthorizedSaleDeleteResult::NotFound) => json_error(StatusCode::NOT_FOUND, "not found"),
        Ok(AuthorizedSaleDeleteResult::WindowExpired) => {
            json_error(StatusCode::FORBIDDEN, "delete window expired")
        }
        Ok(AuthorizedSaleDeleteResult::Deleted) => json_empty(),
        Err(e) => {
            tracing::error!("delete sale error: {}", e);
            json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Server error. Please try again.",
            )
        }
    }
}
