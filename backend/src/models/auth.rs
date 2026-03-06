use jsonwebtoken::{encode, EncodingKey, Header};
use rand::{rngs::OsRng, RngCore};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use sqlx::Row;
use std::time::{SystemTime, UNIX_EPOCH};

use crate::models::ShopProfile;

#[derive(Debug, Deserialize, Clone)]
pub struct AuthRegisterInput {
    pub shop_name: String,
    pub phone: String,
    pub email: String,
    pub password: String,
    pub address: Option<String>,
    pub logo_url: Option<String>,
    pub timezone: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct AuthLoginInput {
    pub phone_or_email: String,
    pub password: String,
    pub device_name: Option<String>,
    pub device_platform: Option<String>,
    pub device_os: Option<String>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct AuthForgotPasswordInput {
    #[serde(default)]
    pub phone_or_email: Option<String>,
    #[serde(default)]
    pub email: Option<String>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct AuthVerifyCodeInput {
    pub phone_or_email: String,
    pub code: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct AuthResetPasswordInput {
    pub phone_or_email: String,
    pub code: String,
    pub new_password: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct AuthRefreshInput {
    pub refresh_token: String,
}

#[derive(Debug, Serialize)]
pub struct AuthLoginResponse {
    pub access_token: String,
    pub refresh_token: String,
    pub shop: ShopProfile,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String,
    pub exp: usize,
    #[serde(default)]
    pub sid: Option<i64>,
}

#[derive(Debug, Clone)]
pub struct CreateShopPayload {
    pub input: AuthRegisterInput,
    pub password: String,
}

#[derive(Debug, Clone)]
pub struct FindShopPayload {
    pub phone_or_email: String,
}

#[derive(Debug, Clone)]
pub struct FindShopByEmailPayload {
    pub email: String,
}

#[derive(Debug, Clone)]
pub struct CreateResetCodePayload {
    pub shop_id: i64,
    pub code: String,
}

#[derive(Debug, Clone)]
pub struct ResetCodeCountPayload {
    pub shop_id: i64,
    pub window_minutes: i64,
}

#[derive(Debug, Clone)]
pub struct RefreshTokenRotation {
    pub shop_id: i64,
    pub refresh_token: String,
    pub device_session_id: Option<i64>,
}

#[derive(Debug, Clone)]
pub struct LoginSessionPayload {
    pub shop_id: i64,
    pub device_name: Option<String>,
    pub device_platform: Option<String>,
    pub device_os: Option<String>,
    pub ip_address: Option<String>,
    pub location: Option<String>,
    pub user_agent: Option<String>,
    pub refresh_token_days: i64,
}

#[derive(Debug, Clone)]
pub struct LoginOneStepPayload {
    pub phone_or_email: String,
    pub password: String,
    pub device_name: Option<String>,
    pub device_platform: Option<String>,
    pub device_os: Option<String>,
    pub ip_address: Option<String>,
    pub location: Option<String>,
    pub user_agent: Option<String>,
    pub refresh_token_days: i64,
    pub max_failed_attempts: i64,
    pub lock_minutes: i64,
}

#[derive(Debug)]
pub enum LoginOneStepResult {
    Success(LoginSessionResult),
    InvalidCredentials,
    Locked,
}

#[derive(Debug)]
pub struct LoginSessionResult {
    pub device_session_id: i64,
    pub shop: ShopProfile,
    pub refresh_token: String,
}

#[derive(Debug)]
pub struct RefreshSessionResult {
    pub shop_id: i64,
    pub device_session_id: Option<i64>,
    pub shop: ShopProfile,
    pub refresh_token: String,
}

#[derive(Debug)]
pub struct ForgotPasswordResult {
    pub has_shop: bool,
    pub request_count: i32,
    pub shop_email: Option<String>,
}

#[derive(Debug)]
pub struct VerifyResetCodeResult {
    pub has_shop: bool,
    pub is_valid: bool,
    pub too_many_attempts: bool,
}

#[derive(Debug)]
pub enum ResetPasswordResult {
    Success,
    InvalidCode,
    TooManyAttempts,
}
#[derive(Debug)]
pub struct ShopAuthRecord {
    pub id: i64,
    pub name: String,
    pub phone: String,
    pub email: String,
    pub address: Option<String>,
    pub logo_url: Option<String>,
    pub timezone: String,
    pub created_at: String,
    pub password_hash: String,
    pub failed_login_attempts: i32,
    pub locked_until: Option<String>,
}

impl ShopAuthRecord {
    pub fn to_profile(&self) -> ShopProfile {
        ShopProfile {
            id: self.id.clone(),
            name: self.name.clone(),
            phone: self.phone.clone(),
            email: self.email.clone(),
            address: self.address.clone(),
            logo_url: self.logo_url.clone(),
            total_revenue: 0.0,
            total_orders: 0,
            total_customers: 0,
            timezone: self.timezone.clone(),
            created_at: self.created_at.clone(),
        }
    }

    pub async fn find_for_login(
        pool: &sqlx::PgPool,
        payload: &FindShopPayload,
    ) -> Result<Option<ShopAuthRecord>, sqlx::Error> {
        let row = sqlx::query(
            "SELECT id, name, phone, email, password_hash, address, logo_url,
                    created_at::text as created_at,
                    failed_login_attempts,
                    locked_until::text as locked_until,
                    timezone
             FROM shops WHERE phone = $1 OR email = $2",
        )
        .bind(&payload.phone_or_email)
        .bind(&payload.phone_or_email)
        .fetch_optional(pool)
        .await?;

        Ok(row.map(|row| ShopAuthRecord {
            id: row.get("id"),
            name: row.get("name"),
            phone: row.get("phone"),
            email: row.get("email"),
            address: row.get("address"),
            logo_url: row.get("logo_url"),
            created_at: row.get("created_at"),
            password_hash: row.get("password_hash"),
            failed_login_attempts: row.get("failed_login_attempts"),
            locked_until: row.get("locked_until"),
            timezone: row.get("timezone"),
        }))
    }

    pub async fn find_by_email(
        pool: &sqlx::PgPool,
        payload: &FindShopByEmailPayload,
    ) -> Result<Option<ShopAuthRecord>, sqlx::Error> {
        let row = sqlx::query(
            "SELECT id, name, phone, email, password_hash, address, logo_url,
                    created_at::text as created_at,
                    failed_login_attempts,
                    locked_until::text as locked_until,
                    timezone
             FROM shops WHERE email = $1",
        )
        .bind(&payload.email)
        .fetch_optional(pool)
        .await?;

        Ok(row.map(|row| ShopAuthRecord {
            id: row.get("id"),
            name: row.get("name"),
            phone: row.get("phone"),
            email: row.get("email"),
            address: row.get("address"),
            logo_url: row.get("logo_url"),
            created_at: row.get("created_at"),
            password_hash: row.get("password_hash"),
            failed_login_attempts: row.get("failed_login_attempts"),
            locked_until: row.get("locked_until"),
            timezone: row.get("timezone"),
        }))
    }

    pub async fn record_failed_login(
        pool: &sqlx::PgPool,
        shop_id: i64,
        max_attempts: i64,
        lock_minutes: i64,
    ) -> Result<(), sqlx::Error> {
        sqlx::query(
            "UPDATE shops
             SET failed_login_attempts = failed_login_attempts + 1,
                 locked_until = CASE
                     WHEN failed_login_attempts + 1 >= $1 THEN NOW() + ($2 || ' minutes')::interval
                     ELSE locked_until
                 END
             WHERE id = $3",
        )
        .bind(max_attempts)
        .bind(lock_minutes.to_string())
        .bind(shop_id)
        .execute(pool)
        .await?;
        Ok(())
    }

    pub async fn clear_login_failures(
        pool: &sqlx::PgPool,
        shop_id: i64,
    ) -> Result<(), sqlx::Error> {
        sqlx::query(
            "UPDATE shops
             SET failed_login_attempts = 0, locked_until = NULL
             WHERE id = $1",
        )
        .bind(shop_id)
        .execute(pool)
        .await?;
        Ok(())
    }

    pub async fn create_login_session(
        pool: &sqlx::PgPool,
        payload: &LoginSessionPayload,
    ) -> Result<LoginSessionResult, sqlx::Error> {
        let refresh_token = generate_refresh_token();
        let refresh_hash = hash_refresh_token(&refresh_token);

        let row = sqlx::query(
            "WITH clear_lock AS (
               UPDATE shops
               SET failed_login_attempts = 0, locked_until = NULL
               WHERE id = $1
                 AND (failed_login_attempts <> 0 OR locked_until IS NOT NULL)
               RETURNING id
             ),
             existing_device AS (
               SELECT id
               FROM device_sessions
               WHERE shop_id = $1
                 AND deleted_at IS NULL
                 AND device_name IS NOT DISTINCT FROM $2
                 AND device_platform IS NOT DISTINCT FROM $3
                 AND device_os IS NOT DISTINCT FROM $4
               ORDER BY last_seen_at DESC
               LIMIT 1
             ),
             updated_device AS (
               UPDATE device_sessions d
               SET ip_address = $5,
                   location = $6,
                   user_agent = $7,
                   last_seen_at = NOW()
               WHERE d.id IN (SELECT id FROM existing_device)
               RETURNING d.id
             ),
             inserted_device AS (
               INSERT INTO device_sessions (shop_id, device_name, device_platform, device_os, ip_address, location, user_agent)
               SELECT $1, $2, $3, $4, $5, $6, $7
               WHERE NOT EXISTS (SELECT 1 FROM updated_device)
               RETURNING id
             ),
             device_row AS (
               SELECT id FROM updated_device
               UNION ALL
               SELECT id FROM inserted_device
               LIMIT 1
             ),
             revoke_old AS (
               UPDATE refresh_tokens
               SET revoked_at = NOW()
               WHERE shop_id = $1
                 AND device_session_id = (SELECT id FROM device_row)
                 AND revoked_at IS NULL
               RETURNING id
             ),
             insert_refresh AS (
               INSERT INTO refresh_tokens (shop_id, device_session_id, token_hash, expires_at)
               VALUES ($1, (SELECT id FROM device_row), $8, NOW() + ($9 || ' days')::interval)
               RETURNING id
             ),
             shop_row AS (
               SELECT id, name, phone, email, address, logo_url,
                      total_revenue, total_orders, total_customers, timezone,
                      created_at::text AS created_at
               FROM shops
               WHERE id = $1
             )
             SELECT
               (SELECT id FROM device_row) AS device_id,
               (SELECT row_to_json(shop_row) FROM shop_row) AS shop_json",
        )
        .bind(payload.shop_id)
        .bind(&payload.device_name)
        .bind(&payload.device_platform)
        .bind(&payload.device_os)
        .bind(&payload.ip_address)
        .bind(&payload.location)
        .bind(&payload.user_agent)
        .bind(&refresh_hash)
        .bind(payload.refresh_token_days)
        .fetch_one(pool)
        .await?;

        let device_session_id = row.get::<Option<i64>, _>("device_id").ok_or_else(|| {
            sqlx::Error::Protocol("missing device session id from login query".into())
        })?;
        let shop_json = row.get::<serde_json::Value, _>("shop_json");
        let shop: ShopProfile = serde_json::from_value(shop_json).map_err(|e| {
            sqlx::Error::Protocol(format!("invalid shop json from login query: {}", e))
        })?;

        Ok(LoginSessionResult {
            device_session_id,
            shop,
            refresh_token,
        })
    }

    pub async fn login_one_step(
        pool: &sqlx::PgPool,
        payload: &LoginOneStepPayload,
    ) -> Result<LoginOneStepResult, sqlx::Error> {
        let refresh_token = generate_refresh_token();
        let refresh_hash = hash_refresh_token(&refresh_token);

        let row = sqlx::query(
            "WITH login_target AS (
               SELECT id, password_hash, failed_login_attempts, locked_until
               FROM shops
               WHERE phone = $1 OR email = $2
               LIMIT 1
             ),
             login_state AS (
               SELECT
                 id AS shop_id,
                 CASE
                   WHEN locked_until IS NOT NULL AND locked_until > NOW() THEN 'locked'
                   WHEN password_hash LIKE '$argon2%' THEN 'legacy'
                   WHEN (
                     password_hash LIKE '$2a$%' OR
                     password_hash LIKE '$2b$%' OR
                     password_hash LIKE '$2y$%'
                   ) AND crypt($3, password_hash) = password_hash THEN 'success'
                   ELSE 'invalid'
                 END AS status
               FROM login_target
             ),
             failed_login AS (
               UPDATE shops s
               SET failed_login_attempts = s.failed_login_attempts + 1,
                   locked_until = CASE
                     WHEN s.failed_login_attempts + 1 >= $12 THEN NOW() + ($13 || ' minutes')::interval
                     ELSE s.locked_until
                   END
               WHERE s.id = (SELECT shop_id FROM login_state WHERE status = 'invalid')
               RETURNING s.id
             ),
             clear_lock AS (
               UPDATE shops s
               SET failed_login_attempts = 0, locked_until = NULL
               WHERE s.id = (SELECT shop_id FROM login_state WHERE status = 'success')
                 AND (s.failed_login_attempts <> 0 OR s.locked_until IS NOT NULL)
               RETURNING s.id
             ),
             existing_device AS (
               SELECT d.id
               FROM device_sessions d
               JOIN login_state ls ON ls.shop_id = d.shop_id
               WHERE ls.status = 'success'
                 AND d.deleted_at IS NULL
                 AND d.device_name IS NOT DISTINCT FROM $4
                 AND d.device_platform IS NOT DISTINCT FROM $5
                 AND d.device_os IS NOT DISTINCT FROM $6
               ORDER BY d.last_seen_at DESC
               LIMIT 1
             ),
             updated_device AS (
               UPDATE device_sessions d
               SET ip_address = $7,
                   location = $8,
                   user_agent = $9,
                   last_seen_at = NOW()
               WHERE d.id IN (SELECT id FROM existing_device)
               RETURNING d.id
             ),
             inserted_device AS (
               INSERT INTO device_sessions (shop_id, device_name, device_platform, device_os, ip_address, location, user_agent)
               SELECT ls.shop_id, $4, $5, $6, $7, $8, $9
               FROM login_state ls
               WHERE ls.status = 'success'
                 AND NOT EXISTS (SELECT 1 FROM updated_device)
               RETURNING id
             ),
             device_row AS (
               SELECT id FROM updated_device
               UNION ALL
               SELECT id FROM inserted_device
               LIMIT 1
             ),
             revoke_old AS (
               UPDATE refresh_tokens
               SET revoked_at = NOW()
               WHERE shop_id = (SELECT shop_id FROM login_state WHERE status = 'success')
                 AND device_session_id = (SELECT id FROM device_row)
                 AND revoked_at IS NULL
               RETURNING id
             ),
             insert_refresh AS (
               INSERT INTO refresh_tokens (shop_id, device_session_id, token_hash, expires_at)
               SELECT ls.shop_id, (SELECT id FROM device_row), $10, NOW() + ($11 || ' days')::interval
               FROM login_state ls
               WHERE ls.status = 'success'
               RETURNING id
             ),
             shop_row AS (
               SELECT id, name, phone, email, address, logo_url,
                      total_revenue, total_orders, total_customers, timezone,
                      created_at::text AS created_at
               FROM shops
               WHERE id = (SELECT shop_id FROM login_state WHERE status = 'success')
             )
             SELECT
               COALESCE((SELECT status FROM login_state LIMIT 1), 'missing') AS login_status,
               (SELECT id FROM device_row LIMIT 1) AS device_id,
               (SELECT row_to_json(shop_row) FROM shop_row) AS shop_json",
        )
        .bind(&payload.phone_or_email)
        .bind(&payload.phone_or_email)
        .bind(&payload.password)
        .bind(&payload.device_name)
        .bind(&payload.device_platform)
        .bind(&payload.device_os)
        .bind(&payload.ip_address)
        .bind(&payload.location)
        .bind(&payload.user_agent)
        .bind(&refresh_hash)
        .bind(payload.refresh_token_days)
        .bind(payload.max_failed_attempts)
        .bind(payload.lock_minutes)
        .fetch_one(pool)
        .await?;

        let status = row.get::<String, _>("login_status");
        if status == "locked" {
            return Ok(LoginOneStepResult::Locked);
        }
        if status != "success" {
            return Ok(LoginOneStepResult::InvalidCredentials);
        }

        let device_session_id = row.get::<Option<i64>, _>("device_id").ok_or_else(|| {
            sqlx::Error::Protocol("missing device session id from login query".into())
        })?;
        let shop_json = row
            .get::<Option<serde_json::Value>, _>("shop_json")
            .ok_or_else(|| sqlx::Error::Protocol("missing shop payload from login query".into()))?;
        let shop: ShopProfile = serde_json::from_value(shop_json).map_err(|e| {
            sqlx::Error::Protocol(format!("invalid shop json from login query: {}", e))
        })?;

        Ok(LoginOneStepResult::Success(LoginSessionResult {
            device_session_id,
            shop,
            refresh_token,
        }))
    }

    pub async fn reset_code_count(
        pool: &sqlx::PgPool,
        payload: &ResetCodeCountPayload,
    ) -> Result<i64, sqlx::Error> {
        let row = sqlx::query(
            "SELECT COUNT(*) as cnt
             FROM password_reset_codes
             WHERE shop_id = $1 AND created_at >= NOW() - ($2 || ' minutes')::interval",
        )
        .bind(payload.shop_id)
        .bind(payload.window_minutes.to_string())
        .fetch_one(pool)
        .await?;

        Ok(row.get::<i64, _>("cnt"))
    }

    pub async fn create_reset_code(
        pool: &sqlx::PgPool,
        payload: &CreateResetCodePayload,
    ) -> Result<(), sqlx::Error> {
        sqlx::query(
            "INSERT INTO password_reset_codes (shop_id, code, expires_at)
             VALUES ($1, $2, NOW() + interval '10 minutes')",
        )
        .bind(payload.shop_id)
        .bind(&payload.code)
        .execute(pool)
        .await?;

        Ok(())
    }

    pub async fn create_refresh_token(
        pool: &sqlx::PgPool,
        shop_id: i64,
        device_session_id: Option<i64>,
        ttl_days: i64,
    ) -> Result<String, sqlx::Error> {
        let raw = generate_refresh_token();
        let hash = hash_refresh_token(&raw);
        let mut tx = pool.begin().await?;
        if let Some(device_id) = device_session_id {
            sqlx::query(
                "UPDATE refresh_tokens
                 SET revoked_at = NOW()
                 WHERE shop_id = $1
                   AND device_session_id = $2
                   AND revoked_at IS NULL",
            )
            .bind(shop_id)
            .bind(device_id)
            .execute(&mut *tx)
            .await?;
        }

        sqlx::query(
            "INSERT INTO refresh_tokens (shop_id, device_session_id, token_hash, expires_at)
             VALUES ($1, $2, $3, NOW() + ($4 || ' days')::interval)",
        )
        .bind(shop_id)
        .bind(device_session_id)
        .bind(hash)
        .bind(ttl_days.to_string())
        .execute(&mut *tx)
        .await?;

        tx.commit().await?;

        Ok(raw)
    }

    pub async fn rotate_refresh_token(
        pool: &sqlx::PgPool,
        raw_token: &str,
        ttl_days: i64,
    ) -> Result<Option<RefreshTokenRotation>, sqlx::Error> {
        let token_hash = hash_refresh_token(raw_token);
        let mut tx = pool.begin().await?;

        let row = sqlx::query(
            "SELECT id, shop_id, device_session_id
             FROM refresh_tokens
             WHERE token_hash = $1
               AND revoked_at IS NULL
               AND expires_at > NOW()",
        )
        .bind(&token_hash)
        .fetch_optional(&mut *tx)
        .await?;

        let row = match row {
            Some(r) => r,
            None => {
                tx.commit().await?;
                return Ok(None);
            }
        };

        let token_id: i64 = row.get("id");
        let shop_id: i64 = row.get("shop_id");
        let device_session_id: Option<i64> = row.get("device_session_id");

        sqlx::query("UPDATE refresh_tokens SET revoked_at = NOW() WHERE id = $1")
            .bind(token_id)
            .execute(&mut *tx)
            .await?;

        let new_raw = generate_refresh_token();
        let new_hash = hash_refresh_token(&new_raw);

        sqlx::query(
            "INSERT INTO refresh_tokens (shop_id, device_session_id, token_hash, expires_at)
             VALUES ($1, $2, $3, NOW() + ($4 || ' days')::interval)",
        )
        .bind(shop_id)
        .bind(device_session_id)
        .bind(new_hash)
        .bind(ttl_days.to_string())
        .execute(&mut *tx)
        .await?;

        tx.commit().await?;

        Ok(Some(RefreshTokenRotation {
            shop_id,
            refresh_token: new_raw,
            device_session_id,
        }))
    }

    pub async fn rotate_refresh_with_shop(
        pool: &sqlx::PgPool,
        raw_token: &str,
        ttl_days: i64,
    ) -> Result<Option<RefreshSessionResult>, sqlx::Error> {
        let old_hash = hash_refresh_token(raw_token);
        let new_refresh = generate_refresh_token();
        let new_hash = hash_refresh_token(&new_refresh);

        let row = sqlx::query(
            "WITH target AS (
               SELECT id, shop_id, device_session_id
               FROM refresh_tokens
               WHERE token_hash = $1
                 AND revoked_at IS NULL
                 AND expires_at > NOW()
               LIMIT 1
             ),
             revoked AS (
               UPDATE refresh_tokens
               SET revoked_at = NOW()
               WHERE id IN (SELECT id FROM target)
               RETURNING shop_id, device_session_id
             ),
             inserted AS (
               INSERT INTO refresh_tokens (shop_id, device_session_id, token_hash, expires_at)
               SELECT shop_id, device_session_id, $2, NOW() + ($3 || ' days')::interval
               FROM revoked
               RETURNING shop_id, device_session_id
             ),
             touched AS (
               UPDATE device_sessions
               SET last_seen_at = NOW()
               WHERE id IN (
                 SELECT device_session_id FROM inserted WHERE device_session_id IS NOT NULL
               )
               RETURNING id
             ),
             shop_row AS (
               SELECT id, name, phone, email, address, logo_url,
                      total_revenue, total_orders, total_customers, timezone,
                      created_at::text AS created_at
               FROM shops
               WHERE id = (SELECT shop_id FROM inserted LIMIT 1)
             )
             SELECT
               EXISTS(SELECT 1 FROM target) AS valid,
               (SELECT shop_id FROM inserted LIMIT 1) AS shop_id,
               (SELECT device_session_id FROM inserted LIMIT 1) AS device_id,
               (SELECT row_to_json(shop_row) FROM shop_row) AS shop_json",
        )
        .bind(old_hash)
        .bind(new_hash)
        .bind(ttl_days)
        .fetch_one(pool)
        .await?;

        let valid: bool = row.get("valid");
        if !valid {
            return Ok(None);
        }

        let shop_id = row.get::<Option<i64>, _>("shop_id").ok_or_else(|| {
            sqlx::Error::Protocol("missing shop id in refresh token query".into())
        })?;
        let device_session_id: Option<i64> = row.get("device_id");
        let shop_json = row.get::<serde_json::Value, _>("shop_json");
        let shop: ShopProfile = serde_json::from_value(shop_json).map_err(|e| {
            sqlx::Error::Protocol(format!("invalid shop json in refresh token query: {}", e))
        })?;

        Ok(Some(RefreshSessionResult {
            shop_id,
            device_session_id,
            shop,
            refresh_token: new_refresh,
        }))
    }

    pub async fn create_forgot_password_request(
        pool: &sqlx::PgPool,
        phone_or_email: &str,
        code: &str,
        window_minutes: i64,
        max_requests: i64,
    ) -> Result<ForgotPasswordResult, sqlx::Error> {
        let row = sqlx::query(
            "WITH shop_row AS (
               SELECT id, email
               FROM shops
               WHERE phone = $1 OR email = $2
               LIMIT 1
             ),
             request_count AS (
               SELECT
                 CASE
                   WHEN EXISTS(SELECT 1 FROM shop_row) THEN (
                     SELECT COUNT(*)::int
                     FROM password_reset_codes
                      WHERE shop_id = (SELECT id FROM shop_row)
                        AND created_at >= NOW() - ($4 * interval '1 minute')
                   )
                   ELSE 0
                 END AS cnt
             ),
             inserted_code AS (
               INSERT INTO password_reset_codes (shop_id, code, expires_at)
               SELECT (SELECT id FROM shop_row), $3, NOW() + interval '10 minutes'
               WHERE EXISTS(SELECT 1 FROM shop_row)
                 AND (SELECT cnt FROM request_count) < $5
               RETURNING shop_id
             )
             SELECT
               EXISTS(SELECT 1 FROM shop_row) AS has_shop,
               (SELECT email FROM shop_row) AS shop_email,
               (SELECT cnt FROM request_count) AS request_count",
        )
        .bind(phone_or_email)
        .bind(phone_or_email)
        .bind(code)
        .bind(window_minutes)
        .bind(max_requests)
        .fetch_one(pool)
        .await?;

        Ok(ForgotPasswordResult {
            has_shop: row.get("has_shop"),
            request_count: row.get("request_count"),
            shop_email: row.try_get("shop_email").unwrap_or(None),
        })
    }

    pub async fn verify_reset_code(
        pool: &sqlx::PgPool,
        phone_or_email: &str,
        code: &str,
        max_incorrect_attempts: i64,
    ) -> Result<VerifyResetCodeResult, sqlx::Error> {
        let row = sqlx::query(
            "WITH shop_row AS (
               SELECT id
               FROM shops
               WHERE phone = $1 OR email = $2
               LIMIT 1
             ),
             latest_code AS (
               SELECT id, code, failed_attempts
               FROM password_reset_codes
               WHERE shop_id = (SELECT id FROM shop_row)
                 AND expires_at > NOW()
               ORDER BY created_at DESC
               LIMIT 1
             ),
             valid_code AS (
               SELECT id
               FROM latest_code
               WHERE code = $3
                 AND failed_attempts < $4
             ),
             bumped AS (
               UPDATE password_reset_codes prc
               SET failed_attempts = prc.failed_attempts + 1
               WHERE prc.id = (
                 SELECT id
                 FROM latest_code
                 WHERE code <> $3
                   AND failed_attempts < $4
               )
               RETURNING prc.failed_attempts
             )
             SELECT
               EXISTS(SELECT 1 FROM shop_row) AS has_shop,
               EXISTS(SELECT 1 FROM valid_code) AS is_valid,
               EXISTS(SELECT 1 FROM latest_code) AS has_active_code,
               COALESCE(
                 (SELECT failed_attempts FROM bumped LIMIT 1),
                 (SELECT failed_attempts FROM latest_code LIMIT 1),
                 0
               ) AS failed_after_attempt",
        )
        .bind(phone_or_email)
        .bind(phone_or_email)
        .bind(code)
        .bind(max_incorrect_attempts)
        .fetch_one(pool)
        .await?;

        let max_attempts_i32 = i32::try_from(max_incorrect_attempts).unwrap_or(i32::MAX);
        let has_shop: bool = row.get("has_shop");
        let is_valid: bool = row.get("is_valid");
        let has_active_code: bool = row.get("has_active_code");
        let failed_after_attempt: i32 = row.get("failed_after_attempt");

        Ok(VerifyResetCodeResult {
            has_shop,
            is_valid,
            too_many_attempts: has_shop
                && has_active_code
                && !is_valid
                && failed_after_attempt >= max_attempts_i32,
        })
    }

