use actix_multipart::Multipart;
use actix_web::http::StatusCode;
use actix_web::web::ReqData;
use actix_web::{web, HttpResponse, Responder};
use futures_util::StreamExt;
use image::codecs::jpeg::JpegEncoder;
use image::ImageReader;
use serde::Serialize;
use std::io::Cursor;
use std::path::{Path, PathBuf};

use crate::api::middlewares::auth::AuthDeviceId;
use crate::api::response::{json_empty, json_error, json_ok};
use crate::api::state::AppState;
use crate::models::{
    AuthorizedSettingsPayload, AuthorizedShopPayload, AuthorizedShopUpdatePayload, DeviceSession,
    SettingsSummary, ShopProfile, ShopUpdateInput,
};

#[derive(Debug, serde::Deserialize)]
pub struct FcmSubscribeInput {
    pub fcm_token: Option<String>,
}

const MAX_TEXT_FIELD_SIZE: usize = 1024 * 1024;
const PROFILE_IMAGE_MAX_DIMENSION: u32 = 1600;
const PROFILE_IMAGE_MAX_SOURCE_DIMENSION: u32 = 5000;
const PROFILE_IMAGE_MAX_SOURCE_PIXELS: u64 = 16_000_000;
const PROFILE_IMAGE_JPEG_QUALITY: u8 = 82;
const MIN_SHOP_NAME_CHARS: usize = 3;
const MAX_SHOP_NAME_CHARS: usize = 40;
const MIN_ADDRESS_CHARS: usize = 8;
const MAX_ADDRESS_CHARS: usize = 40;
const MIN_ADDRESS_WORDS: usize = 4;
const MAX_ADDRESS_WORDS: usize = 10;
const MIN_PASSWORD_CHARS: usize = 8;
const MAX_PASSWORD_CHARS: usize = 128;

#[derive(Debug, Serialize)]
pub struct SettingsSummaryResponse {
    pub shop: ShopProfile,
    pub devices: Vec<DeviceSession>,
    pub current_device_push_enabled: bool,
}

fn count_words(value: &str) -> usize {
    value
        .split_whitespace()
        .filter(|part| !part.trim().is_empty())
        .count()
}

fn validate_shop_patch(input: &ShopUpdateInput) -> Result<(), &'static str> {
    if let Some(name) = input.name.as_deref() {
        let trimmed = name.trim();
        let chars = trimmed.chars().count();
        if chars < MIN_SHOP_NAME_CHARS {
            return Err("shop name must be at least 3 characters");
        }
        if chars > MAX_SHOP_NAME_CHARS {
            return Err("shop name must be 40 characters or less");
        }
    }

    if let Some(address) = input.address.as_deref() {
        let trimmed = address.trim();
        let chars = trimmed.chars().count();
        if chars < MIN_ADDRESS_CHARS {
            return Err("address must be at least 8 characters");
        }
        if chars > MAX_ADDRESS_CHARS {
            return Err("address must be 40 characters or less");
        }
        let words = count_words(trimmed);
        if words < MIN_ADDRESS_WORDS {
            return Err("address must be at least 4 words");
        }
        if words > MAX_ADDRESS_WORDS {
            return Err("address must be 10 words or less");
        }
    }

    if let Some(password) = input.password.as_deref() {
        let chars = password.chars().count();
        if chars < MIN_PASSWORD_CHARS {
            return Err("password must be at least 8 characters");
        }
        if chars > MAX_PASSWORD_CHARS {
            return Err("password must be 128 characters or less");
        }
    }

    Ok(())
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
        if bytes.len() > MAX_TEXT_FIELD_SIZE {
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

async fn read_file_field_and_optimize_logo(
    field: &mut actix_multipart::Field,
    dest_path: &Path,
    max_size: usize,
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
        if size > max_size {
            return Err(json_error(
                actix_web::http::StatusCode::BAD_REQUEST,
                "image too large",
            ));
        }
        file_bytes.extend_from_slice(&chunk);
    }

    inspect_image_bounds(
        &file_bytes,
        PROFILE_IMAGE_MAX_SOURCE_DIMENSION,
        PROFILE_IMAGE_MAX_SOURCE_PIXELS,
    )?;

    let mut image = image::load_from_memory(&file_bytes).map_err(|_| {
        json_error(
            actix_web::http::StatusCode::BAD_REQUEST,
            "invalid image data",
        )
    })?;

    let width = image.width();
    let height = image.height();
    if width > PROFILE_IMAGE_MAX_DIMENSION || height > PROFILE_IMAGE_MAX_DIMENSION {
        image = image.thumbnail(PROFILE_IMAGE_MAX_DIMENSION, PROFILE_IMAGE_MAX_DIMENSION);
    }

    if let Some(parent) = dest_path.parent() {
        if std::fs::create_dir_all(parent).is_err() {
            return Err(json_error(
                actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
                "storage error",
            ));
        }
    }
    let file = std::fs::File::create(dest_path).map_err(|_| {
        json_error(
            actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
            "storage error",
        )
    })?;
    let mut writer = std::io::BufWriter::new(file);
    let mut encoder = JpegEncoder::new_with_quality(&mut writer, PROFILE_IMAGE_JPEG_QUALITY);
    if encoder.encode_image(&image).is_err() {
        return Err(json_error(
            actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
            "image processing error",
        ));
    }

    Ok(())
}

