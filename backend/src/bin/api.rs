use std::net::SocketAddr;

use actix_files::Files;
use actix_web::{middleware::DefaultHeaders, middleware::Logger, web, App, HttpServer};
use ipnet::IpNet;

use salesnote_backend::api::{
    middlewares::rate_limit::{AuthRateLimits, RateLimiter},
    routes, state,
};
use salesnote_backend::{config, db};

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    config::init_tracing();
    let settings = config::Settings::load();
    tracing::info!(
        "[api] starting (profile={}, env_file={})",
        config::active_env_profile(),
        config::active_env_file()
    );

    let pool = db::init(
        &settings.database_url,
        settings.pool_max_size,
        settings.pool_min_idle,
    )
    .await
    .expect("failed to init database");

    let redis = if settings.use_redis {
        Some(redis::Client::open(settings.redis_url.clone()).expect("failed to init redis client"))
    } else {
        tracing::warn!("Redis disabled via SALESNOTE__USE_REDIS=false");
        None
    };

    let app_state = state::AppState {
        pool,
        jwt_secret: settings.jwt_secret.clone(),
        max_request_payload_bytes: settings.max_request_payload_bytes,
        profile_image_max_bytes: settings.profile_image_max_bytes,
        profile_image_max_source_dimension: settings.profile_image_max_source_dimension,
        profile_image_max_source_pixels: settings.profile_image_max_source_pixels,
        signature_image_max_bytes: settings.signature_image_max_bytes,
        signature_image_max_source_dimension: settings.signature_image_max_source_dimension,
        signature_image_max_source_pixels: settings.signature_image_max_source_pixels,
        refresh_token_days: settings.refresh_token_days,
        password_min_chars: settings.password_min_chars,
        password_max_chars: settings.password_max_chars,
        forgot_password_max_requests: settings.forgot_password_max_requests,
        forgot_password_window_minutes: settings.forgot_password_window_minutes,
        reset_code_max_incorrect_attempts: settings.reset_code_max_incorrect_attempts,
        trusted_proxies: parse_trusted_proxies(&settings.trusted_proxy_ranges)
            .expect("invalid trusted proxy ranges"),
        smtp_host: settings.smtp_host.clone(),
        smtp_port: settings.smtp_port,
        smtp_username: settings.smtp_username.clone(),
        smtp_password: settings.smtp_password.clone(),
        smtp_from: settings.smtp_from.clone(),
        dashboard_url: settings.dashboard_url.clone(),
        gcs_bucket: settings.gcs_bucket.clone(),
        gcs_key_json_path: settings.gcs_key_json_path.clone(),
        gcs_signed_url_ttl_secs: settings.gcs_signed_url_ttl_secs,
        redis,
    };

    let addr: SocketAddr = settings.bind.parse().expect("invalid bind addr");
    tracing::info!("listening on {}", addr);

    HttpServer::new(move || {
        let state = app_state.clone();
        App::new()
            .app_data(web::Data::new(state.clone()))
            .app_data(web::PayloadConfig::new(state.max_request_payload_bytes))
            .app_data(web::JsonConfig::default().limit(state.max_request_payload_bytes))
            .wrap(Logger::default())
            .wrap(
                DefaultHeaders::new()
                    .add(("X-Content-Type-Options", "nosniff"))
                    .add(("X-Frame-Options", "DENY"))
                    .add(("Referrer-Policy", "no-referrer"))
                    .add(("Permissions-Policy", "interest-cohort=()")),
            )
            .service(Files::new("/uploads", "uploads").prefer_utf8(true))
            .wrap(RateLimiter::new(
                settings.rate_limit_per_minute,
                AuthRateLimits {
                    login_per_minute: settings.auth_login_rate_limit_per_minute,
                    register_per_minute: settings.auth_register_rate_limit_per_minute,
                    register_verify_per_minute: settings.auth_register_verify_rate_limit_per_minute,
                    forgot_password_per_minute: settings.auth_forgot_password_rate_limit_per_minute,
                    verify_code_per_minute: settings.auth_verify_code_rate_limit_per_minute,
                    reset_password_per_minute: settings.auth_reset_password_rate_limit_per_minute,
                },
                state.trusted_proxies.clone(),
                state.redis.clone(),
            ))
            .configure(|cfg| routes::init_routes(cfg, state.clone()))
    })
    .bind(addr)?
    .run()
    .await
}

fn parse_trusted_proxies(value: &str) -> Result<Vec<IpNet>, String> {
    value
        .split(',')
        .map(str::trim)
        .filter(|part| !part.is_empty())
        .map(|part| {
            part.parse::<IpNet>()
                .map_err(|_| format!("invalid trusted proxy range: {part}"))
        })
        .collect()
}
