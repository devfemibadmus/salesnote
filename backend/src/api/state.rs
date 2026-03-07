use ipnet::IpNet;
use sqlx::PgPool;

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub jwt_secret: String,
    pub max_request_payload_bytes: usize,
    pub profile_image_max_bytes: usize,
    pub profile_image_max_source_dimension: u32,
    pub profile_image_max_source_pixels: u64,
    pub signature_image_max_bytes: usize,
    pub signature_image_max_source_dimension: u32,
    pub signature_image_max_source_pixels: u64,
    pub refresh_token_days: i64,
    pub password_min_chars: usize,
    pub password_max_chars: usize,
    pub forgot_password_max_requests: i64,
    pub forgot_password_window_minutes: i64,
    pub reset_code_max_incorrect_attempts: i64,
    pub trusted_proxies: Vec<IpNet>,
    pub smtp_host: String,
    pub smtp_port: u16,
    pub smtp_username: String,
    pub smtp_password: String,
    pub smtp_from: String,
    pub dashboard_url: String,
    pub gcs_bucket: Option<String>,
    pub gcs_key_json_path: Option<String>,
    pub gcs_signed_url_ttl_secs: u32,
    pub redis: redis::Client,
}
