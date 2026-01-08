use actix_multipart::Multipart;
use actix_web::web::ReqData;
use actix_web::{http::StatusCode, web, HttpResponse, Responder};
use futures_util::StreamExt;
use image::ImageFormat;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

use crate::api::response::{json_created, json_empty, json_error, json_ok};
use crate::api::state::AppState;
use crate::api::middlewares::auth::AuthDeviceId;
use crate::models::{
    AuthorizedSignatureCreatePayload, AuthorizedSignatureCreateResult,
    AuthorizedSignatureDeletePayload, AuthorizedSignatureDeleteResult,
    AuthorizedSignatureListPayload, Signature,
};

const MAX_IMAGE_SIZE: usize = 5 * 1024 * 1024;

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
        if bytes.len() > MAX_IMAGE_SIZE {
            return Err(json_error(StatusCode::BAD_REQUEST, "field too large"));
        }
    }
    String::from_utf8(bytes)
        .map(|s| s.trim().to_string())
        .map_err(|_| json_error(StatusCode::BAD_REQUEST, "invalid text"))
}

async fn read_file_field_bytes(
    field: &mut actix_multipart::Field,
) -> Result<Vec<u8>, HttpResponse> {
    let mut size = 0usize;
    let mut file_bytes = Vec::new();
    while let Some(chunk) = field.next().await {
        let chunk = match chunk {
            Ok(c) => c,
            Err(_) => return Err(json_error(StatusCode::BAD_REQUEST, "invalid file")),
        };
        size += chunk.len();
    if size > MAX_IMAGE_SIZE {
        return Err(json_error(StatusCode::BAD_REQUEST, "image too large"));
    }
    file_bytes.extend_from_slice(&chunk);
    }
    Ok(file_bytes)
}

fn remove_signature_background(bytes: &[u8], out_path: &Path) -> Result<(), HttpResponse> {
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

    if let Some(parent) = out_path.parent() {
        if std::fs::create_dir_all(parent).is_err() {
            return Err(json_error(StatusCode::INTERNAL_SERVER_ERROR, "storage error"));
        }
    }

    image::DynamicImage::ImageRgba8(rgba)
        .save_with_format(out_path, ImageFormat::Png)
        .map_err(|_| json_error(StatusCode::INTERNAL_SERVER_ERROR, "image processing error"))?;
    Ok(())
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
            let file_bytes = match read_file_field_bytes(&mut field).await {
                Ok(b) => b,
                Err(resp) => return resp,
            };

            let processed_filename = format!("sig_{}_{}_processed.png", *shop_id, ts.as_millis());
            let processed_rel_path = format!("uploads/signatures/{}", processed_filename);
            let processed_dest = PathBuf::from("uploads").join("signatures").join(processed_filename);

            if let Err(resp) = remove_signature_background(&file_bytes, &processed_dest) {
                return resp;
            }
            image_path = Some(processed_rel_path);
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
        Ok(AuthorizedSignatureCreateResult::Created(signature)) => json_created(signature),
        Err(e) => {
            tracing::error!("create signature error: {}", e);
            json_error(StatusCode::INTERNAL_SERVER_ERROR, "Server error. Please try again.")
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
        Ok(Some(items)) => json_ok(items),
        Ok(None) => json_error(StatusCode::UNAUTHORIZED, "unauthorized"),
        Err(e) => {
            tracing::error!("list signatures error: {}", e);
            json_error(StatusCode::INTERNAL_SERVER_ERROR, "Server error. Please try again.")
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
        Ok(AuthorizedSignatureDeleteResult::NotFound) => json_error(StatusCode::NOT_FOUND, "not found"),
        Ok(AuthorizedSignatureDeleteResult::InUse) => json_error(
            StatusCode::BAD_REQUEST,
            "signature already in use and can't delete",
        ),
        Ok(AuthorizedSignatureDeleteResult::Deleted) => json_empty(),
        Err(e) => {
            tracing::error!("delete signature error: {}", e);
            json_error(StatusCode::INTERNAL_SERVER_ERROR, "Server error. Please try again.")
        }
    }
}
