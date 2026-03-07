use actix_web::{
    http::header::{self, HeaderMap},
    http::StatusCode,
    web, HttpRequest, HttpResponse, Responder,
};
use chrono_tz::Tz;
use jsonwebtoken::{decode, DecodingKey, Validation};
use rand::Rng;
use std::str::FromStr;

use crate::api::middlewares::auth::AuthDeviceId;
use crate::api::response::{json_error, json_ok};
use crate::api::state::AppState;
use crate::models::{
    build_token, AuthForgotPasswordInput, AuthLoginInput, AuthLoginResponse, AuthRefreshInput,
    AuthRegisterInput, AuthResetPasswordInput, AuthVerifyCodeInput, AuthVerifySignupInput,
    AuthorizedDeviceDeletePayload, AuthorizedDeviceListPayload, Claims, DeviceSession,
    LoginOneStepPayload, LoginOneStepResult, ResetPasswordResult, ShopAuthRecord,
};

pub async fn register(
    state: web::Data<AppState>,
    payload: web::Json<AuthRegisterInput>,
) -> impl Responder {
    let mut input = payload.into_inner();
    input.shop_name = input.shop_name.trim().to_string();
    input.phone = input.phone.trim().to_string();
    input.email = input.email.trim().to_lowercase();
    if let Some(address) = input.address.as_mut() {
        *address = address.trim().to_string();
    }
    input.timezone = input.timezone.trim().to_string();

    if let Err(msg) = validate_register(&input) {
        return json_error(StatusCode::BAD_REQUEST, msg);
    }

    let mut rng = rand::thread_rng();
    let code = format!("{:06}", rng.gen_range(0..=999_999));
    let window_minutes = state.forgot_password_window_minutes.max(1);
    let max_requests = state.forgot_password_max_requests.max(1);

    match ShopAuthRecord::create_signup_verification_request(
        &state.pool,
        &input.phone,
        &input.email,
        &code,
        window_minutes,
        max_requests,
    )
    .await
    {
        Ok(result) => {
            if result.has_existing_shop {
                return json_error(StatusCode::BAD_REQUEST, "phone or email already exists");
            }
            let max_requests_i32 = i32::try_from(max_requests).unwrap_or(i32::MAX);
            if result.request_count >= max_requests_i32 {
                return json_error(
                    StatusCode::TOO_MANY_REQUESTS,
                    "Too many requests. Try again later.",
                );
            }
            let email = input.email.clone();
            let shop_name = input.shop_name.clone();
            let code_clone = code.clone();
            actix_web::rt::spawn(async move {
                let settings = crate::config::Settings::load();
                let _ = crate::api::email::send_signup_verification_email_direct(
                    &settings,
                    &email,
                    &shop_name,
                    &code_clone,
                )
                .await;
            });
            json_ok("Verification code sent.")
        }
        Err(e) => {
            tracing::error!("register error: {}", e);
            json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Server error. Please try again.",
            )
        }
    }
}

