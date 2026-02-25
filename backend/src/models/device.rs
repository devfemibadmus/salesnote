use serde::{Deserialize, Serialize};
use sqlx::{PgPool, Row};

use crate::api::sql::common::AUTH_CTE;

#[derive(Debug, Serialize, Deserialize)]
pub struct DeviceSession {
    pub id: i64,
    pub shop_id: i64,
    pub device_name: Option<String>,
    pub device_platform: Option<String>,
    pub device_os: Option<String>,
    pub ip_address: Option<String>,
    pub location: Option<String>,
    pub user_agent: Option<String>,
    pub created_at: String,
    pub last_seen_at: String,
    pub deleted_at: Option<String>,
}

#[derive(Debug, Clone)]
pub struct DeviceCreatePayload {
    pub shop_id: i64,
    pub device_name: Option<String>,
    pub device_platform: Option<String>,
    pub device_os: Option<String>,
    pub ip_address: Option<String>,
    pub location: Option<String>,
    pub user_agent: Option<String>,
}

#[derive(Debug, Clone)]
pub struct DeviceFcmPayload {
    pub shop_id: i64,
    pub device_id: i64,
    pub fcm_token: String,
}

#[derive(Debug, Clone)]
pub struct DeviceListPayload {
    pub shop_id: i64,
}

#[derive(Debug, Clone)]
pub struct DeviceDeletePayload {
    pub shop_id: i64,
    pub device_id: i64,
}

#[derive(Debug, Clone)]
pub struct AuthorizedDeviceListPayload {
    pub shop_id: i64,
    pub current_device_id: i64,
}

#[derive(Debug, Clone)]
pub struct AuthorizedDeviceDeletePayload {
    pub shop_id: i64,
    pub current_device_id: i64,
    pub target_device_id: i64,
}

impl DeviceSession {
    pub async fn create(pool: &PgPool, payload: &DeviceCreatePayload) -> Result<i64, sqlx::Error> {
        let row = sqlx::query(
            "WITH existing AS (
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
             updated AS (
               UPDATE device_sessions d
               SET ip_address = $5,
                   location = $6,
                   user_agent = $7,
                   last_seen_at = NOW()
               WHERE d.id IN (SELECT id FROM existing)
               RETURNING d.id
             ),
             inserted AS (
               INSERT INTO device_sessions (
                 shop_id, device_name, device_platform, device_os, ip_address, location, user_agent
               )
               SELECT $1, $2, $3, $4, $5, $6, $7
               WHERE NOT EXISTS (SELECT 1 FROM updated)
               RETURNING id
             )
             SELECT id FROM updated
             UNION ALL
             SELECT id FROM inserted
             LIMIT 1",
        )
        .bind(payload.shop_id)
        .bind(&payload.device_name)
        .bind(&payload.device_platform)
        .bind(&payload.device_os)
        .bind(&payload.ip_address)
        .bind(&payload.location)
        .bind(&payload.user_agent)
        .fetch_one(pool)
        .await?;

        Ok(row.get::<i64, _>("id"))
    }

    pub async fn list(
        pool: &PgPool,
        payload: &DeviceListPayload,
    ) -> Result<Vec<DeviceSession>, sqlx::Error> {
        let rows = sqlx::query(
            "SELECT ds.id, ds.shop_id, ds.device_name, ds.device_platform, ds.device_os,
                    ds.ip_address, ds.location, ds.user_agent,
                    TO_CHAR(ds.created_at AT TIME ZONE s.timezone, 'YYYY-MM-DD HH24:MI:SS') as created_at,
                    TO_CHAR(ds.last_seen_at AT TIME ZONE s.timezone, 'YYYY-MM-DD HH24:MI:SS') as last_seen_at,
                    ds.deleted_at::text as deleted_at
             FROM device_sessions ds
             JOIN shops s ON s.id = ds.shop_id
             WHERE ds.shop_id = $1 AND ds.deleted_at IS NULL
             ORDER BY ds.last_seen_at DESC",
        )
        .bind(payload.shop_id)
        .fetch_all(pool)
        .await?;

        Ok(rows
            .into_iter()
            .map(|row| DeviceSession {
                id: row.get("id"),
                shop_id: row.get("shop_id"),
                device_name: row.get("device_name"),
                device_platform: row.get("device_platform"),
                device_os: row.get("device_os"),
                ip_address: row.get("ip_address"),
                location: row.get("location"),
                user_agent: row.get("user_agent"),
                created_at: row.get("created_at"),
                last_seen_at: row.get("last_seen_at"),
                deleted_at: row.get("deleted_at"),
            })
            .collect())
    }