    pub async fn reset_password_with_code(
        pool: &sqlx::PgPool,
        phone_or_email: &str,
        code: &str,
        new_password: &str,
        max_incorrect_attempts: i64,
    ) -> Result<ResetPasswordResult, sqlx::Error> {
        let row = sqlx::query(
            "WITH shop_row AS (
               SELECT id
               FROM shops
               WHERE phone = $1 OR email = $2
               LIMIT 1
             ),
             latest_code AS (
               SELECT id, shop_id, code, failed_attempts
               FROM password_reset_codes
               WHERE shop_id = (SELECT id FROM shop_row)
                 AND expires_at > NOW()
               ORDER BY created_at DESC
               LIMIT 1
             ),
             valid_code AS (
               SELECT id, shop_id
               FROM latest_code
               WHERE code = $3
                 AND failed_attempts < $5
             ),
             bumped AS (
               UPDATE password_reset_codes prc
               SET failed_attempts = prc.failed_attempts + 1
               WHERE prc.id = (
                 SELECT id
                 FROM latest_code
                 WHERE code <> $3
                   AND failed_attempts < $5
               )
               RETURNING prc.failed_attempts
             ),
             updated_shop AS (
               UPDATE shops
               SET password_hash = crypt($4, gen_salt('bf', 12)),
                   failed_login_attempts = 0,
                   locked_until = NULL
               WHERE id = (SELECT shop_id FROM valid_code)
               RETURNING id
             ),
             delete_codes AS (
               DELETE FROM password_reset_codes
               WHERE shop_id = (SELECT id FROM updated_shop)
               RETURNING id
             ),
             revoke_tokens AS (
               UPDATE refresh_tokens
               SET revoked_at = NOW()
               WHERE shop_id = (SELECT id FROM updated_shop)
                 AND revoked_at IS NULL
               RETURNING id
             ),
             close_sessions AS (
               UPDATE device_sessions
               SET deleted_at = NOW()
               WHERE shop_id = (SELECT id FROM updated_shop)
                 AND deleted_at IS NULL
               RETURNING id
             )
             SELECT
               EXISTS(SELECT 1 FROM updated_shop) AS updated,
               EXISTS(SELECT 1 FROM latest_code) AS has_active_code,
               COALESCE(
                 (SELECT failed_attempts FROM bumped LIMIT 1),
                 (SELECT failed_attempts FROM latest_code LIMIT 1),
                 0
               ) AS failed_after_attempt",
        )
        .bind(phone_or_email)
        .bind(phone_or_email)
        .bind(code)
        .bind(new_password)
        .bind(max_incorrect_attempts)
        .fetch_one(pool)
        .await?;

