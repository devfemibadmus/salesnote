use lettre::message::{header::ContentType, Attachment, Mailbox, MultiPart, SinglePart};
use lettre::transport::smtp::authentication::Credentials;
use lettre::{AsyncSmtpTransport, AsyncTransport, Message, Tokio1Executor};

use crate::config;

struct EmailMessage {
    subject: String,
    html_body: String,
    inline_logo_bytes: Option<Vec<u8>>,
}

struct PasswordResetCodeData {
    code: String,
}

struct SignupVerificationCodeData {
    code: String,
    shop_name: String,
}

fn build_mailer(settings: &config::Settings) -> Result<AsyncSmtpTransport<Tokio1Executor>, String> {
    let creds = Credentials::new(
        settings.smtp_username.clone(),
        settings.smtp_password.clone(),
    );

    let transport_builder = if settings.smtp_port == 465 {
        AsyncSmtpTransport::<Tokio1Executor>::relay(&settings.smtp_host)
            .map_err(|_| "smtp config error".to_string())?
    } else {
        AsyncSmtpTransport::<Tokio1Executor>::starttls_relay(&settings.smtp_host)
            .map_err(|_| "smtp config error".to_string())?
    };

    Ok(transport_builder
        .port(settings.smtp_port)
        .credentials(creds)
        .build())
}

pub async fn send_password_reset_email_direct(
    settings: &config::Settings,
    to_email: &str,
    code: &str,
) -> Result<(), String> {
    send_direct(
        settings,
        to_email,
        build_password_reset_code(PasswordResetCodeData {
            code: code.to_string(),
        }),
    )
    .await
}

pub async fn send_signup_verification_email_direct(
    settings: &config::Settings,
    to_email: &str,
    shop_name: &str,
    code: &str,
) -> Result<(), String> {
    send_direct(
        settings,
        to_email,
        build_signup_verification_code(SignupVerificationCodeData {
            code: code.to_string(),
            shop_name: shop_name.to_string(),
        }),
    )
    .await
}

async fn send_direct(
    settings: &config::Settings,
    to_email: &str,
    built: EmailMessage,
) -> Result<(), String> {
    let from = settings
        .smtp_from
        .parse::<Mailbox>()
        .map_err(|_| "invalid smtp_from".to_string())?;

    let to = to_email
        .parse::<Mailbox>()
        .map_err(|_| format!("invalid recipient: {}", to_email))?;

    let mailer = build_mailer(settings)?;

    let html_part = SinglePart::builder()
        .header(ContentType::TEXT_HTML)
        .body(built.html_body);

    let message = if let Some(logo_bytes) = built.inline_logo_bytes {
        let logo_content_type = ContentType::parse("image/jpeg")
            .map_err(|e| format!("logo content type error: {e}"))?;

        Message::builder()
            .from(from)
            .to(to)
            .subject(built.subject)
            .multipart(
                MultiPart::related().singlepart(html_part).singlepart(
                    Attachment::new_inline("salesnote-logo".to_string())
                        .body(logo_bytes, logo_content_type),
                ),
            )
            .map_err(|e| format!("email build error: {}", e))?
    } else {
        Message::builder()
            .from(from)
            .to(to)
            .subject(built.subject)
            .singlepart(html_part)
            .map_err(|e| format!("email build error: {}", e))?
    };

    let send_result = tokio::time::timeout(
        std::time::Duration::from_secs(settings.smtp_timeout_secs),
        mailer.send(message),
    )
    .await;

    match send_result {
        Ok(Ok(_)) => Ok(()),
        Ok(Err(err)) => Err(format!("smtp error: {}", err)),
        Err(_) => Err("smtp timeout".to_string()),
    }
}

