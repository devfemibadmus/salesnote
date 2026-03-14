use once_cell::sync::OnceCell;
use serde::Deserialize;
use std::{env, fs, path::PathBuf};
use tracing::Level;
use tracing_appender::non_blocking::WorkerGuard;
use tracing_subscriber::filter::filter_fn;
use tracing_subscriber::prelude::*;
use tracing_subscriber::{fmt, EnvFilter};

static SETTINGS: OnceCell<Settings> = OnceCell::new();
static ENV_BOOTSTRAPPED: OnceCell<()> = OnceCell::new();
static LOG_GUARDS: OnceCell<LogGuards> = OnceCell::new();

const ENV_PROFILE_FILE: &str = "env.profile";
const ENV_PROFILE_ENV_KEY: &str = "SALESNOTE_ENV_PROFILE";
const LEGACY_ENV_PROFILE_ENV_KEY: &str = "APP_ENV_PROFILE";
const ENV_PROFILE_PRODUCTION: &str = "production";
const ENV_PROFILE_TEST: &str = "test";

#[derive(Debug, Deserialize, Clone)]
pub struct Settings {
    #[serde(default = "default_bind")]
    pub bind: String,
    pub database_url: String,
    #[serde(default = "default_max_request_payload_bytes")]
    pub max_request_payload_bytes: usize,
    #[serde(default = "default_profile_image_max_bytes")]
    pub profile_image_max_bytes: usize,
    #[serde(default = "default_profile_image_max_source_dimension")]
    pub profile_image_max_source_dimension: u32,
    #[serde(default = "default_profile_image_max_source_pixels")]
    pub profile_image_max_source_pixels: u64,
    #[serde(default = "default_signature_image_max_bytes")]
    pub signature_image_max_bytes: usize,
    #[serde(default = "default_signature_image_max_source_dimension")]
    pub signature_image_max_source_dimension: u32,
    #[serde(default = "default_signature_image_max_source_pixels")]
    pub signature_image_max_source_pixels: u64,
    #[serde(default = "default_pool_max_size")]
    pub pool_max_size: u32,
    #[serde(default = "default_pool_min_idle")]
    pub pool_min_idle: u32,
    pub jwt_secret: String,
    pub refresh_token_days: i64,
    pub rate_limit_per_minute: u32,
    #[serde(default = "default_auth_login_rate_limit_per_minute")]
    pub auth_login_rate_limit_per_minute: u32,
    #[serde(default = "default_auth_register_rate_limit_per_minute")]
    pub auth_register_rate_limit_per_minute: u32,
    #[serde(default = "default_auth_register_verify_rate_limit_per_minute")]
    pub auth_register_verify_rate_limit_per_minute: u32,
    #[serde(default = "default_auth_forgot_password_rate_limit_per_minute")]
    pub auth_forgot_password_rate_limit_per_minute: u32,
    #[serde(default = "default_auth_verify_code_rate_limit_per_minute")]
    pub auth_verify_code_rate_limit_per_minute: u32,
    #[serde(default = "default_auth_reset_password_rate_limit_per_minute")]
    pub auth_reset_password_rate_limit_per_minute: u32,
    #[serde(default = "default_forgot_password_max_requests")]
    pub forgot_password_max_requests: i64,
    #[serde(default = "default_forgot_password_window_minutes")]
    pub forgot_password_window_minutes: i64,
    #[serde(default = "default_reset_code_max_incorrect_attempts")]
    pub reset_code_max_incorrect_attempts: i64,
    #[serde(default = "default_trusted_proxy_ranges")]
    pub trusted_proxy_ranges: String,
    #[serde(default = "default_password_min_chars")]
    pub password_min_chars: usize,
    #[serde(default = "default_password_max_chars")]
    pub password_max_chars: usize,
    #[serde(default = "default_use_redis")]
    pub use_redis: bool,
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
    #[serde(default)]
    pub gemini_api_key: String,
    #[serde(default = "default_gemini_live_model")]
    pub gemini_live_model: String,
    #[serde(default = "default_gemini_live_max_session_tokens")]
    pub gemini_live_max_session_tokens: i64,
    #[serde(default)]
    pub gcs_bucket: Option<String>,
    #[serde(default)]
    pub gcs_key_json_path: Option<String>,
    #[serde(default = "default_gcs_signed_url_ttl_secs")]
    pub gcs_signed_url_ttl_secs: u32,
    pub geoip_url: Option<String>,
    pub geoip_token: Option<String>,
    #[serde(default = "default_log_to_terminal")]
    pub log_to_terminal: bool,
    #[serde(default = "default_enable_backtrace")]
    pub enable_backtrace: bool,
    #[serde(default = "default_enable_sql_error_logging")]
    pub enable_sql_error_logging: bool,
    #[serde(default = "default_log_dir")]
    pub log_dir: String,
    #[serde(default = "default_access_log_file")]
    pub access_log_file: String,
    #[serde(default = "default_info_log_file")]
    pub info_log_file: String,
    #[serde(default = "default_error_log_file")]
    pub error_log_file: String,
}

