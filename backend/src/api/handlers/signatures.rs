use actix_multipart::Multipart;
use actix_web::web::ReqData;
use actix_web::{http::StatusCode, web, HttpResponse, Responder};
use futures_util::StreamExt;
use image::ImageFormat;
use image::ImageReader;
use std::io::Cursor;
use std::time::{SystemTime, UNIX_EPOCH};

use crate::api::middlewares::auth::AuthDeviceId;
use crate::api::response::{json_created, json_empty, json_error, json_ok};
use crate::api::state::AppState;
use crate::models::{
    AuthorizedSignatureCreatePayload, AuthorizedSignatureCreateResult,
    AuthorizedSignatureDeletePayload, AuthorizedSignatureDeleteResult,
    AuthorizedSignatureListPayload, Signature,
};

fn extension_from_mime(mime: &mime::Mime) -> Option<&'static str> {
    match (mime.type_().as_str(), mime.subtype().as_str()) {
        ("image", "jpeg") => Some("jpg"),
        ("image", "jpg") => Some("jpg"),
        ("image", "pjpeg") => Some("jpg"),
        ("image", "jfif") => Some("jpg"),
        ("image", "png") => Some("png"),
        ("image", "webp") => Some("webp"),
        _ => None,
    }
}

fn extension_from_filename(filename: &str) -> Option<&'static str> {
    let ext = filename.rsplit('.').next()?.to_ascii_lowercase();
    match ext.as_str() {
        "jpg" | "jpeg" => Some("jpg"),
        "png" => Some("png"),
        "webp" => Some("webp"),
        _ => None,
    }
}

async fn read_text_field(field: &mut actix_multipart::Field) -> Result<String, HttpResponse> {
    let mut bytes = Vec::new();
    while let Some(chunk) = field.next().await {
        let chunk = match chunk {
            Ok(c) => c,
            Err(_) => return Err(json_error(StatusCode::BAD_REQUEST, "invalid field")),
        };
        bytes.extend_from_slice(&chunk);
        if bytes.len() > 1024 * 1024 {
            return Err(json_error(StatusCode::BAD_REQUEST, "field too large"));
        }
    }
    String::from_utf8(bytes)
        .map(|s| s.trim().to_string())
        .map_err(|_| json_error(StatusCode::BAD_REQUEST, "invalid text"))
}

async fn read_file_field_bytes(
    field: &mut actix_multipart::Field,
    max_size: usize,
) -> Result<Vec<u8>, HttpResponse> {
    let mut size = 0usize;
    let mut file_bytes = Vec::new();
    while let Some(chunk) = field.next().await {
        let chunk = match chunk {
            Ok(c) => c,
            Err(_) => return Err(json_error(StatusCode::BAD_REQUEST, "invalid file")),
        };
        size += chunk.len();
        if size > max_size {
            return Err(json_error(StatusCode::BAD_REQUEST, "image too large"));
        }
        file_bytes.extend_from_slice(&chunk);
    }
    Ok(file_bytes)
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

fn remove_signature_background(bytes: &[u8]) -> Result<Vec<u8>, HttpResponse> {
    let img = image::load_from_memory(bytes).map_err(|_| {
        json_error(
            StatusCode::BAD_REQUEST,
            "invalid image data (expected jpeg/png/webp)",
        )
    })?;
    let mut rgba = img.to_rgba8();

    for p in rgba.pixels_mut() {
        let r = p[0] as f32;
        let g = p[1] as f32;
        let b = p[2] as f32;
        let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;

        // Treat bright background as transparent and softly fade near-white edges.
        let alpha = if lum >= 245.0 {
            0u8
        } else if lum >= 220.0 {
            let t = (245.0 - lum) / 25.0; // 0..1
            (t * 255.0).clamp(0.0, 255.0) as u8
        } else {
            255u8
        };
        p[3] = alpha;
    }

    let mut output = std::io::Cursor::new(Vec::new());
    image::DynamicImage::ImageRgba8(rgba)
        .write_to(&mut output, ImageFormat::Png)
        .map_err(|_| json_error(StatusCode::INTERNAL_SERVER_ERROR, "image processing error"))?;
    Ok(output.into_inner())
}

fn save_signature_bytes_local(
    shop_id: i64,
    ts_millis: u128,
    bytes: &[u8],
) -> Result<String, HttpResponse> {
    let filename = format!("sig_{shop_id}_{ts_millis}_processed.png");
    let rel_path = format!("uploads/signatures/{filename}");
    let dest = std::path::PathBuf::from("uploads")
        .join("signatures")
        .join(filename);

    if let Some(parent) = dest.parent() {
        if std::fs::create_dir_all(parent).is_err() {
            return Err(json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "storage error",
            ));
        }
    }

    std::fs::write(&dest, bytes)
        .map_err(|_| json_error(StatusCode::INTERNAL_SERVER_ERROR, "storage error"))?;
    Ok(rel_path)
}

async fn persist_signature(
    state: &AppState,
    shop_id: i64,
    ts_millis: u128,
    bytes: Vec<u8>,
) -> Result<String, HttpResponse> {
    if let Some(bucket) = state.gcs_bucket.as_deref() {
        let object_name = format!("signatures/shop_{shop_id}/sig_{ts_millis}.png");
        let key_path = state
            .gcs_key_json_path
            .as_deref()
            .filter(|v| !v.trim().is_empty())
            .unwrap_or("firebase-adminsdk.json");
        return crate::storage::gcs::upload_object(
            key_path,
            bucket,
            &object_name,
            "image/png",
            bytes,
        )
        .await
        .map_err(|e| {
            tracing::error!("gcs signature upload error: {}", e);
            json_error(StatusCode::INTERNAL_SERVER_ERROR, "storage error")
        });
    }

    save_signature_bytes_local(shop_id, ts_millis, &bytes)
}

