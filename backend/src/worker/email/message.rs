#[derive(Debug, Clone)]
pub enum EmailTemplate {
    PasswordResetCode,
    Welcome,
}

pub struct EmailMessage {
    pub subject: String,
    pub html_body: String,
    pub text_body: String,
}

pub struct PasswordResetCodeData {
    pub code: String,
}

pub struct WelcomeData {
    pub shop_name: String,
    pub dashboard_url: String,
}

pub fn build_password_reset_code(data: PasswordResetCodeData) -> EmailMessage {
    let template = load_template("password-reset.html");
    let year = current_year();
    let code_boxes = render_code_boxes(&data.code);
    let html_body = match template {
        Some(tpl) => tpl
            .replace("{{CODE}}", &data.code)
            .replace("{{CODE_BOXES}}", &code_boxes)
            .replace("{{YEAR}}", &year),
        None => format!(
            "<p>Your Salesnote password reset code is <strong>{}</strong>.</p>\
             <p>This code expires in 10 minutes.</p>",
            data.code
        ),
    };

    EmailMessage {
        subject: "Salesnote Password Reset Code".to_string(),
        html_body,
        text_body: format!(
            "Your Salesnote password reset code is: {}\n\nThis code expires in 10 minutes.",
            data.code
        ),
    }
}

pub fn build_welcome(data: WelcomeData) -> EmailMessage {
    let template = load_template("welcome.html");
    let year = current_year();
    let html_body = match template {
        Some(tpl) => tpl
            .replace("{{SHOP_NAME}}", &data.shop_name)
            .replace("{{DASHBOARD_URL}}", &data.dashboard_url)
            .replace("{{YEAR}}", &year),
        None => format!(
            "<p>Hi {},</p><p>Welcome to Salesnote. You're ready to create e-receipts.</p>",
            data.shop_name
        ),
    };

    EmailMessage {
        subject: "Welcome to Salesnote".to_string(),
        html_body,
        text_body: format!(
            "Hi {},\n\nWelcome to Salesnote. You're ready to create e-receipts.",
            data.shop_name
        ),
    }
}

fn load_template(filename: &str) -> Option<String> {
    let base = env!("CARGO_MANIFEST_DIR");
    let path = format!("{}/src/worker/email/templates/{}", base, filename);
    std::fs::read_to_string(path).ok()
}

fn render_code_boxes(code: &str) -> String {
    let mut out = String::new();
    for ch in code.chars() {
        out.push_str(&format!(
            "<span class=\"code-box\">{}</span>",
            html_escape(ch)
        ));
    }
    out
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