pub async fn verify_signup(
    state: web::Data<AppState>,
    req: HttpRequest,
    payload: web::Json<AuthVerifySignupInput>,
) -> impl Responder {
    let mut input = payload.into_inner();
    input.input.shop_name = input.input.shop_name.trim().to_string();
    input.input.phone = input.input.phone.trim().to_string();
    input.input.email = input.input.email.trim().to_lowercase();
    if let Some(address) = input.input.address.as_mut() {
        *address = address.trim().to_string();
    }
    input.input.timezone = input.input.timezone.trim().to_string();

    if let Err(msg) = validate_register(&input.input) {
        return json_error(StatusCode::BAD_REQUEST, msg);
    }

    let code = input.code.trim();
    if !is_valid_reset_code(code) {
        return json_error(StatusCode::BAD_REQUEST, "invalid code");
    }

    let max_incorrect_attempts = state.reset_code_max_incorrect_attempts.max(1);
    let verification = match ShopAuthRecord::verify_signup_code(
        &state.pool,
        &input.input.phone,
        &input.input.email,
        code,
        max_incorrect_attempts,
    )
    .await
    {
        Ok(v) => v,
        Err(e) => {
            tracing::error!("verify signup flow error: {}", e);
            return json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Server error. Please try again.",
            );
        }
    };

    if verification.too_many_attempts {
        return json_error(
            StatusCode::TOO_MANY_REQUESTS,
            "Too many incorrect attempts. Request a new code.",
        );
    }

    if !verification.has_pending_code || !verification.is_valid {
        return json_error(StatusCode::UNAUTHORIZED, "invalid or expired code");
    }

    let ip_address = extract_client_ip(&req);
    let user_agent = req
        .headers()
        .get(header::USER_AGENT)
        .and_then(|v| v.to_str().ok())
        .map(|v| v.to_string());
    let location = build_location_from_headers(req.headers());

    let session = match ShopAuthRecord::create_verified_signup_session(
        &state.pool,
        &input.input,
        &state.dashboard_url,
        input.device_name.as_ref().map(|v| v.trim().to_string()),
        input.device_platform.as_ref().map(|v| v.trim().to_string()),
        input.device_os.as_ref().map(|v| v.trim().to_string()),
        ip_address,
        location,
        user_agent,
        state.refresh_token_days,
    )
    .await
    {
        Ok(session) => session,
        Err(e) => {
            tracing::error!("verify signup create error: {}", e);
            if let sqlx::Error::Database(db_err) = &e {
                if db_err.code().as_deref() == Some("23505") {
                    return json_error(StatusCode::BAD_REQUEST, "phone or email already exists");
                }
            }
            return json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Unable to create account right now.",
            );
        }
    };

    let _ = ShopAuthRecord::clear_signup_verification_codes(
        &state.pool,
        &input.input.phone,
        &input.input.email,
    )
    .await;

    let token = match build_token(
        session.shop.id,
        Some(session.device_session_id),
        &state.jwt_secret,
    ) {
        Ok(t) => t,
        Err(_) => {
            return json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Unable to create session. Please try again.",
            );
        }
    };

    json_ok(AuthLoginResponse {
        access_token: token,
        refresh_token: session.refresh_token,
        shop: session.shop,
    })
}

pub async fn login(
    state: web::Data<AppState>,
    req: HttpRequest,
    payload: web::Json<AuthLoginInput>,
) -> impl Responder {
    let mut phone_or_email = payload.phone_or_email.trim().to_string();
    if phone_or_email.contains('@') {
        phone_or_email = phone_or_email.to_lowercase();
    }
    let ip_address = extract_client_ip(&req);
    let user_agent = req
        .headers()
        .get(header::USER_AGENT)
        .and_then(|v| v.to_str().ok())
        .map(|v| v.to_string());
    let location = build_location_from_headers(req.headers());
    let login_payload = LoginOneStepPayload {
        phone_or_email,
        password: payload.password.clone(),
        device_name: payload.device_name.as_ref().map(|v| v.trim().to_string()),
        device_platform: payload
            .device_platform
            .as_ref()
            .map(|v| v.trim().to_string()),
        device_os: payload.device_os.as_ref().map(|v| v.trim().to_string()),
        ip_address,
        location,
        user_agent,
        refresh_token_days: state.refresh_token_days,
        max_failed_attempts: 5,
        lock_minutes: 15,
    };

    let session = match ShopAuthRecord::login_one_step(&state.pool, &login_payload).await {
        Ok(LoginOneStepResult::Success(s)) => s,
        Ok(LoginOneStepResult::InvalidCredentials) => {
            return json_error(StatusCode::UNAUTHORIZED, "invalid credentials");
        }
        Ok(LoginOneStepResult::Locked) => {
            return json_error(
                StatusCode::TOO_MANY_REQUESTS,
                "Account locked. Try again later.",
            );
        }
        Err(e) => {
            tracing::error!("auth login failed: {}", e);
            return json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Unable to sign you in right now.",
            );
        }
    };

    let token = match build_token(
        session.shop.id,
        Some(session.device_session_id),
        &state.jwt_secret,
    ) {
        Ok(t) => t,
        Err(_) => {
            return json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Unable to create session. Please try again.",
            );
        }
    };

    json_ok(AuthLoginResponse {
        access_token: token,
        refresh_token: session.refresh_token,
        shop: session.shop,
    })
}

