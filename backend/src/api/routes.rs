use actix_web::web;

use crate::api::handlers::*;
use crate::api::middlewares::auth::AuthGuard;
use crate::api::state::AppState;

pub fn init_routes(cfg: &mut web::ServiceConfig, state: AppState) {
    let auth_guard = AuthGuard::new(state.jwt_secret);

    cfg.service(web::resource("/health").route(web::get().to(health)));

    cfg.service(
        web::scope("/auth")
            .route("/register", web::post().to(register))
            .route("/login", web::post().to(login))
            .route("/refresh", web::post().to(refresh_token))
            .route("/forgot-password", web::post().to(forgot_password))
            .route("/verify-code", web::post().to(verify_code))
            .route("/reset-password", web::post().to(reset_password)),
    );

    cfg.service(
        web::resource("/home")
            .wrap(auth_guard.clone())
            .route(web::get().to(home_summary)),
    );

    cfg.service(
        web::resource("/shop")
            .wrap(auth_guard.clone())
            .route(web::get().to(get_my_shop))
            .route(web::patch().to(update_my_shop)),
    );

    cfg.service(
        web::resource("/settings")
            .wrap(auth_guard.clone())
            .route(web::get().to(get_settings_summary)),
    );

    cfg.service(
        web::resource("/shop/subscribe")
            .wrap(auth_guard.clone())
            .route(web::post().to(subscribe_fcm)),
    );

    cfg.service(
        web::resource("/devices")
            .wrap(auth_guard.clone())
            .route(web::get().to(list_devices)),
    );

    cfg.service(
        web::resource("/devices/{id}")
            .wrap(auth_guard.clone())
            .route(web::delete().to(delete_device)),
    );

    cfg.service(
        web::resource("/signatures")
            .wrap(auth_guard.clone())
            .route(web::post().to(create_signature))
            .route(web::get().to(list_signatures)),
    );

    cfg.service(
        web::resource("/signatures/{id}")
            .wrap(auth_guard.clone())
            .route(web::delete().to(delete_signature)),
    );

    cfg.service(
        web::resource("/sales")
            .wrap(auth_guard.clone())
            .route(web::get().to(list_sales))
            .route(web::post().to(create_sale)),
    );

    cfg.service(
        web::resource("/sales/{id}")
            .wrap(auth_guard.clone())
            .route(web::get().to(get_sale))
            .route(web::patch().to(update_sale))
            .route(web::delete().to(delete_sale)),
    );

    cfg.service(
        web::resource("/analytics/summary")
            .wrap(auth_guard.clone())
            .route(web::get().to(analytics_summary)),
    );
}
