use actix_web::web::ReqData;
use actix_web::{http::StatusCode, web, Responder};

use crate::api::middlewares::auth::AuthDeviceId;
use crate::api::response::{json_error, json_ok};
use crate::api::state::AppState;
use crate::models::AnalyticsSummary;

pub async fn analytics_summary(
    state: web::Data<AppState>,
    shop_id: ReqData<i64>,
    device_id: ReqData<AuthDeviceId>,
) -> impl Responder {
    match AnalyticsSummary::authorized_summary(&state.pool, *shop_id, (*device_id).0).await {
        Ok(Some(summary)) => json_ok(summary),
        Ok(None) => json_error(StatusCode::UNAUTHORIZED, "unauthorized"),
        Err(e) => {
            tracing::error!("analytics error: {}", e);
            json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Server error. Please try again.",
            )
        }
    }
}