pub async fn refresh_token(
    state: web::Data<AppState>,
    payload: web::Json<AuthRefreshInput>,
) -> impl Responder {
    let raw = payload.refresh_token.trim();
    if raw.is_empty() {
        return json_error(StatusCode::BAD_REQUEST, "refresh token required");
    }

    let refreshed =
        match ShopAuthRecord::rotate_refresh_with_shop(&state.pool, raw, state.refresh_token_days)
            .await
        {
            Ok(v) => v,
            Err(e) => {
                tracing::error!("refresh token rotate error: {}", e);
                return json_error(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "Unable to refresh session.",
                );
            }
        };

    let Some(refreshed) = refreshed else {
        return json_error(StatusCode::UNAUTHORIZED, "invalid refresh token");
    };

    let token = match build_token(
        refreshed.shop_id,
        refreshed.device_session_id,
        &state.jwt_secret,
    ) {
        Ok(t) => t,
        Err(_) => {
            return json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Unable to refresh session.",
            );
        }
    };

    json_ok(AuthLoginResponse {
        access_token: token,
        refresh_token: refreshed.refresh_token,
        shop: refreshed.shop,
    })
}

pub async fn forgot_password(
    state: web::Data<AppState>,
    payload: web::Json<AuthForgotPasswordInput>,
) -> impl Responder {
    let Some(phone_or_email) =
        normalize_phone_or_email(payload.phone_or_email.as_deref(), payload.email.as_deref())
    else {
        return json_error(StatusCode::BAD_REQUEST, "phone_or_email required");
    };

    let mut rng = rand::thread_rng();
    let code = format!("{:06}", rng.gen_range(0..=999_999));
    let window_minutes = state.forgot_password_window_minutes.max(1);
    let max_requests = state.forgot_password_max_requests.max(1);

    let result = match ShopAuthRecord::create_forgot_password_request(
        &state.pool,
        &phone_or_email,
        &code,
        window_minutes,
        max_requests,
    )
    .await
    {
        Ok(v) => v,
        Err(e) => {
            tracing::error!("forgot password flow error: {}", e);
            return json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Server error. Please try again.",
            );
        }
    };

    let max_requests_i32 = i32::try_from(max_requests).unwrap_or(i32::MAX);
    if result.has_shop && result.request_count >= max_requests_i32 {
        return json_error(
            StatusCode::TOO_MANY_REQUESTS,
            "Too many requests. Try again later.",
        );
    }

    if result.has_shop {
        if let Some(shop_email) = result.shop_email {
            let code_clone = code.clone();
            actix_web::rt::spawn(async move {
                let settings = crate::config::Settings::load();
                let _ = crate::api::email::send_password_reset_email_direct(
                    &settings,
                    &shop_email,
                    &code_clone,
                )
                .await;
            });
        }
    }

    json_ok("If that account exists, a reset code has been sent.")
}

pub async fn verify_code(
    state: web::Data<AppState>,
    payload: web::Json<AuthVerifyCodeInput>,
) -> impl Responder {
    let Some(phone_or_email) = normalize_strict_phone_or_email(&payload.phone_or_email) else {
        return json_error(StatusCode::BAD_REQUEST, "invalid phone or email");
    };

    let code = payload.code.trim();
    if !is_valid_reset_code(code) {
        return json_error(StatusCode::BAD_REQUEST, "invalid code");
    }
    let max_incorrect_attempts = state.reset_code_max_incorrect_attempts.max(1);

    let result = match ShopAuthRecord::verify_reset_code(
        &state.pool,
        &phone_or_email,
        code,
        max_incorrect_attempts,
    )
    .await
    {
        Ok(v) => v,
        Err(e) => {
            tracing::error!("verify code flow error: {}", e);
            return json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Server error. Please try again.",
            );
        }
    };

    if result.too_many_attempts {
        return json_error(
            StatusCode::TOO_MANY_REQUESTS,
            "Too many incorrect attempts. Request a new code.",
        );
    }

    if !result.has_shop || !result.is_valid {
        return json_error(StatusCode::UNAUTHORIZED, "invalid or expired code");
    }

    json_ok("Code verified")
}