fn inspect_image_bounds(
    bytes: &[u8],
    max_dimension: u32,
    max_pixels: u64,
) -> Result<(), HttpResponse> {
    let reader = ImageReader::new(Cursor::new(bytes))
        .with_guessed_format()
        .map_err(|_| json_error(StatusCode::BAD_REQUEST, "invalid image data"))?;

    let (width, height) = reader
        .into_dimensions()
        .map_err(|_| json_error(StatusCode::BAD_REQUEST, "invalid image data"))?;

    if width == 0 || height == 0 {
        return Err(json_error(StatusCode::BAD_REQUEST, "invalid image data"));
    }

    let pixel_count = u64::from(width) * u64::from(height);
    if width > max_dimension || height > max_dimension || pixel_count > max_pixels {
        return Err(json_error(
            StatusCode::BAD_REQUEST,
            "image dimensions too large",
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
                    let _validated_ext = match ext {
                        Some(e) => e,
                        None => {
                            return json_error(
                                actix_web::http::StatusCode::BAD_REQUEST,
                                "invalid image type",
                            )
                        }
                    };

                    let filename = format!("shop_{}.jpg", *shop_id);
                    let rel_path = format!("uploads/logos/{}", filename);
                    let dest = PathBuf::from("uploads").join("logos").join(filename);

                    if let Err(resp) = read_file_field_and_optimize_logo(
                        &mut field,
                        &dest,
                        state.profile_image_max_bytes,
                    )
                    .await
                    {
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
                    "name" => {
                        multipart_input.name = if value.is_empty() { None } else { Some(value) }
                    }
                    "phone" => {
                        multipart_input.phone = if value.is_empty() { None } else { Some(value) }
                    }
                    "email" => {
                        multipart_input.email = if value.is_empty() { None } else { Some(value) }
                    }
                    "address" => {
                        multipart_input.address = if value.is_empty() { None } else { Some(value) }
                    }
                    "timezone" => {
                        multipart_input.timezone = if value.is_empty() { None } else { Some(value) }
                    }
                    "password" => {
                        multipart_input.password = if value.is_empty() { None } else { Some(value) }
                    }
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

    if let Err(message) = validate_shop_patch(&input) {
        return json_error(StatusCode::BAD_REQUEST, message);
    }

    let password = input.password.clone();

    match ShopProfile::update_authorized(
        &state.pool,
        &AuthorizedShopUpdatePayload {
            shop_id: *shop_id,
            device_id: (*device_id).0,
            input,
            password,
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
