use serde::{Deserialize, Serialize};
use sqlx::{PgPool, Row};

use crate::api::sql::common::AUTH_CTE;
use crate::models::IdPayload;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Signature {
    pub id: i64,
    pub shop_id: i64,
    pub name: String,
    pub image_url: String,
    pub created_at: String,
}

#[derive(Debug, Clone)]
pub struct SignatureCreatePayload {
    pub shop_id: i64,
    pub name: String,
    pub image_url: String,
}

#[derive(Debug, Clone)]
pub struct AuthorizedSignatureCreatePayload {
    pub shop_id: i64,
    pub device_id: i64,
    pub name: String,
    pub image_url: String,
}

#[derive(Debug, Clone)]
pub struct AuthorizedSignatureListPayload {
    pub shop_id: i64,
    pub device_id: i64,
}

#[derive(Debug, Clone)]
pub struct AuthorizedSignatureDeletePayload {
    pub shop_id: i64,
    pub device_id: i64,
    pub signature_id: i64,
}

#[derive(Debug)]
pub enum AuthorizedSignatureCreateResult {
    Unauthorized,
    LimitReached,
    Created(Signature),
}

#[derive(Debug)]
pub enum AuthorizedSignatureDeleteResult {
    Unauthorized,
    NotFound,
    InUse,
    Deleted,
}

impl Signature {
    pub async fn create_authorized(
        pool: &PgPool,
        payload: &AuthorizedSignatureCreatePayload,
    ) -> Result<AuthorizedSignatureCreateResult, sqlx::Error> {
        let sql = format!(
            r#"
            WITH {},
            can_insert AS (
              SELECT
                (SELECT COUNT(*)::bigint FROM signatures WHERE shop_id = $1) AS sig_count
              WHERE EXISTS (SELECT 1 FROM auth_active)
            ),
            inserted AS (
              INSERT INTO signatures (shop_id, name, image_url)
              SELECT $1, $3, $4
              FROM can_insert
              WHERE sig_count < 3
              RETURNING id, shop_id, name, image_url, created_at::text AS created_at
            )
            SELECT
              EXISTS(SELECT 1 FROM auth_active) AS auth_ok,
              EXISTS(SELECT 1 FROM can_insert WHERE sig_count >= 3) AS limit_hit,
              (SELECT row_to_json(inserted) FROM inserted) AS signature_json
            "#,
            AUTH_CTE
        );

        let row = sqlx::query(&sql)
            .bind(payload.shop_id)
            .bind(payload.device_id)
            .bind(&payload.name)
            .bind(&payload.image_url)
            .fetch_one(pool)
            .await?;

        let auth_ok: bool = row.get("auth_ok");
        if !auth_ok {
            return Ok(AuthorizedSignatureCreateResult::Unauthorized);
        }

        let signature_json: Option<serde_json::Value> = row.try_get("signature_json").ok();
        if let Some(signature_json) = signature_json {
            let signature: Signature = serde_json::from_value(signature_json).map_err(|e| {
                sqlx::Error::Protocol(format!("invalid signature json: {}", e).into())
            })?;
            return Ok(AuthorizedSignatureCreateResult::Created(signature));
        }

        let limit_hit: bool = row.get("limit_hit");
        if limit_hit {
            return Ok(AuthorizedSignatureCreateResult::LimitReached);
        }

        Ok(AuthorizedSignatureCreateResult::LimitReached)
    }

    pub async fn list_authorized(
        pool: &PgPool,
        payload: &AuthorizedSignatureListPayload,
    ) -> Result<Option<Vec<Signature>>, sqlx::Error> {
        let sql = format!(
            r#"
            WITH {}
            SELECT
              EXISTS(SELECT 1 FROM auth_active) AS auth_ok,
              COALESCE(json_agg(
                json_build_object(
                  'id', s.id,
                  'shop_id', s.shop_id,
                  'name', s.name,
                  'image_url', s.image_url,
                  'created_at', s.created_at::text
                )
                ORDER BY s.created_at DESC
              ) FILTER (WHERE s.id IS NOT NULL), '[]'::json) AS signatures_json
            FROM signatures s
            WHERE s.shop_id = $1
              AND EXISTS (SELECT 1 FROM auth_active)
            "#,
            AUTH_CTE
        );

        let row = sqlx::query(&sql)
            .bind(payload.shop_id)
            .bind(payload.device_id)
            .fetch_one(pool)
            .await?;
        let auth_ok: bool = row.get("auth_ok");
        if !auth_ok {
            return Ok(None);
        }

        let signatures_json: serde_json::Value = row.get("signatures_json");
        let items: Vec<Signature> = serde_json::from_value(signatures_json)
            .map_err(|e| sqlx::Error::Protocol(format!("invalid signatures json: {}", e).into()))?;
        Ok(Some(items))
    }

