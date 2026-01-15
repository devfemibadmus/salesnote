use chrono::Utc;
use jsonwebtoken::{Algorithm, EncodingKey, Header};
use serde::Serialize;
use std::fs;

use crate::config::Settings;

#[derive(Serialize)]
struct Claims<'a> {
    iss: &'a str,
    scope: &'a str,
    aud: &'a str,
    iat: i64,
    exp: i64,
}

#[derive(Serialize)]
struct FcmRequest<'a> {
    message: FcmMessage<'a>,
}

#[derive(Serialize)]
struct FcmMessage<'a> {
    token: &'a str,
    notification: FcmNotification<'a>,
    data: FcmData<'a>,
}

#[derive(Serialize)]
struct FcmNotification<'a> {
    title: &'a str,
    body: &'a str,
}

#[derive(Serialize)]
struct FcmData<'a> {
    #[serde(rename = "type")]
    kind: &'a str,
    title: &'a str,
    body: &'a str,
}

#[derive(Serialize)]
struct TokenRequest<'a> {
    grant_type: &'a str,
    assertion: &'a str,
}

#[derive(serde::Deserialize)]
struct TokenResponse {
    access_token: String,
}

#[derive(serde::Deserialize)]
struct ServiceAccount {
    client_email: String,
    private_key: String,
}

pub async fn send_fcm_notification(
    token: &str,
    title: String,
    body: String,
    kind: &str,
    settings: &Settings,
) -> Result<(), String> {
    let access_token = fetch_access_token(settings).await?;
    let url = format!(
        "https://fcm.googleapis.com/v1/projects/{}/messages:send",
        settings.fcm_project_id
    );

    let payload = FcmRequest {
        message: FcmMessage {
            token,
            notification: FcmNotification {
                title: &title,
                body: &body,
            },
            data: FcmData {
                kind,
                title: &title,
                body: &body,
            },
        },
    };

    let client = reqwest::Client::new();
    let resp = client
        .post(url)
        .bearer_auth(access_token)
        .json(&payload)
        .send()
        .await
        .map_err(|e| e.to_string())?;

    if !resp.status().is_success() {
        let text = resp.text().await.unwrap_or_default();
        return Err(format!("fcm error: {}", text));
    }

    Ok(())
}

async fn fetch_access_token(settings: &Settings) -> Result<String, String> {
    let sa = load_service_account(&settings.fcm_key_json_path)?;
    let now = Utc::now().timestamp();
    let claims = Claims {
        iss: &sa.client_email,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        iat: now,
        exp: now + 3600,
    };

    let mut header = Header::new(Algorithm::RS256);
    header.typ = Some("JWT".to_string());

    let private_key = sa.private_key.replace("\\n", "\n");
    let key = EncodingKey::from_rsa_pem(private_key.as_bytes())
        .map_err(|_| "invalid fcm private key".to_string())?;

    let jwt = jsonwebtoken::encode(&header, &claims, &key).map_err(|e| e.to_string())?;

    let token_request = TokenRequest {
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: &jwt,
    };

    let client = reqwest::Client::new();
    let resp = client
        .post("https://oauth2.googleapis.com/token")
        .form(&token_request)
        .send()
        .await
        .map_err(|e| e.to_string())?;

    if !resp.status().is_success() {
        let text = resp.text().await.unwrap_or_default();
        return Err(format!("token error: {}", text));
    }

    let token_resp = resp
        .json::<TokenResponse>()
        .await
        .map_err(|e| e.to_string())?;

    Ok(token_resp.access_token)
}

fn load_service_account(path: &str) -> Result<ServiceAccount, String> {
    let content = fs::read_to_string(path).map_err(|_| "service account read error".to_string())?;
    serde_json::from_str(&content).map_err(|_| "service account parse error".to_string())
}
