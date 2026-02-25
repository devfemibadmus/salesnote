use sqlx::PgPool;

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub jwt_secret: String,
    pub refresh_token_days: i64,
    pub forgot_password_max_requests: i64,
    pub forgot_password_window_minutes: i64,
    pub reset_code_max_incorrect_attempts: i64,
    pub smtp_host: String,
    pub smtp_port: u16,
    pub smtp_username: String,
    pub smtp_password: String,
    pub smtp_from: String,
    pub dashboard_url: String,
    pub redis: redis::Client,
}
