use chrono::Utc;
use jsonwebtoken::{Algorithm, EncodingKey, Header};
use reqwest::Url;
use rsa::pkcs1v15::SigningKey;
use rsa::pkcs8::DecodePrivateKey;
use rsa::signature::{SignatureEncoding, Signer};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::fs;

const GCS_REFERENCE_PREFIX: &str = "gcs://";
const GOOGLE_STORAGE_HOST: &str = "storage.googleapis.com";

#[derive(Serialize)]
struct Claims<'a> {
    iss: &'a str,
    scope: &'a str,
    aud: &'a str,
    iat: i64,
    exp: i64,
}

#[derive(Serialize)]
struct TokenRequest<'a> {
    grant_type: &'a str,
    assertion: &'a str,
}

#[derive(Deserialize)]
struct TokenResponse {
    access_token: String,
}

#[derive(Deserialize)]
struct ServiceAccount {
    client_email: String,
    private_key: String,
}

pub async fn upload_object(
    key_json_path: &str,
    bucket: &str,
    object_name: &str,
    content_type: &str,
    bytes: Vec<u8>,
) -> Result<String, String> {
    let access_token = fetch_access_token(key_json_path).await?;

    let mut url = Url::parse(&format!(
        "https://storage.googleapis.com/upload/storage/v1/b/{bucket}/o"
    ))
    .map_err(|e| e.to_string())?;
    url.query_pairs_mut()
        .append_pair("uploadType", "media")
        .append_pair("name", object_name);

    let response = reqwest::Client::new()
        .post(url)
        .bearer_auth(access_token)
        .header(reqwest::header::CONTENT_TYPE, content_type)
        .body(bytes)
        .send()
        .await
        .map_err(|e| e.to_string())?;

    if !response.status().is_success() {
        let text = response.text().await.unwrap_or_default();
        return Err(format!("gcs upload error: {text}"));
    }

    Ok(build_object_reference(bucket, object_name))
}

pub fn resolve_media_url(
    key_json_path: &str,
    value: &str,
    ttl_secs: u32,
) -> Result<String, String> {
    let Some((bucket, object_name)) = parse_object_reference(value) else {
        return Ok(value.to_string());
    };

    build_signed_read_url(key_json_path, bucket, object_name, ttl_secs)
}

pub fn build_object_reference(bucket: &str, object_name: &str) -> String {
    format!(
        "{GCS_REFERENCE_PREFIX}{}/{}",
        bucket.trim(),
        object_name.trim_start_matches('/')
    )
}

pub fn parse_object_reference(value: &str) -> Option<(&str, &str)> {
    let path = value.strip_prefix(GCS_REFERENCE_PREFIX)?;
    let (bucket, object_name) = path.split_once('/')?;
    if bucket.trim().is_empty() || object_name.trim().is_empty() {
        return None;
    }
    Some((bucket, object_name))
}

fn build_signed_read_url(
    key_json_path: &str,
    bucket: &str,
    object_name: &str,
    ttl_secs: u32,
) -> Result<String, String> {
    let service_account = load_service_account(key_json_path)?;
    let private_key = service_account.private_key.replace("\\n", "\n");
    let signing_key = SigningKey::<Sha256>::new(
        rsa::RsaPrivateKey::from_pkcs8_pem(&private_key)
            .map_err(|_| "invalid gcs private key".to_string())?,
    );

    let now = Utc::now();
    let datestamp = now.format("%Y%m%d").to_string();
    let timestamp = now.format("%Y%m%dT%H%M%SZ").to_string();
    let scope = format!("{datestamp}/auto/storage/goog4_request");
    let credential = format!("{}/{}", service_account.client_email, scope);
    let expires = ttl_secs.clamp(1, 604_800);
    let signed_headers = "host";
    let canonical_uri = format!("/{}/{}", bucket, encode_path_keep_slashes(object_name));
    let canonical_query = vec![
        (
            "X-Goog-Algorithm".to_string(),
            "GOOG4-RSA-SHA256".to_string(),
        ),
        (
            "X-Goog-Credential".to_string(),
            percent_encode_query(&credential),
        ),
        ("X-Goog-Date".to_string(), timestamp.clone()),
        ("X-Goog-Expires".to_string(), expires.to_string()),
        (
            "X-Goog-SignedHeaders".to_string(),
            signed_headers.to_string(),
        ),
    ]
    .into_iter()
    .map(|(key, value)| format!("{key}={value}"))
    .collect::<Vec<_>>()
    .join("&");
    let canonical_headers = format!("host:{GOOGLE_STORAGE_HOST}\n");
    let canonical_request = format!(
        "GET\n{canonical_uri}\n{canonical_query}\n{canonical_headers}\n{signed_headers}\nUNSIGNED-PAYLOAD"
    );
    let canonical_request_hash = hex::encode(Sha256::digest(canonical_request.as_bytes()));
    let string_to_sign =
        format!("GOOG4-RSA-SHA256\n{timestamp}\n{scope}\n{canonical_request_hash}");
    let signature = hex::encode(signing_key.sign(string_to_sign.as_bytes()).to_vec());

    Ok(format!(
        "https://{GOOGLE_STORAGE_HOST}{canonical_uri}?{canonical_query}&X-Goog-Signature={signature}"
    ))
}

fn encode_path_keep_slashes(value: &str) -> String {
    value
        .split('/')
        .map(percent_encode_path_segment)
        .collect::<Vec<_>>()
        .join("/")
}

fn percent_encode_path_segment(value: &str) -> String {
    percent_encode(value.as_bytes(), false)
}

fn percent_encode_query(value: &str) -> String {
    percent_encode(value.as_bytes(), true)
}

fn percent_encode(bytes: &[u8], encode_slash: bool) -> String {
    let mut out = String::with_capacity(bytes.len());
    for &b in bytes {
        let keep = matches!(b, b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~')
            || (!encode_slash && b == b'/');
        if keep {
            out.push(char::from(b));
        } else {
            out.push('%');
            out.push_str(&format!("{b:02X}"));
        }
    }
    out
}

async fn fetch_access_token(key_json_path: &str) -> Result<String, String> {
    let sa = load_service_account(key_json_path)?;
    let now = Utc::now().timestamp();
    let claims = Claims {
        iss: &sa.client_email,
        scope: "https://www.googleapis.com/auth/devstorage.read_write",
        aud: "https://oauth2.googleapis.com/token",
        iat: now,
        exp: now + 3600,
    };

    let mut header = Header::new(Algorithm::RS256);
    header.typ = Some("JWT".to_string());

    let private_key = sa.private_key.replace("\\n", "\n");
    let key = EncodingKey::from_rsa_pem(private_key.as_bytes())
        .map_err(|_| "invalid gcs private key".to_string())?;

    let jwt = jsonwebtoken::encode(&header, &claims, &key).map_err(|e| e.to_string())?;

    let token_request = TokenRequest {
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: &jwt,
    };

    let response = reqwest::Client::new()
        .post("https://oauth2.googleapis.com/token")
        .form(&token_request)
        .send()
        .await
        .map_err(|e| e.to_string())?;

    if !response.status().is_success() {
        let text = response.text().await.unwrap_or_default();
        return Err(format!("gcs token error: {text}"));
    }

    let token_response = response
        .json::<TokenResponse>()
        .await
        .map_err(|e| e.to_string())?;

    Ok(token_response.access_token)
}

fn load_service_account(path: &str) -> Result<ServiceAccount, String> {
    let content = fs::read_to_string(path).map_err(|_| "service account read error".to_string())?;
    serde_json::from_str(&content).map_err(|_| "service account parse error".to_string())
}
