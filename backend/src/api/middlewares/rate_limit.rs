use std::rc::Rc;

use actix_web::{
    body::MessageBody,
    dev::{Service, ServiceRequest, ServiceResponse, Transform},
    http::StatusCode,
    Error, HttpMessage,
};
use futures_util::future::{ok, LocalBoxFuture, Ready};
use redis::AsyncCommands;
use tokio::time::{timeout, Duration};

use crate::api::response::json_error;

#[derive(Clone)]
pub struct RateLimiter {
    pub max_per_minute: u32,
    pub redis: redis::Client,
}

impl RateLimiter {
    pub fn new(max_per_minute: u32, redis: redis::Client) -> Self {
        Self {
            max_per_minute,
            redis,
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
            redis: self.redis.clone(),
        })
    }
}

pub struct RateLimiterMiddleware<S> {
    service: Rc<S>,
    max_per_minute: u32,
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
        let redis = self.redis.clone();

        Box::pin(async move {
            let shop_id = req.extensions().get::<i64>().copied();
            let key = if let Some(shop_id) = shop_id {
                format!("shop:{}", shop_id)
            } else {
                req.connection_info()
                    .realip_remote_addr()
                    .map(|v| v.to_string())
                    .unwrap_or_else(|| "unknown".to_string())
            };

            let mut limited = false;
            let redis_key = format!("rate:{}", key);

            // Fail-open fast: if Redis is slow/down, do not block request path.
            let conn_result = timeout(
                Duration::from_millis(120),
                redis.get_multiplexed_async_connection(),
            )
            .await;

            if let Ok(Ok(mut conn)) = conn_result {
                let count_result = timeout(Duration::from_millis(120), conn.incr(&redis_key, 1)).await;
                if let Ok(Ok(count)) = count_result {
                    let count: i64 = count;
                    if count == 1 {
                        let _ = timeout(Duration::from_millis(120), conn.expire::<_, ()>(&redis_key, 60)).await;
                    }
                    if count as u32 > max_per_minute {
                        limited = true;
                    }
                }
            }

            if limited {
                let (req, _pl) = req.into_parts();
                let response = json_error(
                    StatusCode::TOO_MANY_REQUESTS,
                    "Too many requests. Try again later.",
                );
                return Ok(ServiceResponse::new(req, response.map_into_right_body()));
            }

            let res = srv.call(req).await?;
            Ok(res.map_into_left_body())
        })
    }
}