impl Settings {
    pub fn load() -> Self {
        bootstrap_env();
        let settings = SETTINGS.get_or_init(build_settings);
        apply_runtime_env_flags(settings);
        settings.clone()
    }
}

pub fn init_tracing() {
    let settings = Settings::load();

    let _ = tracing_log::LogTracer::init();
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("trace"));

    if settings.log_to_terminal {
        let _ = tracing_subscriber::registry()
            .with(filter)
            .with(fmt::layer().with_target(true).with_ansi(true))
            .try_init();
        return;
    }

    if fs::create_dir_all(&settings.log_dir).is_err() {
        let _ = tracing_subscriber::registry()
            .with(filter)
            .with(fmt::layer().with_target(true).with_ansi(true))
            .try_init();
        return;
    }

    let (access_writer, access_guard) = tracing_appender::non_blocking(
        tracing_appender::rolling::never(&settings.log_dir, &settings.access_log_file),
    );
    let (info_writer, info_guard) = tracing_appender::non_blocking(
        tracing_appender::rolling::never(&settings.log_dir, &settings.info_log_file),
    );
    let (error_writer, error_guard) = tracing_appender::non_blocking(
        tracing_appender::rolling::never(&settings.log_dir, &settings.error_log_file),
    );

    let _ = tracing_subscriber::registry()
        .with(filter)
        .with(
            fmt::layer()
                .with_ansi(false)
                .with_target(true)
                .with_writer(access_writer)
                .with_filter(filter_fn(|meta| is_access_target(meta.target()))),
        )
        .with(
            fmt::layer()
                .with_ansi(false)
                .with_target(true)
                .with_writer(info_writer)
                .with_filter(filter_fn(|meta| !is_access_target(meta.target()))),
        )
        .with(
            fmt::layer()
                .with_ansi(false)
                .with_target(true)
                .with_writer(error_writer)
                .with_filter(filter_fn(|meta| {
                    !is_access_target(meta.target()) && *meta.level() >= Level::WARN
                })),
        )
        .try_init();

    let _ = LOG_GUARDS.set(LogGuards {
        _access: access_guard,
        _info: info_guard,
        _error: error_guard,
    });
}

pub fn available_env_profiles() -> &'static [&'static str] {
    &[ENV_PROFILE_PRODUCTION, ENV_PROFILE_TEST]
}

pub fn active_env_profile() -> String {
    resolve_profile().to_string()
}

pub fn active_env_file() -> String {
    let profile = resolve_profile();
    let preferred = runtime_dir().join(format!(".env.{profile}"));
    if preferred.exists() {
        preferred.to_string_lossy().to_string()
    } else {
        runtime_dir().join(".env").to_string_lossy().to_string()
    }
}

pub fn set_active_env_profile(profile: &str) -> std::io::Result<()> {
    let normalized = normalize_env_profile(profile).ok_or_else(|| {
        std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            "profile must be 'production' or 'test'",
        )
    })?;

    let path = profile_file_path();
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, normalized)?;
    Ok(())
}

