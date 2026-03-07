use std::rc::Rc;

use actix_web::{
    body::MessageBody,
    dev::{Service, ServiceRequest, ServiceResponse, Transform},
    http::header,
    http::StatusCode,
    Error, HttpMessage,
};
use futures_util::future::{ok, LocalBoxFuture, Ready};
use ipnet::IpNet;
use redis::AsyncCommands;
use tokio::time::{timeout, Duration};

use crate::api::request_origin::extract_client_ip_for_service;
use crate::api::response::json_error;

#[derive(Clone)]
pub struct RateLimiter {
    pub max_per_minute: u32,
    pub auth_limits: AuthRateLimits,
    pub trusted_proxies: Vec<IpNet>,
    pub redis: redis::Client,
}

#[derive(Clone)]
pub struct AuthRateLimits {
    pub login_per_minute: u32,
    pub register_per_minute: u32,
    pub register_verify_per_minute: u32,
    pub forgot_password_per_minute: u32,
    pub verify_code_per_minute: u32,
    pub reset_password_per_minute: u32,
}

#[derive(Clone, Copy)]
struct RouteLimit {
    key: &'static str,
    max_per_minute: u32,
}

impl RateLimiter {
    pub fn new(
        max_per_minute: u32,
        auth_limits: AuthRateLimits,
        trusted_proxies: Vec<IpNet>,
        redis: redis::Client,
    ) -> Self {
        Self {
            max_per_minute,
            auth_limits,
            trusted_proxies,
            redis,
        }
    }

    fn route_limit(
        method: &str,
        path: &str,
        fallback: u32,
        auth_limits: &AuthRateLimits,
    ) -> RouteLimit {
        match (method, path) {
            ("POST", "/auth/login") => RouteLimit {
                key: "auth_login",
                max_per_minute: auth_limits.login_per_minute,
            },
            ("POST", "/auth/register") => RouteLimit {
                key: "auth_register",
                max_per_minute: auth_limits.register_per_minute,
            },
            ("POST", "/auth/register/verify") => RouteLimit {
                key: "auth_register_verify",
                max_per_minute: auth_limits.register_verify_per_minute,
            },
            ("POST", "/auth/forgot-password") => RouteLimit {
                key: "auth_forgot_password",
                max_per_minute: auth_limits.forgot_password_per_minute,
            },
            ("POST", "/auth/verify-code") => RouteLimit {
                key: "auth_verify_code",
                max_per_minute: auth_limits.verify_code_per_minute,
            },
            ("POST", "/auth/reset-password") => RouteLimit {
                key: "auth_reset_password",
                max_per_minute: auth_limits.reset_password_per_minute,
            },
            _ => RouteLimit {
                key: "global",
                max_per_minute: fallback,
            },
        }
    }
}

impl<S, B> Transform<S, ServiceRequest> for RateLimiter
where
    S: Service<ServiceRequest, Response = ServiceResponse<B>, Error = Error> + 'static,
    B: MessageBody + 'static,
{
    type Response = ServiceResponse<actix_web::body::EitherBody<B>>;
    type Error = Error;
    type Transform = RateLimiterMiddleware<S>;
    type InitError = ();
    type Future = Ready<Result<Self::Transform, Self::InitError>>;

    fn new_transform(&self, service: S) -> Self::Future {
        ok(RateLimiterMiddleware {
            service: Rc::new(service),
            max_per_minute: self.max_per_minute,
            auth_limits: self.auth_limits.clone(),
            trusted_proxies: self.trusted_proxies.clone(),
            redis: self.redis.clone(),
        })
    }
}

pub struct RateLimiterMiddleware<S> {
    service: Rc<S>,
    max_per_minute: u32,
    auth_limits: AuthRateLimits,
    trusted_proxies: Vec<IpNet>,
    redis: redis::Client,
}

