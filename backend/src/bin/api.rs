use std::net::SocketAddr;

use actix_files::Files;
use actix_web::{middleware::DefaultHeaders, middleware::Logger, web, App, HttpServer};

use salesnote_backend::{config, db};
use salesnote_backend::api::{routes, state};

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

    let app_state = state::AppState {
        pool,
        jwt_secret: settings.jwt_secret.clone(),
        refresh_token_days: settings.refresh_token_days,
        forgot_password_max_requests: settings.forgot_password_max_requests,
        forgot_password_window_minutes: settings.forgot_password_window_minutes,
        reset_code_max_incorrect_attempts: settings.reset_code_max_incorrect_attempts,
        smtp_host: settings.smtp_host.clone(),
        smtp_port: settings.smtp_port,
        smtp_username: settings.smtp_username.clone(),
        smtp_password: settings.smtp_password.clone(),
        smtp_from: settings.smtp_from.clone(),
        dashboard_url: settings.dashboard_url.clone(),
        redis: redis::Client::open(settings.redis_url.clone())
            .expect("failed to init redis client"),
    };

    let addr: SocketAddr = settings.bind.parse().expect("invalid bind addr");
    tracing::info!("listening on {}", addr);

    HttpServer::new(move || {
        let state = app_state.clone();
        App::new()
            .app_data(web::Data::new(state.clone()))
            .wrap(Logger::default())
            .wrap(
                DefaultHeaders::new()
                    .add(("X-Content-Type-Options", "nosniff"))
                    .add(("X-Frame-Options", "DENY"))
                    .add(("Referrer-Policy", "no-referrer"))
                    .add(("Permissions-Policy", "interest-cohort=()")),
            )
            .service(Files::new("/uploads", "uploads").prefer_utf8(true))
            // Temporarily disabled to isolate latency during troubleshooting.
            // .wrap(RateLimiter::new(settings.rate_limit_per_minute, state.redis.clone()))
            .configure(|cfg| routes::init_routes(cfg, state.clone()))
    })
    .bind(addr)?
    .run()
    .await
}