fn build_settings() -> Settings {
    let mut settings: Settings = config::Config::builder()
        .add_source(config::Environment::with_prefix("SALESNOTE").separator("__"))
        .build()
        .expect("invalid config")
        .try_deserialize()
        .expect("invalid config values");

    settings.log_to_terminal = env_bool_any(
        &["SALESNOTE__LOG_TO_TERMINAL", "LOG_TO_TERMINAL"],
        settings.log_to_terminal,
    );
    settings.enable_backtrace = env_bool_any(
        &["SALESNOTE__ENABLE_BACKTRACE", "ENABLE_BACKTRACE"],
        settings.enable_backtrace,
    );
    settings.enable_sql_error_logging = env_bool_any(
        &["SALESNOTE__ENABLE_SQL_ERROR_LOG", "ENABLE_SQL_ERROR_LOG"],
        settings.enable_sql_error_logging,
    );
    settings.pool_max_size = env_u32_any(
        &["SALESNOTE__POOL_MAX_SIZE", "PG_POOL_MAX_SIZE"],
        settings.pool_max_size,
    );
    settings.pool_min_idle = env_u32_any(
        &["SALESNOTE__POOL_MIN_IDLE", "PG_POOL_MIN_IDLE"],
        settings.pool_min_idle,
    );

    settings.log_dir = env_string_any(&["SALESNOTE__LOG_DIR", "LOG_DIR"], settings.log_dir.clone());
    settings.access_log_file = env_string_any(
        &["SALESNOTE__ACCESS_LOG_FILE", "ACCESS_LOG_FILE"],
        settings.access_log_file.clone(),
    );
    settings.info_log_file = env_string_any(
        &["SALESNOTE__INFO_LOG_FILE", "INFO_LOG_FILE"],
        settings.info_log_file.clone(),
    );
    settings.error_log_file = env_string_any(
        &["SALESNOTE__ERROR_LOG_FILE", "ERROR_LOG_FILE"],
        settings.error_log_file.clone(),
    );
    if settings.bind.trim().is_empty() {
        settings.bind = default_bind();
    }

    apply_instance_log_suffixes(&mut settings);

    settings
}

fn bootstrap_env() {
    ENV_BOOTSTRAPPED.get_or_init(|| {
        let env_file = resolve_env_file_path();
        if !env_file.exists() {
            panic!("missing env file: {}", env_file.to_string_lossy());
        }

        if let Err(err) = dotenvy::from_path_override(&env_file) {
            panic!(
                "failed to load env file {}: {}",
                env_file.to_string_lossy(),
                err
            );
        }
    });
}

fn resolve_env_file_path() -> PathBuf {
    let profile = resolve_profile();
    let preferred = runtime_dir().join(format!(".env.{profile}"));
    if preferred.exists() {
        preferred
    } else {
        runtime_dir().join(".env")
    }
}

fn resolve_profile() -> &'static str {
    if let Ok(content) = fs::read_to_string(profile_file_path()) {
        if let Some(profile) = normalize_env_profile(content.trim()) {
            return profile;
        }
    }

    if let Ok(value) = env::var(ENV_PROFILE_ENV_KEY) {
        if let Some(profile) = normalize_env_profile(&value) {
            return profile;
        }
    }

    if let Ok(value) = env::var(LEGACY_ENV_PROFILE_ENV_KEY) {
        if let Some(profile) = normalize_env_profile(&value) {
            return profile;
        }
    }

    if runtime_dir().join(".env.test").exists() {
        return ENV_PROFILE_TEST;
    }

    if runtime_dir().join(".env.production").exists() {
        return ENV_PROFILE_PRODUCTION;
    }

    ENV_PROFILE_TEST
}

fn normalize_env_profile(value: &str) -> Option<&'static str> {
    match value.trim().to_ascii_lowercase().as_str() {
        ENV_PROFILE_PRODUCTION => Some(ENV_PROFILE_PRODUCTION),
        ENV_PROFILE_TEST => Some(ENV_PROFILE_TEST),
        _ => None,
    }
}

fn apply_runtime_env_flags(settings: &Settings) {
    if settings.enable_backtrace && env::var("RUST_BACKTRACE").is_err() {
        env::set_var("RUST_BACKTRACE", "1");
    }

    if settings.enable_sql_error_logging && env::var("SQLX_LOG").is_err() {
        env::set_var("SQLX_LOG", "error");
    }
}

fn env_bool_any(keys: &[&str], default: bool) -> bool {
    for key in keys {
        if let Ok(value) = env::var(key) {
            return matches!(
                value.trim().to_ascii_lowercase().as_str(),
                "1" | "true" | "yes" | "on"
            );
        }
    }
    default
}

fn env_string_any(keys: &[&str], default: String) -> String {
    for key in keys {
        if let Ok(value) = env::var(key) {
            let trimmed = value.trim();
            if !trimmed.is_empty() {
                return trimmed.to_string();
            }
        }
    }
    default
}

