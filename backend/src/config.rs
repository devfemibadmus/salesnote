use serde::Deserialize;
use tracing_subscriber::{fmt, EnvFilter};

#[derive(Debug, Deserialize, Clone)]
pub struct Settings {
    pub bind: String,
    pub database_url: String,
    pub jwt_secret: String,
    pub refresh_token_days: i64,
    pub rate_limit_per_minute: u32,
    pub redis_url: String,
    pub smtp_host: String,
    pub smtp_port: u16,
    pub smtp_username: String,
    pub smtp_password: String,
    pub smtp_from: String,
    pub smtp_timeout_secs: u64,
    pub smtp_test_to: String,
    pub dashboard_url: String,
    pub fcm_project_id: String,
    pub fcm_key_json_path: String,
    pub geoip_url: Option<String>,
    pub geoip_token: Option<String>,
}

impl Settings {
    pub fn load() -> Self {
        let base = env!("CARGO_MANIFEST_DIR");
        let env_path = format!("{}/.env", base);
        dotenvy::from_filename(&env_path)
            .expect("missing .env file in backend/");

        config::Config::builder()
            .add_source(config::Environment::with_prefix("SALESNOTE").separator("__"))
            .build()
            .expect("invalid config")
            .try_deserialize()
            .expect("invalid config values")
    }
}

pub fn init_tracing() {
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("trace"));
    fmt().with_env_filter(filter).init();
}
