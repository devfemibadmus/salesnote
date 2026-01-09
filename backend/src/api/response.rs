use actix_web::{http::StatusCode, HttpResponse};
use serde::Serialize;

#[derive(Debug, Serialize)]
pub struct ApiError {
    pub message: String,
}

#[derive(Debug, Serialize)]
pub struct ApiResponse<T>
where
    T: Serialize,
{
    pub success: bool,
    pub data: Option<T>,
    pub error: Option<ApiError>,
}

impl<T> ApiResponse<T>
where
    T: Serialize,
{
    pub fn ok(data: T) -> Self {
        Self {
            success: true,
            data: Some(data),
            error: None,
        }
    }

    pub fn err(message: &str) -> Self {
        Self {
            success: false,
            data: None,
            error: Some(ApiError {
                message: message.to_string(),
            }),
        }
    }
}

pub fn json_ok<T>(data: T) -> HttpResponse
where
    T: Serialize,
{
    HttpResponse::Ok().json(ApiResponse::ok(data))
}

pub fn json_created<T>(data: T) -> HttpResponse
where
    T: Serialize,
{
    HttpResponse::Created().json(ApiResponse::ok(data))
}

pub fn json_empty() -> HttpResponse {
    HttpResponse::Ok().json(ApiResponse::ok(serde_json::Value::Null))
}

pub fn json_error(status: StatusCode, message: &str) -> HttpResponse {
    HttpResponse::build(status).json(ApiResponse::<serde_json::Value>::err(message))
}
