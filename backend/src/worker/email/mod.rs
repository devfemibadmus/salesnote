use lettre::message::Mailbox;
use lettre::transport::smtp::authentication::Credentials;
use lettre::{
    message::header::ContentType, AsyncSmtpTransport, AsyncTransport, Message, Tokio1Executor,
};

use crate::config;

use crate::models::{EmailFailPayload, EmailFetchPayload, EmailMarkPayload, EmailOutbox};
use crate::worker::email::message::{
    build_password_reset_code, build_welcome, PasswordResetCodeData, WelcomeData,
};
use serde_json::Value;

pub mod message;

fn build_mailer(settings: &config::Settings) -> Result<AsyncSmtpTransport<Tokio1Executor>, String> {
    let creds = Credentials::new(
        settings.smtp_username.clone(),
        settings.smtp_password.clone(),
    );

    let transport_builder = if settings.smtp_port == 465 {
        // 465 uses implicit TLS (SMTPS).
        AsyncSmtpTransport::<Tokio1Executor>::relay(&settings.smtp_host)
            .map_err(|_| "smtp config error".to_string())?
    } else {
        // Other common ports (e.g. 587) use STARTTLS.
        AsyncSmtpTransport::<Tokio1Executor>::starttls_relay(&settings.smtp_host)
            .map_err(|_| "smtp config error".to_string())?
    };

    Ok(transport_builder
        .port(settings.smtp_port)
        .credentials(creds)
        .build())
}

pub async fn process_email_once(
    settings: &config::Settings,
    pool: &sqlx::PgPool,
) -> Result<(), String> {
    let emails = EmailOutbox::fetch_pending(pool, &EmailFetchPayload { limit: 20 })
        .await
        .map_err(|e| e.to_string())?;

    if emails.is_empty() {
        return Ok(());
    }

    let from = settings
        .smtp_from
        .parse::<Mailbox>()
        .map_err(|_| "invalid smtp_from".to_string())?;
    let mailer = build_mailer(settings)?;

    for email in emails {
        let to = match email.to_email.parse::<Mailbox>() {
            Ok(m) => m,
            Err(_) => {
                let _ = EmailOutbox::mark_failed(
                    pool,
                    &EmailFailPayload {
                        id: email.id,
                        error: Some("invalid recipient".to_string()),
                        status: "failed".to_string(),
                    },
                )
                .await;
                continue;
            }
        };

        let built = build_message(&email);
        if built.html_body.trim().is_empty() {
            tracing::error!(
                "email_outbox missing template/payload: id={} template={:?}",
                email.id,
                email.template
            );
            let _ = EmailOutbox::mark_failed(
                pool,
                &EmailFailPayload {
                    id: email.id,
                    error: Some("missing template or payload".to_string()),
                    status: "failed".to_string(),
                },
            )
            .await;
            continue;
        }

        let message = match Message::builder()
            .from(from.clone())
            .to(to)
            .subject(built.subject)
            .header(ContentType::TEXT_HTML)
            .body(built.html_body)
        {
            Ok(m) => m,
            Err(_) => {
                let _ = EmailOutbox::mark_failed(
                    pool,
                    &EmailFailPayload {
                        id: email.id,
                        error: Some("email build error".to_string()),
                        status: "failed".to_string(),
                    },
                )
                .await;
                continue;
            }
        };

        let send_result = tokio::time::timeout(
            std::time::Duration::from_secs(settings.smtp_timeout_secs),
            mailer.send(message),
        )
        .await;

        match send_result {
            Ok(Ok(_)) => {
                let _ = EmailOutbox::mark_sent(
                    pool,
                    &EmailMarkPayload {
                        id: email.id,
                        error: None,
                    },
                )
                .await;
            }
            Ok(Err(err)) => {
                tracing::error!(
                    "email_outbox send error: id={} template={:?} err={}",
                    email.id,
                    email.template,
                    err
                );
                let next_attempts = email.attempts + 1;
                let status = if next_attempts >= 2 {
                    "failed".to_string()
                } else {
                    "pending".to_string()
                };

                let _ = EmailOutbox::mark_failed(
                    pool,
                    &EmailFailPayload {
                        id: email.id,
                        error: Some(err.to_string()),
                        status,
                    },
                )
                .await;
            }
            Err(_) => {
                tracing::error!(
                    "email_outbox send timeout: id={} template={:?}",
                    email.id,
                    email.template
                );
                let next_attempts = email.attempts + 1;
                let status = if next_attempts >= 2 {
                    "failed".to_string()
                } else {
                    "pending".to_string()
                };
                let _ = EmailOutbox::mark_failed(
                    pool,
                    &EmailFailPayload {
                        id: email.id,
                        error: Some("send timeout".to_string()),
                        status,
                    },
                )
                .await;
            }
        }
    }

    Ok(())
}

pub async fn check_smtp(settings: &config::Settings) -> Result<(), String> {
    let from = settings
        .smtp_from
        .parse::<Mailbox>()
        .map_err(|_| "invalid smtp_from".to_string())?;
    let mailer = build_mailer(settings)?;

    let message = Message::builder()
        .from(from)
        .to(settings
            .smtp_test_to
            .parse()
            .map_err(|_| "smtp test to error")?)
        .subject("SMTP Check")
        .header(ContentType::TEXT_PLAIN)
        .body("smtp check".to_string())
        .map_err(|_| "smtp test message error".to_string())?;

    let check_result = tokio::time::timeout(
        std::time::Duration::from_secs(settings.smtp_timeout_secs),
        mailer.send(message),
    )
    .await;

    match check_result {
        Ok(Ok(_)) => {
            tracing::info!("smtp check ok");
            Ok(())
        }
        Ok(Err(err)) => {
            tracing::error!("smtp check failed: {}", err);
            Err(err.to_string())
        }
        Err(_) => {
            tracing::error!("smtp check timeout after {}s", settings.smtp_timeout_secs);
            Err(format!(
                "smtp check timeout after {}s",
                settings.smtp_timeout_secs
            ))
        }
    }
}

fn build_message(email: &EmailOutbox) -> message::EmailMessage {
    if let Some(template) = email.template.as_deref() {
        let template = template.trim().to_lowercase();
        match template.as_str() {
            "welcome" => {
                let (shop_name, dashboard_url) = extract_welcome_payload(email.payload.as_ref());
                return build_welcome(WelcomeData {
                    shop_name,
                    dashboard_url,
                });
            }
            "password_reset_code" => {
                let code = extract_string(email.payload.as_ref(), "code").unwrap_or_default();
                return build_password_reset_code(PasswordResetCodeData { code });
            }
            "welsome" => {
                let (shop_name, dashboard_url) = extract_welcome_payload(email.payload.as_ref());
                return build_welcome(WelcomeData {
                    shop_name,
                    dashboard_url,
                });
            }
            _ => {}
        }
    }

    message::EmailMessage {
        subject: "Salesnote".to_string(),
        html_body: String::new(),
        text_body: String::new(),
    }
}

fn extract_welcome_payload(payload: Option<&Value>) -> (String, String) {
    let shop_name = extract_string(payload, "shop_name").unwrap_or_else(|| "Shop".to_string());
    let dashboard_url = extract_string(payload, "dashboard_url").unwrap_or_else(|| "#".to_string());
    (shop_name, dashboard_url)
}

fn extract_string(payload: Option<&Value>, key: &str) -> Option<String> {
    payload
        .and_then(|v| v.get(key))
        .and_then(|v| v.as_str())
        .map(|v| v.to_string())
}
