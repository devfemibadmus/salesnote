use actix_web::http::StatusCode;

use crate::api::response::json_error;
use crate::api::state::AppState;
use crate::models::{AuthLoginResponse, ReceiptDetail, SettingsSummary, ShopProfile, Signature};

pub fn resolve_shop_media(
    state: &AppState,
    shop: &mut ShopProfile,
) -> Result<(), actix_web::HttpResponse> {
    if let Some(value) = shop.logo_url.as_deref() {
        shop.logo_url = Some(resolve_media_value(state, value)?);
    }
    Ok(())
}

pub fn resolve_signature_media(
    state: &AppState,
    signature: &mut Signature,
) -> Result<(), actix_web::HttpResponse> {
    signature.image_url = resolve_media_value(state, &signature.image_url)?;
    Ok(())
}

pub fn resolve_signature_list_media(
    state: &AppState,
    items: &mut [Signature],
) -> Result<(), actix_web::HttpResponse> {
    for item in items {
        resolve_signature_media(state, item)?;
    }
    Ok(())
}

pub fn resolve_auth_login_response(
    state: &AppState,
    response: &mut AuthLoginResponse,
) -> Result<(), actix_web::HttpResponse> {
    resolve_shop_media(state, &mut response.shop)
}

pub fn resolve_settings_summary(
    state: &AppState,
    summary: &mut SettingsSummary,
) -> Result<(), actix_web::HttpResponse> {
    resolve_shop_media(state, &mut summary.shop)
}

pub fn resolve_receipt_detail(
    state: &AppState,
    detail: &mut ReceiptDetail,
) -> Result<(), actix_web::HttpResponse> {
    resolve_shop_media(state, &mut detail.shop)?;
    if let Some(signature) = detail.signature.as_mut() {
        resolve_signature_media(state, signature)?;
    }
    Ok(())
}

fn resolve_media_value(state: &AppState, value: &str) -> Result<String, actix_web::HttpResponse> {
    let key_path = state
        .gcs_key_json_path
        .as_deref()
        .filter(|v| !v.trim().is_empty())
        .unwrap_or("firebase-adminsdk.json");

    crate::storage::gcs::resolve_media_url(key_path, value, state.gcs_signed_url_ttl_secs).map_err(
        |e| {
            tracing::error!("media resolve error: {}", e);
            json_error(StatusCode::INTERNAL_SERVER_ERROR, "media error")
        },
    )
}