pub async fn reset_password(
    state: web::Data<AppState>,
    payload: web::Json<AuthResetPasswordInput>,
) -> impl Responder {
    let Some(phone_or_email) = normalize_strict_phone_or_email(&payload.phone_or_email) else {
        return json_error(StatusCode::BAD_REQUEST, "invalid phone or email");
    };

    let code = payload.code.trim();
    if !is_valid_reset_code(code) {
        return json_error(StatusCode::BAD_REQUEST, "invalid code");
    }

    let password = payload.new_password.trim();
    if password.len() < 5 {
        return json_error(
            StatusCode::BAD_REQUEST,
            "password must be at least 5 characters",
        );
    }
    if password.len() > 20 {
        return json_error(
            StatusCode::BAD_REQUEST,
            "password must be 20 characters or less",
        );
    }
    let max_incorrect_attempts = state.reset_code_max_incorrect_attempts.max(1);

    match ShopAuthRecord::reset_password_with_code(
        &state.pool,
        &phone_or_email,
        code,
        password,
        max_incorrect_attempts,
    )
    .await
    {
        Ok(ResetPasswordResult::Success) => json_ok("Password reset successful."),
        Ok(ResetPasswordResult::TooManyAttempts) => json_error(
            StatusCode::TOO_MANY_REQUESTS,
            "Too many incorrect attempts. Request a new code.",
        ),
        Ok(ResetPasswordResult::InvalidCode) => {
            json_error(StatusCode::UNAUTHORIZED, "invalid or expired code")
        }
        Err(e) => {
            tracing::error!("reset password flow error: {}", e);
            json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Server error. Please try again.",
            )
        }
    }
}

pub async fn list_devices(
    state: web::Data<AppState>,
    shop_id: web::ReqData<i64>,
    device_id: web::ReqData<AuthDeviceId>,
) -> impl Responder {
    let payload = AuthorizedDeviceListPayload {
        shop_id: *shop_id,
        current_device_id: (*device_id).0,
    };

    match DeviceSession::list_authorized(&state.pool, &payload).await {
        Ok(devices) => json_ok(devices),
        Err(e) => {
            tracing::error!("list devices error: {}", e);
            json_error(StatusCode::INTERNAL_SERVER_ERROR, "Unable to load devices.")
        }
    }
}

pub async fn delete_device(
    state: web::Data<AppState>,
    shop_id: web::ReqData<i64>,
    device_id: web::ReqData<AuthDeviceId>,
    path: web::Path<i64>,
) -> impl Responder {
    let target_device_id = path.into_inner();
    let payload = AuthorizedDeviceDeletePayload {
        shop_id: *shop_id,
        current_device_id: (*device_id).0,
        target_device_id,
    };

    match DeviceSession::delete_authorized(&state.pool, &payload).await {
        Ok(true) => json_ok("Device removed"),
        Ok(false) => json_error(StatusCode::NOT_FOUND, "not found"),
        Err(e) => {
            tracing::error!("delete device error: {}", e);
            json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Unable to remove device.",
            )
        }
    }
}

fn build_location_from_headers(headers: &HeaderMap) -> Option<String> {
    let city = headers
        .get("X-Geo-City")
        .and_then(|v| v.to_str().ok())
        .map(|v| v.trim().to_string());
    let region = headers
        .get("X-Geo-Region")
        .and_then(|v| v.to_str().ok())
        .map(|v| v.trim().to_string());
    let country = headers
        .get("X-Geo-Country")
        .or_else(|| headers.get("CF-IPCountry"))
        .and_then(|v| v.to_str().ok())
        .map(|v| v.trim().to_string());

    let parts: Vec<String> = [city, region, country]
        .into_iter()
        .flatten()
        .filter(|p| !p.is_empty())
        .collect();

    if parts.is_empty() {
        None
    } else {
        Some(parts.join(", "))
    }
}

fn extract_client_ip(req: &HttpRequest) -> Option<String> {
    if let Some(v) = req.headers().get("X-Forwarded-For") {
        if let Ok(s) = v.to_str() {
            if let Some(ip) = s
                .split(',')
                .next()
                .map(|v| v.trim())
                .filter(|v| !v.is_empty())
            {
                return Some(ip.to_string());
            }
        }
    }
    if let Some(v) = req.headers().get("X-Real-IP") {
        if let Ok(s) = v.to_str() {
            if !s.trim().is_empty() {
                return Some(s.trim().to_string());
            }
        }
    }
    req.connection_info()
        .realip_remote_addr()
        .map(|v| v.to_string())
        .or_else(|| req.peer_addr().map(|a| a.ip().to_string()))
}

