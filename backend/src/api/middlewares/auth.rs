use std::rc::Rc;

use crate::api::handlers::auth;
use crate::api::response::json_error;
use actix_web::{
    body::MessageBody,
    dev::{Service, ServiceRequest, ServiceResponse, Transform},
    http::StatusCode,
    Error, HttpMessage,
};
use futures_util::future::{ok, LocalBoxFuture, Ready};

#[derive(Clone, Copy, Debug)]
pub struct AuthDeviceId(pub i64);

#[derive(Clone)]
pub struct AuthGuard {
    pub jwt_secret: String,
}

impl AuthGuard {
    pub fn new(jwt_secret: String) -> Self {
        Self { jwt_secret }
    }
}

impl<S, B> Transform<S, ServiceRequest> for AuthGuard
where
    S: Service<ServiceRequest, Response = ServiceResponse<B>, Error = Error> + 'static,
    B: MessageBody + 'static,
{
    type Response = ServiceResponse<actix_web::body::EitherBody<B>>;
    type Error = Error;
    type Transform = AuthGuardMiddleware<S>;
    type InitError = ();
    type Future = Ready<Result<Self::Transform, Self::InitError>>;

    fn new_transform(&self, service: S) -> Self::Future {
        ok(AuthGuardMiddleware {
            service: Rc::new(service),
            jwt_secret: self.jwt_secret.clone(),
        })
    }
}

pub struct AuthGuardMiddleware<S> {
    service: Rc<S>,
    jwt_secret: String,
}

impl<S, B> Service<ServiceRequest> for AuthGuardMiddleware<S>
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
        let jwt_secret = self.jwt_secret.clone();
        let srv = self.service.clone();

        Box::pin(async move {
            match auth::auth_claims(req.headers(), &jwt_secret) {
                Ok(claims) => {
                    let shop_id = match claims.sub.parse::<i64>() {
                        Ok(id) => id,
                        Err(_) => {
                            let (req, _pl) = req.into_parts();
                            let response =
                                json_error(StatusCode::UNAUTHORIZED, "unauthorized");
                            return Ok(ServiceResponse::new(
                                req,
                                response.map_into_right_body(),
                            ));
                        }
                    };

                    if claims.sid.is_none() {
                        let (req, _pl) = req.into_parts();
                        let response = json_error(StatusCode::UNAUTHORIZED, "unauthorized");
                        return Ok(ServiceResponse::new(req, response.map_into_right_body()));
                    }

                    let device_id = match claims.sid {
                        Some(id) => id,
                        None => {
                            let (req, _pl) = req.into_parts();
                            let response = json_error(StatusCode::UNAUTHORIZED, "unauthorized");
                            return Ok(ServiceResponse::new(req, response.map_into_right_body()));
                        }
                    };

                    req.extensions_mut().insert(shop_id);
                    req.extensions_mut().insert(AuthDeviceId(device_id));
                    let res = srv.call(req).await?;
                    Ok(res.map_into_left_body())
                }
                Err(_) => {
                    let (req, _pl) = req.into_parts();
                    let response =
                        json_error(StatusCode::UNAUTHORIZED, "unauthorized");
                    Ok(ServiceResponse::new(req, response.map_into_right_body()))
                }
            }
        })
    }
}
