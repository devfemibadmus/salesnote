use actix_multipart::Multipart;
use actix_web::http::StatusCode;
use actix_web::web::ReqData;
use actix_web::{web, HttpResponse, Responder};
use argon2::PasswordHasher;
use futures_util::StreamExt;
use serde::Serialize;
use std::path::{Path, PathBuf};

use crate::api::response::{json_empty, json_error, json_ok};
use crate::api::state::AppState;
use crate::api::middlewares::auth::AuthDeviceId;
use crate::models::{
    AuthorizedSettingsPayload, AuthorizedShopPayload, AuthorizedShopUpdatePayload, DeviceSession,
    ShopProfile, ShopUpdateInput, SettingsSummary,
};

#[derive(Debug, serde::Deserialize)]
pub struct FcmSubscribeInput {
    pub fcm_token: Option<String>,
}

const MAX_IMAGE_SIZE: usize = 5 * 1024 * 1024;

#[derive(Debug, Serialize)]
pub struct SettingsSummaryResponse {
    pub shop: ShopProfile,
    pub devices: Vec<DeviceSession>,
    pub current_device_push_enabled: bool,
}

fn extension_from_mime(mime: &mime::Mime) -> Option<&'static str> {
    match (mime.type_().as_str(), mime.subtype().as_str()) {
        ("image", "jpeg") => Some("jpg"),
        ("image", "jpg") => Some("jpg"),
        ("image", "pjpeg") => Some("jpg"),
        ("image", "jfif") => Some("jpg"),
        ("image", "png") => Some("png"),
        _ => None,
    }
}

fn extension_from_filename(filename: &str) -> Option<&'static str> {
    let ext = filename.rsplit('.').next()?.to_ascii_lowercase();
    match ext.as_str() {
        "jpg" | "jpeg" => Some("jpg"),
        "png" => Some("png"),
        _ => None,
    }
}

async fn read_text_field(field: &mut actix_multipart::Field) -> Result<String, HttpResponse> {
    let mut bytes = Vec::new();
    while let Some(chunk) = field.next().await {
        let chunk = match chunk {
            Ok(c) => c,
            Err(_) => {
                return Err(json_error(
                    actix_web::http::StatusCode::BAD_REQUEST,
                    "invalid field",
                ))
            }
        };
        bytes.extend_from_slice(&chunk);
        if bytes.len() > MAX_IMAGE_SIZE {
            return Err(json_error(
                actix_web::http::StatusCode::BAD_REQUEST,
                "field too large",
            ));
        }
    }
    String::from_utf8(bytes)
        .map(|s| s.trim().to_string())
        .map_err(|_| json_error(actix_web::http::StatusCode::BAD_REQUEST, "invalid text"))
}

async fn read_file_field(
    field: &mut actix_multipart::Field,
    dest_path: &Path,
) -> Result<(), HttpResponse> {
    let mut size = 0usize;
    let mut file_bytes = Vec::new();
    while let Some(chunk) = field.next().await {
        let chunk = match chunk {
            Ok(c) => c,
            Err(_) => {
                return Err(json_error(
                    actix_web::http::StatusCode::BAD_REQUEST,
                    "invalid file",
                ))
            }
        };
        size += chunk.len();
        if size > MAX_IMAGE_SIZE {
            return Err(json_error(
                actix_web::http::StatusCode::BAD_REQUEST,
                "image too large",
            ));
        }
        file_bytes.extend_from_slice(&chunk);
    }
    if let Some(parent) = dest_path.parent() {
        if std::fs::create_dir_all(parent).is_err() {
            return Err(json_error(
                actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
                "storage error",
            ));
        }
    }
    if std::fs::write(dest_path, &file_bytes).is_err() {
        return Err(json_error(
            actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
            "storage error",
        ));
    }
    Ok(())
}

pub async fn get_my_shop(
    state: web::Data<AppState>,
    shop_id: ReqData<i64>,
    device_id: ReqData<AuthDeviceId>,
) -> impl Responder {
    match ShopProfile::get_authorized(
        &state.pool,
        &AuthorizedShopPayload {
            shop_id: *shop_id,
            device_id: (*device_id).0,
        },
    )
    .await
    {
        Ok(Some(shop)) => json_ok(shop),
        Ok(None) => json_error(actix_web::http::StatusCode::UNAUTHORIZED, "unauthorized"),
        Err(e) => {
            tracing::error!("get shop error: {}", e);
            json_error(
                actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
                "Server error. Please try again.",
            )
        }
    }
}

pub async fn get_settings_summary(
    state: web::Data<AppState>,
    shop_id: ReqData<i64>,
    device_id: ReqData<AuthDeviceId>,
) -> impl Responder {
    match ShopProfile::settings_summary_authorized(
        &state.pool,
        &AuthorizedSettingsPayload {
            shop_id: *shop_id,
            device_id: (*device_id).0,
        },
    )
    .await
    {
        Ok(Some(SettingsSummary {
            shop,
            devices,
            current_device_push_enabled,
        })) => json_ok(SettingsSummaryResponse {
            shop,
            devices,
            current_device_push_enabled,
        }),
        Ok(None) => json_error(actix_web::http::StatusCode::UNAUTHORIZED, "unauthorized"),
        Err(e) => {
            tracing::error!("get settings summary error: {}", e);
            json_error(
                actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
                "Server error. Please try again.",
            )
        }
    }
}

