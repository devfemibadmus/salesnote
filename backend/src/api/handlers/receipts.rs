use actix_web::web::ReqData;
use actix_web::{http::StatusCode, web, Responder};

use crate::models::{
    IdPayload, Receipt, ReceiptCreateInput, ReceiptDetail, ReceiptInsertPayload, Sale, ShopProfile,
    Signature,
};
use crate::api::state::AppState;
use crate::api::response::{json_created, json_error, json_ok};

pub async fn create_receipt(
    state: web::Data<AppState>,
    shop_id: ReqData<i64>,
    payload: web::Json<ReceiptCreateInput>,
) -> impl Responder {
    if payload.customer_name.trim().is_empty()
        || payload.customer_email.trim().is_empty()
        || payload.customer_phone.trim().is_empty()
    {
        return json_error(
            StatusCode::BAD_REQUEST,
            "customer name, email and phone are required",
        );
    }

    let sale = match Sale::load_with_items(
        &state.pool,
        &IdPayload {
            id: payload.sale_id,
        },
    )
    .await
    {
        Ok(Some(s)) => s,
        Ok(None) => return json_error(StatusCode::NOT_FOUND, "sale not found"),
        Err(e) => {
            tracing::error!("get sale error: {}", e);
            return json_error(StatusCode::INTERNAL_SERVER_ERROR, "Server error. Please try again.");
        }
    };

    if sale.shop_id != *shop_id {
        return json_error(StatusCode::FORBIDDEN, "shop mismatch");
    }

    let signature = match Signature::get(&state.pool, &IdPayload { id: payload.signature_id }).await {
        Ok(Some(sig)) => sig,
        Ok(None) => return json_error(StatusCode::NOT_FOUND, "signature not found"),
        Err(e) => {
            tracing::error!("get signature error: {}", e);
            return json_error(StatusCode::INTERNAL_SERVER_ERROR, "Server error. Please try again.");
        }
    };
    if signature.shop_id != *shop_id {
        return json_error(StatusCode::FORBIDDEN, "shop mismatch");
    }

    let receipt = match Receipt::insert(
        &state.pool,
        &ReceiptInsertPayload {
            shop_id: *shop_id,
            input: payload.into_inner(),
        },
    )
    .await
    {
        Ok(r) => r,
        Err(e) => {
            tracing::error!("insert receipt error: {}", e);
            return json_error(StatusCode::INTERNAL_SERVER_ERROR, "Server error. Please try again.");
        }
    };

    let shop = match ShopProfile::get(&state.pool, &IdPayload { id: *shop_id }).await {
        Ok(Some(s)) => s,
        Ok(None) => return json_error(StatusCode::NOT_FOUND, "shop not found"),
        Err(e) => {
            tracing::error!("get shop error: {}", e);
            return json_error(StatusCode::INTERNAL_SERVER_ERROR, "Server error. Please try again.");
        }
    };

    json_created(ReceiptDetail {
        receipt,
        shop,
        sale,
        signature: Some(signature),
    })
}

pub async fn list_receipts_handler(
    state: web::Data<AppState>,
    shop_id: ReqData<i64>,
) -> impl Responder {
    match Receipt::list(&state.pool, &IdPayload { id: *shop_id }).await {
        Ok(items) => json_ok(items),
        Err(e) => {
            tracing::error!("list receipts error: {}", e);
            json_error(StatusCode::INTERNAL_SERVER_ERROR, "Server error. Please try again.")
        }
    }
}

pub async fn get_receipt(
    state: web::Data<AppState>,
    shop_id: ReqData<i64>,
    receipt_id: web::Path<i64>,
) -> impl Responder {
    let receipt = match Receipt::find(&state.pool, &IdPayload { id: *receipt_id }).await {
        Ok(Some(r)) => r,
        Ok(None) => return json_error(StatusCode::NOT_FOUND, "not found"),
        Err(e) => {
            tracing::error!("get receipt error: {}", e);
            return json_error(StatusCode::INTERNAL_SERVER_ERROR, "Server error. Please try again.");
        }
    };

    if receipt.shop_id != *shop_id {
        return json_error(StatusCode::FORBIDDEN, "shop mismatch");
    }

    let shop = match ShopProfile::get(&state.pool, &IdPayload { id: *shop_id }).await {
        Ok(Some(s)) => s,
        Ok(None) => return json_error(StatusCode::NOT_FOUND, "shop not found"),
        Err(e) => {
            tracing::error!("get shop error: {}", e);
            return json_error(StatusCode::INTERNAL_SERVER_ERROR, "Server error. Please try again.");
        }
    };

    let sale = match Sale::load_with_items(
        &state.pool,
        &IdPayload {
            id: receipt.sale_id,
        },
    )
    .await
    {
        Ok(Some(s)) => s,
        Ok(None) => return json_error(StatusCode::NOT_FOUND, "sale not found"),
        Err(e) => {
            tracing::error!("get sale error: {}", e);
            return json_error(StatusCode::INTERNAL_SERVER_ERROR, "Server error. Please try again.");
        }
    };

    let signature = match Signature::get(&state.pool, &IdPayload { id: receipt.signature_id }).await {
        Ok(sig) => sig,
        Err(e) => {
            tracing::error!("get signature error: {}", e);
            return json_error(StatusCode::INTERNAL_SERVER_ERROR, "Server error. Please try again.");
        }
    };

    json_ok(ReceiptDetail {
        receipt,
        shop,
        sale,
        signature,
    })
}
