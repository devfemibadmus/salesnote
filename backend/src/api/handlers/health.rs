use actix_web::Responder;

use crate::api::response::json_ok;
use crate::models::HealthResponse;

pub async fn health() -> impl Responder {
    json_ok(HealthResponse {
        status: "ok".into(),
    })
}