    pub async fn list_authorized(
        pool: &PgPool,
        payload: &AuthorizedDeviceListPayload,
    ) -> Result<Vec<DeviceSession>, sqlx::Error> {
        let rows = sqlx::query(
            "WITH auth_active AS (
               SELECT id
               FROM device_sessions
               WHERE id = $2
                 AND shop_id = $1
                 AND deleted_at IS NULL
             )
             SELECT ds.id, ds.shop_id, ds.device_name, ds.device_platform, ds.device_os,
                    ds.ip_address, ds.location, ds.user_agent,
                    TO_CHAR(ds.created_at AT TIME ZONE s.timezone, 'YYYY-MM-DD HH24:MI:SS') as created_at,
                    TO_CHAR(ds.last_seen_at AT TIME ZONE s.timezone, 'YYYY-MM-DD HH24:MI:SS') as last_seen_at,
                    ds.deleted_at::text as deleted_at
             FROM device_sessions ds
             JOIN shops s ON s.id = ds.shop_id
             WHERE ds.shop_id = $1
               AND ds.deleted_at IS NULL
               AND EXISTS (SELECT 1 FROM auth_active)
             ORDER BY ds.last_seen_at DESC",
        )
        .bind(payload.shop_id)
        .bind(payload.current_device_id)
        .fetch_all(pool)
        .await?;

