use chrono::Utc;
use jsonwebtoken::{Algorithm, EncodingKey, Header};
use reqwest::Url;
use serde::{Deserialize, Serialize};
use std::fs;

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
    public_base_url: Option<&str>,
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

    Ok(build_public_url(bucket, object_name, public_base_url))
}

fn build_public_url(bucket: &str, object_name: &str, public_base_url: Option<&str>) -> String {
    let base = public_base_url
        .map(str::trim)
        .filter(|v| !v.is_empty())
        .map(|v| v.trim_end_matches('/').to_string())
        .unwrap_or_else(|| format!("https://storage.googleapis.com/{bucket}"));
    format!("{base}/{}", object_name.trim_start_matches('/'))
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