fn validate_register(input: &AuthRegisterInput) -> Result<(), &'static str> {
    if input.shop_name.len() < 3 {
        return Err("shop name must be at least 3 characters");
    }
    if input.shop_name.len() > 40 {
        return Err("shop name must be 40 characters or less");
    }

    if !is_valid_phone(&input.phone) {
        return Err("invalid phone number");
    }

    if input.email.is_empty() || input.email.len() > 50 || !is_valid_email(&input.email) {
        return Err("invalid email");
    }

    if input.password.len() < 5 {
        return Err("password must be at least 5 characters");
    }
    if input.password.len() > 20 {
        return Err("password must be 20 characters or less");
    }

    if input.timezone.is_empty() {
        return Err("timezone is required");
    }
    if !is_valid_timezone(&input.timezone) {
        return Err("invalid timezone");
    }

    let address = input.address.as_deref().unwrap_or("").trim();
    if address.is_empty() {
        return Err("shop address is required");
    }
    if address.len() < 8 {
        return Err("address must be at least 8 characters");
    }
    if address.len() > 40 {
        return Err("address must be 40 characters or less");
    }
    let words = count_words(address);
    if words < 4 {
        return Err("address must be at least 4 words");
    }
    if words > 10 {
        return Err("address must be 10 words or less");
    }

    Ok(())
}

fn is_valid_email(email: &str) -> bool {
    let parts: Vec<&str> = email.split('@').collect();
    if parts.len() != 2 {
        return false;
    }
    if parts[0].is_empty() || parts[1].is_empty() {
        return false;
    }
    parts[1].contains('.')
}

fn is_valid_phone(phone: &str) -> bool {
    let trimmed = phone.trim();
    if !trimmed.starts_with('+') {
        return false;
    }
    let digits: String = trimmed
        .chars()
        .skip(1)
        .filter(|c| c.is_ascii_digit())
        .collect();
    if digits.len() < 8 || digits.len() > 15 {
        return false;
    }
    !digits.starts_with('0')
}

fn normalize_phone_or_email(
    phone_or_email: Option<&str>,
    email_fallback: Option<&str>,
) -> Option<String> {
    let primary = phone_or_email.unwrap_or("").trim();
    let fallback = email_fallback.unwrap_or("").trim();
    let value = if !primary.is_empty() {
        primary
    } else {
        fallback
    };
    normalize_strict_phone_or_email(value)
}

fn normalize_strict_phone_or_email(value: &str) -> Option<String> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        return None;
    }

    if trimmed.contains('@') {
        let email = trimmed.to_lowercase();
        if email.len() > 50 || !is_valid_email(&email) {
            return None;
        }
        return Some(email);
    }

    if !is_valid_phone(trimmed) {
        return None;
    }

    Some(trimmed.to_string())
}

fn is_valid_reset_code(value: &str) -> bool {
    value.len() == 6 && value.chars().all(|ch| ch.is_ascii_digit())
}

fn count_words(text: &str) -> usize {
    text.replace(',', " ")
        .split_whitespace()
        .filter(|w| !w.is_empty())
        .count()
}

fn is_valid_timezone(value: &str) -> bool {
    Tz::from_str(value).is_ok()
}

pub fn auth_claims(headers: &HeaderMap, jwt_secret: &str) -> Result<Claims, StatusCode> {
    let value = headers
        .get(header::AUTHORIZATION)
        .and_then(|v| v.to_str().ok())
        .ok_or(StatusCode::UNAUTHORIZED)?;

    let token = value
        .strip_prefix("Bearer ")
        .ok_or(StatusCode::UNAUTHORIZED)?;

    let data = decode::<Claims>(
        token,
        &DecodingKey::from_secret(jwt_secret.as_bytes()),
        &Validation::default(),
    )
    .map_err(|_| StatusCode::UNAUTHORIZED)?;

    Ok(data.claims)
}

pub async fn require_active_session(
    state: &AppState,
    req: &HttpRequest,
    shop_id: i64,
) -> Result<i64, HttpResponse> {
    let claims = match auth_claims(req.headers(), &state.jwt_secret) {
        Ok(c) => c,
        Err(_) => return Err(json_error(StatusCode::UNAUTHORIZED, "unauthorized")),
    };
    let device_id = match claims.sid {
        Some(id) => id,
        None => return Err(json_error(StatusCode::UNAUTHORIZED, "unauthorized")),
    };

    let active = match DeviceSession::validate_and_touch_if_stale(
        &state.pool,
        shop_id,
        device_id,
        5,
    )
    .await
    {
        Ok(v) => v,
        Err(e) => {
            tracing::error!("device session validate error: {}", e);
            return Err(json_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Server error. Please try again.",
            ));
        }
    };

    if !active {
        return Err(json_error(StatusCode::UNAUTHORIZED, "unauthorized"));
    }

    Ok(device_id)
}