fn env_u32_any(keys: &[&str], default: u32) -> u32 {
    for key in keys {
        if let Ok(value) = env::var(key) {
            if let Ok(parsed) = value.trim().parse::<u32>() {
                return parsed;
            }
        }
    }
    default
}

fn apply_instance_log_suffixes(settings: &mut Settings) {
    let Some(instance_id) = env_optional_string(&["SALESNOTE__INSTANCE_ID", "INSTANCE_ID"]) else {
        return;
    };

    settings.access_log_file = with_instance_suffix(&settings.access_log_file, &instance_id);
    settings.info_log_file = with_instance_suffix(&settings.info_log_file, &instance_id);
    settings.error_log_file = with_instance_suffix(&settings.error_log_file, &instance_id);
}

fn env_optional_string(keys: &[&str]) -> Option<String> {
    for key in keys {
        if let Ok(value) = env::var(key) {
            let trimmed = value.trim();
            if !trimmed.is_empty() {
                return Some(trimmed.to_string());
            }
        }
    }
    None
}

fn with_instance_suffix(filename: &str, instance_id: &str) -> String {
    if let Some((name, ext)) = filename.rsplit_once('.') {
        format!("{name}-{instance_id}.{ext}")
    } else {
        format!("{filename}-{instance_id}")
    }
}

fn profile_file_path() -> PathBuf {
    runtime_dir().join(ENV_PROFILE_FILE)
}

fn runtime_dir() -> PathBuf {
    env::current_dir().unwrap_or_else(|_| PathBuf::from("."))
}

fn is_access_target(target: &str) -> bool {
    target == "access" || target == "actix_web::middleware::logger"
}

fn default_log_to_terminal() -> bool {
    false
}

fn default_bind() -> String {
    "0.0.0.0:8080".to_string()
}

fn default_max_request_payload_bytes() -> usize {
    12 * 1024 * 1024
}

fn default_profile_image_max_bytes() -> usize {
    10 * 1024 * 1024
}

fn default_profile_image_max_source_dimension() -> u32 {
    5_000
}

fn default_profile_image_max_source_pixels() -> u64 {
    16_000_000
}

fn default_signature_image_max_bytes() -> usize {
    10 * 1024 * 1024
}

fn default_signature_image_max_source_dimension() -> u32 {
    5_000
}

fn default_signature_image_max_source_pixels() -> u64 {
    16_000_000
}

fn default_pool_max_size() -> u32 {
    50
}

fn default_pool_min_idle() -> u32 {
    10
}

fn default_forgot_password_max_requests() -> i64 {
    2
}

fn default_auth_login_rate_limit_per_minute() -> u32 {
    10
}

fn default_auth_register_rate_limit_per_minute() -> u32 {
    5
}

fn default_auth_register_verify_rate_limit_per_minute() -> u32 {
    10
}

fn default_auth_forgot_password_rate_limit_per_minute() -> u32 {
    5
}

fn default_auth_verify_code_rate_limit_per_minute() -> u32 {
    10
}

fn default_auth_reset_password_rate_limit_per_minute() -> u32 {
    10
}

fn default_forgot_password_window_minutes() -> i64 {
    120
}

fn default_reset_code_max_incorrect_attempts() -> i64 {
    5
}

fn default_trusted_proxy_ranges() -> String {
    "127.0.0.1/32,::1/128".to_string()
}

fn default_password_min_chars() -> usize {
    8
}

fn default_password_max_chars() -> usize {
    128
}

fn default_use_redis() -> bool {
    true
}

fn default_gcs_signed_url_ttl_secs() -> u32 {
    900
}

fn default_gemini_live_model() -> String {
    "gemini-2.5-flash-native-audio-preview-12-2025".to_string()
}

fn default_gemini_live_max_session_tokens() -> i64 {
    50_000
}

fn default_enable_backtrace() -> bool {
    true
}

fn default_enable_sql_error_logging() -> bool {
    true
}

fn default_log_dir() -> String {
    "data".to_string()
}

fn default_access_log_file() -> String {
    "access.log".to_string()
}

fn default_info_log_file() -> String {
    "info.log".to_string()
}

fn default_error_log_file() -> String {
    "error.log".to_string()
}

struct LogGuards {
    _access: WorkerGuard,
    _info: WorkerGuard,
    _error: WorkerGuard,
}
