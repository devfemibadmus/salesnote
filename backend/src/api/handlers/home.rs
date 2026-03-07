use actix_web::web::ReqData;
use actix_web::{http::StatusCode, web, Responder};
use serde::Serialize;
use std::time::Instant;

use crate::api::middlewares::auth::AuthDeviceId;
use crate::api::response::{json_error, json_ok};
use crate::api::state::AppState;
use crate::models::{AnalyticsSummary, Sale, ShopProfile};

#[derive(Debug, Serialize)]
pub struct HomeSummaryResponse {
    pub shop: ShopProfile,
    pub analytics: AnalyticsSummary,
    pub recent_sales: Vec<Sale>,
}

pub async fn home_summary(
    state: web::Data<AppState>,
    shop_id: ReqData<i64>,
    device_id: ReqData<AuthDeviceId>,
) -> impl Responder {
    let started = Instant::now();

    let data = match AnalyticsSummary::authorized_home_summary(
        &state.pool,
        *shop_id,
        (*device_id).0,
    )
    .await
    {
        Ok(Some(v)) => v,
        Ok(None) => return json_error(StatusCode::UNAUTHORIZED, "unauthorized"),
        Err(e) => {
            tracing::error!("home summary query error: {}", e);
            return json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Server error. Please try again.",
            );
        }
    };

    let total_ms = started.elapsed().as_millis();

    tracing::debug!("home_summary timing: single_query_total={}ms", total_ms,);

    let mut shop = data.shop;
    if let Err(resp) = crate::api::media::resolve_shop_media(&state, &mut shop) {
        return resp;
    }

    json_ok(HomeSummaryResponse {
        shop,
        analytics: data.analytics,
        recent_sales: data.recent_sales,
    })
}