        Ok(rows
            .into_iter()
            .map(|row| DeviceSession {
                id: row.get("id"),
                shop_id: row.get("shop_id"),
                device_name: row.get("device_name"),
                device_platform: row.get("device_platform"),
                device_os: row.get("device_os"),
                ip_address: row.get("ip_address"),
                location: row.get("location"),
                user_agent: row.get("user_agent"),
                created_at: row.get("created_at"),
                last_seen_at: row.get("last_seen_at"),
                deleted_at: row.get("deleted_at"),
            })
            .collect())
    }

    pub async fn list_missing_location(
        pool: &PgPool,
        limit: i64,
    ) -> Result<Vec<DeviceSession>, sqlx::Error> {
        let rows = sqlx::query(
            "SELECT id, shop_id, device_name, device_platform, device_os,
                    ip_address, location, user_agent,
                    created_at::text as created_at,
                    last_seen_at::text as last_seen_at,
                    deleted_at::text as deleted_at
             FROM device_sessions
             WHERE deleted_at IS NULL
               AND ip_address IS NOT NULL
               AND ip_address <> ''
               AND (location IS NULL OR location = '')
             ORDER BY created_at ASC
             LIMIT $1",
        )
        .bind(limit)
        .fetch_all(pool)
        .await?;

        Ok(rows
            .into_iter()
            .map(|row| DeviceSession {
                id: row.get("id"),
                shop_id: row.get("shop_id"),
                device_name: row.get("device_name"),
                device_platform: row.get("device_platform"),
                device_os: row.get("device_os"),
                ip_address: row.get("ip_address"),
                location: row.get("location"),
                user_agent: row.get("user_agent"),
                created_at: row.get("created_at"),
                last_seen_at: row.get("last_seen_at"),
                deleted_at: row.get("deleted_at"),
            })
            .collect())
    }

    pub async fn update_location(
        pool: &PgPool,
        device_id: i64,
        location: &str,
    ) -> Result<(), sqlx::Error> {
        sqlx::query(
            "UPDATE device_sessions
             SET location = $1
             WHERE id = $2",
        )
        .bind(location)
        .bind(device_id)
        .execute(pool)
        .await?;
        Ok(())
    }

    pub async fn delete(pool: &PgPool, payload: &DeviceDeletePayload) -> Result<(), sqlx::Error> {
        sqlx::query(
            "WITH deleted AS (
               UPDATE device_sessions
               SET deleted_at = NOW()
               WHERE id = $1
                 AND shop_id = $2
               RETURNING id
             )
             UPDATE refresh_tokens
             SET revoked_at = NOW()
             WHERE revoked_at IS NULL
               AND device_session_id IN (SELECT id FROM deleted)",
        )
        .bind(payload.device_id)
        .bind(payload.shop_id)
        .execute(pool)
        .await?;
        Ok(())
    }

    pub async fn delete_authorized(
        pool: &PgPool,
        payload: &AuthorizedDeviceDeletePayload,
    ) -> Result<bool, sqlx::Error> {
        let result = sqlx::query(
            "WITH auth_active AS (
               SELECT id
               FROM device_sessions
               WHERE id = $2
                 AND shop_id = $1
                 AND deleted_at IS NULL
             ),
             deleted AS (
               UPDATE device_sessions
               SET deleted_at = NOW()
               WHERE id = $3
                 AND shop_id = $1
                 AND EXISTS (SELECT 1 FROM auth_active)
               RETURNING id
             ),
             revoked AS (
               UPDATE refresh_tokens
               SET revoked_at = NOW()
               WHERE device_session_id IN (SELECT id FROM deleted)
                 AND revoked_at IS NULL
               RETURNING device_session_id
             )
             SELECT id FROM deleted",
        )
        .bind(payload.shop_id)
        .bind(payload.current_device_id)
        .bind(payload.target_device_id)
        .fetch_optional(pool)
        .await?;

        Ok(result.is_some())
    }

    pub async fn touch(pool: &PgPool, device_id: i64) -> Result<(), sqlx::Error> {
        sqlx::query(
            "UPDATE device_sessions
             SET last_seen_at = NOW()
             WHERE id = $1",
        )
        .bind(device_id)
        .execute(pool)
        .await?;
        Ok(())
    }

    pub async fn touch_if_stale(
        pool: &PgPool,
        device_id: i64,
        stale_minutes: i64,
    ) -> Result<(), sqlx::Error> {
        sqlx::query(
            "UPDATE device_sessions
             SET last_seen_at = NOW()
             WHERE id = $1
               AND (last_seen_at IS NULL OR last_seen_at < NOW() - ($2::text || ' minutes')::interval)",
        )
        .bind(device_id)
        .bind(stale_minutes)
        .execute(pool)
        .await?;
        Ok(())
    }

    pub async fn is_active(
        pool: &PgPool,
        shop_id: i64,
        device_id: i64,
    ) -> Result<bool, sqlx::Error> {
        let row = sqlx::query(
            "SELECT COUNT(*) as cnt
             FROM device_sessions
             WHERE id = $1 AND shop_id = $2 AND deleted_at IS NULL",
        )
        .bind(device_id)
        .bind(shop_id)
        .fetch_one(pool)
        .await?;

        Ok(row.get::<i64, _>("cnt") > 0)
    }

    pub async fn validate_and_touch_if_stale(
        pool: &PgPool,
        shop_id: i64,
        device_id: i64,
        stale_minutes: i64,
    ) -> Result<bool, sqlx::Error> {
        let row = sqlx::query(
            "WITH active AS (
               SELECT id
               FROM device_sessions
               WHERE id = $1
                 AND shop_id = $2
                 AND deleted_at IS NULL
             ),
             touched AS (
               UPDATE device_sessions
               SET last_seen_at = NOW()
               WHERE id IN (SELECT id FROM active)
                 AND (last_seen_at IS NULL OR last_seen_at < NOW() - ($3::text || ' minutes')::interval)
               RETURNING id
             )
             SELECT EXISTS(SELECT 1 FROM active) AS is_active,
                    EXISTS(SELECT 1 FROM touched) AS was_touched",
        )
        .bind(device_id)
        .bind(shop_id)
        .bind(stale_minutes)
        .fetch_one(pool)
        .await?;

        Ok(row.get::<bool, _>("is_active"))
    }

    pub async fn set_fcm_token(
        pool: &PgPool,
        payload: &DeviceFcmPayload,
    ) -> Result<bool, sqlx::Error> {
        let result = sqlx::query(
            "UPDATE device_sessions
             SET fcm_token = $1,
                 last_seen_at = NOW()
             WHERE id = $2
               AND shop_id = $3
               AND deleted_at IS NULL",
        )
        .bind(&payload.fcm_token)
        .bind(payload.device_id)
        .bind(payload.shop_id)
        .execute(pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    pub async fn set_fcm_token_authorized(
        pool: &PgPool,
        shop_id: i64,
        current_device_id: i64,
        token: Option<&str>,
    ) -> Result<bool, sqlx::Error> {
        let sql = format!(
            r#"
            WITH {}
            UPDATE device_sessions d
            SET fcm_token = $3
            WHERE d.id = $2
              AND d.shop_id = $1
              AND d.deleted_at IS NULL
              AND EXISTS (SELECT 1 FROM auth_active)
            RETURNING d.id
            "#,
            AUTH_CTE
        );

        let row = sqlx::query(&sql)
            .bind(shop_id)
            .bind(current_device_id)
            .bind(token)
            .fetch_optional(pool)
            .await?;

        Ok(row.is_some())
    }
}