pub async fn update_my_shop(
    state: web::Data<AppState>,
    shop_id: ReqData<i64>,
    device_id: ReqData<AuthDeviceId>,
    payload: web::Either<web::Json<ShopUpdateInput>, Multipart>,
) -> impl Responder {
    let mut input = match payload {
        web::Either::Left(json_payload) => json_payload.into_inner(),
        web::Either::Right(mut multipart) => {
            let mut multipart_input = ShopUpdateInput {
                name: None,
                phone: None,
                email: None,
                address: None,
                logo_url: None,
                timezone: None,
                password: None,
            };

            while let Some(item) = multipart.next().await {
                let mut field = match item {
                    Ok(f) => f,
                    Err(_) => {
                        return json_error(
                            actix_web::http::StatusCode::BAD_REQUEST,
                            "invalid multipart",
                        )
                    }
                };

                let field_name = field.name().to_string();
                if field_name == "logo" {
                    let ext = if let Some(content_type) = field.content_type() {
                        extension_from_mime(content_type)
                    } else {
                        None
                    }
                    .or_else(|| {
                        field
                            .content_disposition()
                            .get_filename()
                            .and_then(extension_from_filename)
                    });
                    let ext = match ext {
                        Some(e) => e,
                        None => {
                            return json_error(
                                actix_web::http::StatusCode::BAD_REQUEST,
                                "invalid image type",
                            )
                        }
                    };

                    let filename = format!("shop_{}.{}", *shop_id, ext);
                    let rel_path = format!("uploads/logos/{}", filename);
                    let dest = PathBuf::from("uploads").join("logos").join(filename);

                    if let Err(resp) = read_file_field(&mut field, &dest).await {
                        return resp;
                    }
                    multipart_input.logo_url = Some(rel_path);
                    continue;
                }

                let value = match read_text_field(&mut field).await {
                    Ok(v) => v,
                    Err(resp) => return resp,
                };

                match field_name.as_str() {
                    "name" => multipart_input.name = if value.is_empty() { None } else { Some(value) },
                    "phone" => multipart_input.phone = if value.is_empty() { None } else { Some(value) },
                    "email" => multipart_input.email = if value.is_empty() { None } else { Some(value) },
                    "address" => multipart_input.address = if value.is_empty() { None } else { Some(value) },
                    "timezone" => multipart_input.timezone = if value.is_empty() { None } else { Some(value) },
                    "password" => multipart_input.password = if value.is_empty() { None } else { Some(value) },
                    _ => {}
                }
            }

            multipart_input
        }
    };

    if let Some(v) = input.name.as_ref() {
        if v.trim().is_empty() {
            input.name = None;
        }
    }
    if let Some(v) = input.phone.as_ref() {
        if v.trim().is_empty() {
            input.phone = None;
        }
    }
    if let Some(v) = input.email.as_ref() {
        if v.trim().is_empty() {
            input.email = None;
        }
    }
    if let Some(v) = input.address.as_ref() {
        if v.trim().is_empty() {
            input.address = None;
        }
    }
    if let Some(v) = input.timezone.as_ref() {
        if v.trim().is_empty() {
            input.timezone = None;
        }
    }
    if let Some(v) = input.password.as_ref() {
        if v.trim().is_empty() {
            input.password = None;
        }
    }

    let mut password_hash: Option<String> = None;
    if let Some(password) = &input.password {
        let salt = argon2::password_hash::SaltString::generate(
            &mut argon2::password_hash::rand_core::OsRng,
        );
        let hash = match argon2::Argon2::default().hash_password(password.as_bytes(), &salt) {
            Ok(h) => h.to_string(),
            Err(e) => {
                tracing::error!("hash error: {}", e);
                return json_error(StatusCode::INTERNAL_SERVER_ERROR, "password error");
            }
        };
        password_hash = Some(hash);
    }

    match ShopProfile::update_authorized(
        &state.pool,
        &AuthorizedShopUpdatePayload {
            shop_id: *shop_id,
            device_id: (*device_id).0,
            input,
            password_hash,
        },
    )
    .await
    {
        Ok(Some(shop)) => json_ok(shop),
        Ok(None) => json_error(actix_web::http::StatusCode::UNAUTHORIZED, "unauthorized"),
        Err(e) => {
            tracing::error!("update shop error: {}", e);
            json_error(
                actix_web::http::StatusCode::BAD_REQUEST,
                "phone or email already exists",
            )
        }
    }
}

pub async fn subscribe_fcm(
    state: web::Data<AppState>,
    shop_id: ReqData<i64>,
    device_id: ReqData<AuthDeviceId>,
    payload: web::Json<FcmSubscribeInput>,
) -> impl Responder {
    let token = payload
        .fcm_token
        .as_deref()
        .map(str::trim)
        .filter(|v| !v.is_empty());

    match crate::models::DeviceSession::set_fcm_token_authorized(
        &state.pool,
        *shop_id,
        (*device_id).0,
        token,
    )
    .await
    {
        Ok(true) => json_empty(),
        Ok(false) => json_error(actix_web::http::StatusCode::UNAUTHORIZED, "unauthorized"),
        Err(e) => {
            tracing::error!("fcm subscribe error: {}", e);
            json_error(
                actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
                "Server error. Please try again.",
            )
        }
    }
}