impl<S, B> Service<ServiceRequest> for RateLimiterMiddleware<S>
where
    S: Service<ServiceRequest, Response = ServiceResponse<B>, Error = Error> + 'static,
    B: MessageBody + 'static,
{
    type Response = ServiceResponse<actix_web::body::EitherBody<B>>;
    type Error = Error;
    type Future = LocalBoxFuture<'static, Result<Self::Response, Self::Error>>;

    fn poll_ready(
        &self,
        ctx: &mut std::task::Context<'_>,
    ) -> std::task::Poll<Result<(), Self::Error>> {
        self.service.poll_ready(ctx)
    }

    fn call(&self, req: ServiceRequest) -> Self::Future {
        let srv = self.service.clone();
        let max_per_minute = self.max_per_minute;
        let auth_limits = self.auth_limits.clone();
        let trusted_proxies = self.trusted_proxies.clone();
        let redis = self.redis.clone();

        Box::pin(async move {
            let route_limit = RateLimiter::route_limit(
                req.method().as_str(),
                req.path(),
                max_per_minute,
                &auth_limits,
            );
            let shop_id = req.extensions().get::<i64>().copied();
            let key = if let Some(shop_id) = shop_id {
                format!("shop:{}", shop_id)
            } else {
                extract_client_ip_for_service(&req, &trusted_proxies)
                    .unwrap_or_else(|| "unknown".to_string())
            };

            let mut limited = false;
            let redis_key = format!("rate:{}:{}", route_limit.key, key);

            // Fail-open fast: if Redis is slow/down, do not block request path.
            let conn_result = timeout(
                Duration::from_millis(120),
                redis.get_multiplexed_async_connection(),
            )
            .await;

            match conn_result {
                Ok(Ok(mut conn)) => {
                    let count_result =
                        timeout(Duration::from_millis(120), conn.incr(&redis_key, 1)).await;
                    match count_result {
                        Ok(Ok(count)) => {
                            let count: i64 = count;
                            if count == 1 {
                                let expire_result = timeout(
                                    Duration::from_millis(120),
                                    conn.expire::<_, ()>(&redis_key, 60),
                                )
                                .await;
                                match expire_result {
                                    Ok(Ok(())) => {}
                                    Ok(Err(err)) => tracing::warn!(
                                        route = route_limit.key,
                                        requester = %key,
                                        redis_key = %redis_key,
                                        error = %err,
                                        "rate limit expire failed open"
                                    ),
                                    Err(_) => tracing::warn!(
                                        route = route_limit.key,
                                        requester = %key,
                                        redis_key = %redis_key,
                                        "rate limit expire timed out; failing open"
                                    ),
                                }
                            }
                            if count as u32 > route_limit.max_per_minute {
                                limited = true;
                            }
                        }
                        Ok(Err(err)) => tracing::warn!(
                            route = route_limit.key,
                            requester = %key,
                            redis_key = %redis_key,
                            error = %err,
                            "rate limit increment failed open"
                        ),
                        Err(_) => tracing::warn!(
                            route = route_limit.key,
                            requester = %key,
                            redis_key = %redis_key,
                            "rate limit increment timed out; failing open"
                        ),
                    }
                }
                Ok(Err(err)) => tracing::warn!(
                    route = route_limit.key,
                    requester = %key,
                    redis_key = %redis_key,
                    error = %err,
                    "rate limit redis connection failed open"
                ),
                Err(_) => tracing::warn!(
                    route = route_limit.key,
                    requester = %key,
                    redis_key = %redis_key,
                    "rate limit redis connection timed out; failing open"
                ),
            }

            if limited {
                let (req, _pl) = req.into_parts();
                let mut response = json_error(
                    StatusCode::TOO_MANY_REQUESTS,
                    "Too many requests. Try again later.",
                );
                let _ = response
                    .headers_mut()
                    .insert(header::RETRY_AFTER, header::HeaderValue::from_static("60"));
                return Ok(ServiceResponse::new(req, response.map_into_right_body()));
            }

            let res = srv.call(req).await?;
            Ok(res.map_into_left_body())
        })
    }
}