fn build_password_reset_code(data: PasswordResetCodeData) -> EmailMessage {
    let template = load_template("password-reset.html");
    let year = current_year();
    let code_boxes = render_code_boxes(&data.code);
    let logo_bytes = load_logo_bytes();
    let logo_block = render_logo_block(logo_bytes.is_some());

    let html_body = match template {
        Some(tpl) => tpl
            .replace("{{CODE_BOXES}}", &code_boxes)
            .replace("{{YEAR}}", &year)
            .replace("{{LOGO_BLOCK}}", &logo_block),
        None => format!(
            "<p>Your Salesnote password reset code is <strong>{}</strong>.</p><p>This code expires in 10 minutes.</p>",
            data.code
        ),
    };

    EmailMessage {
        subject: "Salesnote Password Reset Code".to_string(),
        html_body,
        inline_logo_bytes: logo_bytes,
    }
}

fn build_signup_verification_code(data: SignupVerificationCodeData) -> EmailMessage {
    let template = load_template("signup-verification.html");
    let year = current_year();
    let code_boxes = render_code_boxes(&data.code);
    let logo_bytes = load_logo_bytes();
    let logo_block = render_logo_block(logo_bytes.is_some());

    let html_body = match template {
        Some(tpl) => tpl
            .replace("{{SHOP_NAME}}", &data.shop_name)
            .replace("{{CODE_BOXES}}", &code_boxes)
            .replace("{{YEAR}}", &year)
            .replace("{{LOGO_BLOCK}}", &logo_block),
        None => format!(
            "<p>Hi {},</p><p>Use this verification code to complete your account creation:</p><p><strong>{}</strong></p>",
            data.shop_name, data.code
        ),
    };

    EmailMessage {
        subject: "Verify your Salesnote account".to_string(),
        html_body,
        inline_logo_bytes: logo_bytes,
    }
}

fn load_template(filename: &str) -> Option<String> {
    for path in template_candidates(filename) {
        if let Ok(content) = std::fs::read_to_string(&path) {
            return Some(content);
        }
    }

    embedded_template(filename).map(ToString::to_string)
}

fn template_candidates(filename: &str) -> Vec<std::path::PathBuf> {
    let mut out = Vec::new();

    if let Some(dir) = std::env::var("SALESNOTE__EMAIL_TEMPLATES_DIR")
        .ok()
        .or_else(|| std::env::var("EMAIL_TEMPLATES_DIR").ok())
    {
        let dir = dir.trim();
        if !dir.is_empty() {
            out.push(std::path::PathBuf::from(dir).join(filename));
        }
    }

    if let Ok(cwd) = std::env::current_dir() {
        out.push(
            cwd.join("src")
                .join("api")
                .join("email")
                .join("templates")
                .join(filename),
        );
    }

    out.push(
        std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("src")
            .join("api")
            .join("email")
            .join("templates")
            .join(filename),
    );

    out
}

fn embedded_template(filename: &str) -> Option<&'static str> {
    match filename {
        "password-reset.html" => Some(include_str!("templates/password-reset.html")),
        "signup-verification.html" => Some(include_str!("templates/signup-verification.html")),
        _ => None,
    }
}

fn load_logo_bytes() -> Option<Vec<u8>> {
    for path in template_candidates("logo.jpg") {
        if let Ok(bytes) = std::fs::read(&path) {
            return Some(bytes);
        }
    }

    Some(include_bytes!("templates/logo.jpg").to_vec())
}

fn render_code_boxes(code: &str) -> String {
    let mut out = String::new();
    for ch in code.chars() {
        out.push_str(&format!(
            "<td class=\"code-cell\"><div class=\"code-box\">{}</div></td>",
            html_escape(ch)
        ));
    }
    out
}

fn render_logo_block(has_logo: bool) -> String {
    if has_logo {
        return "<img src=\"cid:salesnote-logo\" alt=\"Salesnote\" class=\"logo\" width=\"64\" height=\"64\" style=\"display:block; width:64px; height:64px; border-radius:18px; margin:0 auto;\" />".to_string();
    }

    "<div class=\"logo-fallback\">S</div>".to_string()
}

fn html_escape(ch: char) -> String {
    match ch {
        '&' => "&amp;".to_string(),
        '<' => "&lt;".to_string(),
        '>' => "&gt;".to_string(),
        '"' => "&quot;".to_string(),
        '\'' => "&#39;".to_string(),
        _ => ch.to_string(),
    }
}

fn current_year() -> String {
    let now = chrono::Utc::now();
    now.format("%Y").to_string()
}