        let updated: bool = row.get("updated");
        if updated {
            return Ok(ResetPasswordResult::Success);
        }

        let has_active_code: bool = row.get("has_active_code");
        let failed_after_attempt: i32 = row.get("failed_after_attempt");
        let max_attempts_i32 = i32::try_from(max_incorrect_attempts).unwrap_or(i32::MAX);
        if has_active_code && failed_after_attempt >= max_attempts_i32 {
            return Ok(ResetPasswordResult::TooManyAttempts);
        }

        Ok(ResetPasswordResult::InvalidCode)
    }
}

impl ShopProfile {
    pub async fn create(
        pool: &sqlx::PgPool,
        payload: &CreateShopPayload,
    ) -> Result<ShopProfile, sqlx::Error> {
        let row = sqlx::query(
            "INSERT INTO shops (name, phone, email, password_hash, address, logo_url, timezone)
             VALUES ($1, $2, $3, crypt($4, gen_salt('bf', 12)), $5, $6, $7)
             RETURNING id, created_at::text as created_at",
        )
        .bind(&payload.input.shop_name)
        .bind(&payload.input.phone)
        .bind(&payload.input.email)
        .bind(&payload.password)
        .bind(&payload.input.address)
        .bind(&payload.input.logo_url)
        .bind(&payload.input.timezone)
        .fetch_one(pool)
        .await?;

        let shop_id = row.get::<i64, _>("id");
        let created_at = row.get::<String, _>("created_at");

        Ok(ShopProfile {
            id: shop_id,
            name: payload.input.shop_name.clone(),
            phone: payload.input.phone.clone(),
            email: payload.input.email.clone(),
            address: payload.input.address.clone(),
            logo_url: payload.input.logo_url.clone(),
            total_revenue: 0.0,
            total_orders: 0,
            total_customers: 0,
            timezone: payload.input.timezone.clone(),
            created_at,
        })
    }

