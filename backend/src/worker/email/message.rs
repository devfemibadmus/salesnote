pub struct EmailMessage {
    pub subject: String,
    pub html_body: String,
    pub text_body: String,
}

pub struct WelcomeData {
    pub shop_name: String,
    pub dashboard_url: String,
}

pub fn build_welcome(data: WelcomeData) -> EmailMessage {
    let template = load_template("welcome.html");
    let year = current_year();
    let logo_b64 = load_logo_base64().unwrap_or_default();

    let html_body = match template {
        Some(tpl) => tpl
            .replace("{{SHOP_NAME}}", &data.shop_name)
            .replace("{{DASHBOARD_URL}}", &data.dashboard_url)
            .replace("{{YEAR}}", &year)
            .replace("{{LOGO_URL}}", &logo_b64),
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
        out.push(cwd.join("templates").join("email").join(filename));
        out.push(
            cwd.join("src")
                .join("worker")
                .join("email")
                .join("templates")
                .join(filename),
        );
    }

    if let Ok(exe) = std::env::current_exe() {
        if let Some(parent) = exe.parent() {
            out.push(parent.join("templates").join("email").join(filename));
            if let Some(grand_parent) = parent.parent() {
                out.push(grand_parent.join("templates").join("email").join(filename));
            }
        }
    }

    out.push(std::path::PathBuf::from("/home/salesnote/worker/templates/email").join(filename));
    out.push(
        std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("src")
            .join("worker")
            .join("email")
            .join("templates")
            .join(filename),
    );

    out
}

fn embedded_template(filename: &str) -> Option<&'static str> {
    match filename {
        "welcome.html" => Some(include_str!("templates/welcome.html")),
        _ => None,
    }
}

fn load_logo_base64() -> Option<String> {
    use base64::{engine::general_purpose, Engine as _};
    for path in template_candidates("logo.jpg") {
        if let Ok(bytes) = std::fs::read(&path) {
            let b64 = general_purpose::STANDARD.encode(&bytes);
            return Some(format!("data:image/jpeg;base64,{}", b64));
        }
    }

    let bytes = include_bytes!("templates/logo.jpg");
    let b64 = general_purpose::STANDARD.encode(bytes);
    Some(format!("data:image/jpeg;base64,{}", b64))
}

fn current_year() -> String {
    let now = chrono::Utc::now();
    now.format("%Y").to_string()
}
