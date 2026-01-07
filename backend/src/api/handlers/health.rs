use actix_web::Responder;

use crate::models::HealthResponse;
use crate::api::response::json_ok;

pub async fn health() -> impl Responder {
    json_ok(HealthResponse { status: "ok".into() })
}