    pub async fn delete_authorized(
        pool: &PgPool,
        payload: &AuthorizedSignatureDeletePayload,
    ) -> Result<AuthorizedSignatureDeleteResult, sqlx::Error> {
        let sql = format!(
            r#"
            WITH {},
            target AS (
              SELECT s.id
              FROM signatures s
              WHERE s.id = $3
                AND s.shop_id = $1
                AND EXISTS (SELECT 1 FROM auth_active)
            ),
            usage AS (
              SELECT EXISTS(
                SELECT 1
                FROM sales sa
                WHERE sa.shop_id = $1
                  AND sa.signature_id = $3
              ) AS in_use
            ),
            deleted AS (
              DELETE FROM signatures s
              WHERE s.id IN (SELECT id FROM target)
                AND NOT (SELECT in_use FROM usage)
              RETURNING s.id
            )
            SELECT
              EXISTS(SELECT 1 FROM auth_active) AS auth_ok,
              EXISTS(SELECT 1 FROM target) AS target_exists,
              (SELECT in_use FROM usage) AS in_use,
              EXISTS(SELECT 1 FROM deleted) AS deleted
            "#,
            AUTH_CTE
        );

        let row = sqlx::query(&sql)
            .bind(payload.shop_id)
            .bind(payload.device_id)
            .bind(payload.signature_id)
            .fetch_one(pool)
            .await?;

        let auth_ok: bool = row.get("auth_ok");
        if !auth_ok {
            return Ok(AuthorizedSignatureDeleteResult::Unauthorized);
        }
        let deleted: bool = row.get("deleted");
        if deleted {
            return Ok(AuthorizedSignatureDeleteResult::Deleted);
        }
        let target_exists: bool = row.get("target_exists");
        if !target_exists {
            return Ok(AuthorizedSignatureDeleteResult::NotFound);
        }
        let in_use: bool = row.get("in_use");
        if in_use {
            return Ok(AuthorizedSignatureDeleteResult::InUse);
        }
        Ok(AuthorizedSignatureDeleteResult::NotFound)
    }

    pub async fn count_for_shop(pool: &PgPool, payload: &IdPayload) -> Result<i64, sqlx::Error> {
        let row = sqlx::query("SELECT COUNT(*) as cnt FROM signatures WHERE shop_id = $1")
            .bind(&payload.id)
            .fetch_one(pool)
            .await?;
        Ok(row.get("cnt"))
    }

    pub async fn create(
        pool: &PgPool,
        payload: &SignatureCreatePayload,
    ) -> Result<Signature, sqlx::Error> {
        let row = sqlx::query(
            "INSERT INTO signatures (shop_id, name, image_url)
             VALUES ($1, $2, $3)
             RETURNING id, created_at::text as created_at",
        )
        .bind(payload.shop_id)
        .bind(&payload.name)
        .bind(&payload.image_url)
        .fetch_one(pool)
        .await?;

        let id = row.get::<i64, _>("id");
        let created_at = row.get::<String, _>("created_at");

        Ok(Signature {
            id,
            shop_id: payload.shop_id,
            name: payload.name.clone(),
            image_url: payload.image_url.clone(),
            created_at,
        })
    }

    pub async fn list(pool: &PgPool, payload: &IdPayload) -> Result<Vec<Signature>, sqlx::Error> {
        let rows = sqlx::query(
            "SELECT id, shop_id, name, image_url, created_at::text as created_at
             FROM signatures WHERE shop_id = $1 ORDER BY created_at DESC",
        )
        .bind(&payload.id)
        .fetch_all(pool)
        .await?;

        Ok(rows.into_iter().map(Signature::from_row).collect())
    }

    pub async fn get(pool: &PgPool, payload: &IdPayload) -> Result<Option<Signature>, sqlx::Error> {
        let row = sqlx::query(
            "SELECT id, shop_id, name, image_url, created_at::text as created_at FROM signatures WHERE id = $1",
        )
        .bind(payload.id)
        .fetch_optional(pool)
        .await?;

        Ok(row.map(Signature::from_row))
    }

    pub async fn delete(pool: &PgPool, payload: &IdPayload) -> Result<(), sqlx::Error> {
        sqlx::query("DELETE FROM signatures WHERE id = $1")
            .bind(payload.id)
            .execute(pool)
            .await?;
        Ok(())
    }

    fn from_row(row: sqlx::postgres::PgRow) -> Signature {
        Signature {
            id: row.get("id"),
            shop_id: row.get("shop_id"),
            name: row.get("name"),
            image_url: row.get("image_url"),
            created_at: row.get("created_at"),
        }
    }
}