    pub async fn create_with_welcome_email(
        pool: &sqlx::PgPool,
        input: &AuthRegisterInput,
        password: &str,
        dashboard_url: &str,
    ) -> Result<ShopProfile, sqlx::Error> {
        let row = sqlx::query(
            "WITH inserted_shop AS (
               INSERT INTO shops (name, phone, email, password_hash, address, logo_url, timezone)
               VALUES ($1, $2, $3, crypt($4, gen_salt('bf', 12)), $5, $6, $7)
               RETURNING id, name, phone, email, address, logo_url,
                         total_revenue, total_orders, total_customers, timezone,
                         created_at::text AS created_at
             ),
             inserted_email AS (
               INSERT INTO email_outbox (to_email, template, payload)
               SELECT email, 'welcome', json_build_object('shop_name', name, 'dashboard_url', $8)
               FROM inserted_shop
               RETURNING id
             )
             SELECT (SELECT row_to_json(inserted_shop) FROM inserted_shop) AS shop_json",
        )
        .bind(&input.shop_name)
        .bind(&input.phone)
        .bind(&input.email)
        .bind(password)
        .bind(&input.address)
        .bind(&input.logo_url)
        .bind(&input.timezone)
        .bind(dashboard_url)
        .fetch_one(pool)
        .await?;

        let shop_json = row.get::<serde_json::Value, _>("shop_json");
        let shop = serde_json::from_value::<ShopProfile>(shop_json).map_err(|e| {
            sqlx::Error::Protocol(format!("invalid shop json from register query: {}", e))
        })?;
        Ok(shop)
    }
}

pub fn build_token(
    shop_id: i64,
    device_session_id: Option<i64>,
    jwt_secret: &str,
) -> Result<String, ()> {
    let exp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|_| ())?
        .as_secs()
        + 60 * 60 * 24 * 7;

    let claims = Claims {
        sub: shop_id.to_string(),
        exp: exp as usize,
        sid: device_session_id,
    };
    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(jwt_secret.as_bytes()),
    )
    .map_err(|_| ())
}

fn generate_refresh_token() -> String {
    let mut bytes = [0u8; 32];
    OsRng.fill_bytes(&mut bytes);
    hex::encode(bytes)
}

fn hash_refresh_token(raw: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(raw.as_bytes());
    hex::encode(hasher.finalize())
}