pub async fn create_signature(
    state: web::Data<AppState>,
    shop_id: ReqData<i64>,
    device_id: ReqData<AuthDeviceId>,
    mut payload: Multipart,
) -> impl Responder {
    let mut name: Option<String> = None;
    let mut image_path: Option<String> = None;

    while let Some(item) = payload.next().await {
        let mut field = match item {
            Ok(f) => f,
            Err(_) => return json_error(StatusCode::BAD_REQUEST, "invalid multipart"),
        };

        let field_name = field.name().to_string();
        if field_name == "name" {
            match read_text_field(&mut field).await {
                Ok(val) => name = Some(val),
                Err(resp) => return resp,
            }
            continue;
        }

        if field_name == "image" {
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
                None => return json_error(StatusCode::BAD_REQUEST, "invalid image type"),
            };

            let ts = match SystemTime::now().duration_since(UNIX_EPOCH) {
                Ok(t) => t,
                Err(_) => return json_error(StatusCode::INTERNAL_SERVER_ERROR, "time error"),
            };
            let file_bytes =
                match read_file_field_bytes(&mut field, state.signature_image_max_bytes).await {
                    Ok(b) => b,
                    Err(resp) => return resp,
                };
            if let Err(resp) = inspect_image_bounds(
                &file_bytes,
                state.signature_image_max_source_dimension,
                state.signature_image_max_source_pixels,
            ) {
                return resp;
            }

            let processed_bytes = match remove_signature_background(&file_bytes) {
                Ok(bytes) => bytes,
                Err(resp) => return resp,
            };
            let stored_url =
                match persist_signature(&state, *shop_id, ts.as_millis(), processed_bytes).await {
                    Ok(url) => url,
                    Err(resp) => return resp,
                };
            image_path = Some(stored_url);
            continue;
        }
    }

    let name = match name {
        Some(n) if !n.trim().is_empty() => n,
        _ => return json_error(StatusCode::BAD_REQUEST, "name required"),
    };
    let image_url = match image_path {
        Some(p) => p,
        None => return json_error(StatusCode::BAD_REQUEST, "image required"),
    };

    match Signature::create_authorized(
        &state.pool,
        &AuthorizedSignatureCreatePayload {
            shop_id: *shop_id,
            device_id: (*device_id).0,
            name,
            image_url,
        },
    )
    .await
    {
        Ok(AuthorizedSignatureCreateResult::Unauthorized) => {
            json_error(StatusCode::UNAUTHORIZED, "unauthorized")
        }
        Ok(AuthorizedSignatureCreateResult::LimitReached) => {
            json_error(StatusCode::BAD_REQUEST, "signature limit reached")
        }
        Ok(AuthorizedSignatureCreateResult::Created(mut signature)) => {
            if let Err(resp) = crate::api::media::resolve_signature_media(&state, &mut signature) {
                return resp;
            }
            json_created(signature)
        }
        Err(e) => {
            tracing::error!("create signature error: {}", e);
            json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Server error. Please try again.",
            )
        }
    }
}

pub async fn list_signatures(
    state: web::Data<AppState>,
    shop_id: ReqData<i64>,
    device_id: ReqData<AuthDeviceId>,
) -> impl Responder {
    match Signature::list_authorized(
        &state.pool,
        &AuthorizedSignatureListPayload {
            shop_id: *shop_id,
            device_id: (*device_id).0,
        },
    )
    .await
    {
        Ok(Some(mut items)) => {
            if let Err(resp) = crate::api::media::resolve_signature_list_media(&state, &mut items) {
                return resp;
            }
            json_ok(items)
        }
        Ok(None) => json_error(StatusCode::UNAUTHORIZED, "unauthorized"),
        Err(e) => {
            tracing::error!("list signatures error: {}", e);
            json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Server error. Please try again.",
            )
        }
    }
}

pub async fn delete_signature(
    state: web::Data<AppState>,
    shop_id: ReqData<i64>,
    device_id: ReqData<AuthDeviceId>,
    signature_id: web::Path<i64>,
) -> impl Responder {
    match Signature::delete_authorized(
        &state.pool,
        &AuthorizedSignatureDeletePayload {
            shop_id: *shop_id,
            device_id: (*device_id).0,
            signature_id: *signature_id,
        },
    )
    .await
    {
        Ok(AuthorizedSignatureDeleteResult::Unauthorized) => {
            json_error(StatusCode::UNAUTHORIZED, "unauthorized")
        }
        Ok(AuthorizedSignatureDeleteResult::NotFound) => {
            json_error(StatusCode::NOT_FOUND, "not found")
        }
        Ok(AuthorizedSignatureDeleteResult::InUse) => json_error(
            StatusCode::BAD_REQUEST,
            "signature already in use and can't delete",
        ),
        Ok(AuthorizedSignatureDeleteResult::Deleted) => json_empty(),
        Err(e) => {
            tracing::error!("delete signature error: {}", e);
            json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Server error. Please try again.",
            )
        }
    }
}
