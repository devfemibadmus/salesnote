use serde::{Deserialize, Serialize};
use sqlx::{PgPool, Postgres, Row, Transaction};

use crate::api::sql::common::AUTH_CTE;
use crate::models::DeviceSession;
use crate::models::IdPayload;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ShopProfile {
    pub id: i64,
    pub name: String,
    pub phone: String,
    pub email: String,
    pub address: Option<String>,
    pub logo_url: Option<String>,
    pub total_revenue: f64,
    pub total_orders: i64,
    pub total_customers: i64,
    pub timezone: String,
    pub created_at: String,
    #[serde(default)]
    pub bank_accounts: Vec<ShopBankAccount>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ShopBankAccount {
    pub id: i16,
    pub bank_name: String,
    pub account_number: String,
    pub account_name: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ShopBankAccountInput {
    pub id: i16,
    pub bank_name: String,
    pub account_number: String,
    pub account_name: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct ShopUpdateInput {
    pub name: Option<String>,
    pub phone: Option<String>,
    pub email: Option<String>,
    pub address: Option<String>,
    pub logo_url: Option<String>,
    pub timezone: Option<String>,
    pub password: Option<String>,
    pub bank_accounts: Option<Vec<ShopBankAccountInput>>,
}

#[derive(Debug, Clone)]
pub struct ShopUpdatePayload {
    pub shop_id: i64,
    pub input: ShopUpdateInput,
    pub password: Option<String>,
}

#[derive(Debug, Clone)]
pub struct AuthorizedShopPayload {
    pub shop_id: i64,
    pub device_id: i64,
}

#[derive(Debug, Clone)]
pub struct AuthorizedShopUpdatePayload {
    pub shop_id: i64,
    pub device_id: i64,
    pub input: ShopUpdateInput,
    pub password: Option<String>,
}

#[derive(Debug, Clone)]
pub struct AuthorizedSettingsPayload {
    pub shop_id: i64,
    pub device_id: i64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct SettingsSummary {
    pub shop: ShopProfile,
    pub devices: Vec<DeviceSession>,
    pub current_device_push_enabled: bool,
}

impl ShopProfile {
    pub async fn get(
        pool: &PgPool,
        payload: &IdPayload,
    ) -> Result<Option<ShopProfile>, sqlx::Error> {
        let row = sqlx::query(
            "SELECT
                s.id, s.name, s.phone, s.email, s.address, s.logo_url,
                s.total_revenue, s.total_orders, s.total_customers, s.timezone,
                s.created_at::text as created_at,
                COALESCE((
                  SELECT json_agg(
                    json_build_object(
                      'id', sba.id,
                      'bank_name', sba.bank_name,
                      'account_number', sba.account_number,
                      'account_name', sba.account_name
                    )
                    ORDER BY sba.id ASC
                  )
                  FROM shop_bank_accounts sba
                  WHERE sba.shop_id = s.id
                ), '[]'::json) AS bank_accounts
             FROM shops s
             WHERE s.id = $1",
        )
        .bind(&payload.id)
        .fetch_optional(pool)
        .await?;

        row.map(shop_profile_from_row).transpose()
    }

    pub async fn update(pool: &PgPool, payload: &ShopUpdatePayload) -> Result<(), sqlx::Error> {
        sqlx::query(
            "UPDATE shops SET
                name = COALESCE($1, name),
                phone = COALESCE($2, phone),
                email = COALESCE($3, email),
                address = COALESCE($4, address),
                logo_url = COALESCE($5, logo_url),
                timezone = COALESCE($6, timezone),
                password_hash = CASE
                  WHEN $7 IS NULL THEN password_hash
                  ELSE crypt($7, gen_salt('bf', 12))
                END
             WHERE id = $8",
        )
        .bind(&payload.input.name)
        .bind(&payload.input.phone)
        .bind(&payload.input.email)
        .bind(&payload.input.address)
        .bind(&payload.input.logo_url)
        .bind(&payload.input.timezone)
        .bind(&payload.password)
        .bind(payload.shop_id)
        .execute(pool)
        .await?;

        Ok(())
    }

    pub async fn get_authorized(
        pool: &PgPool,
        payload: &AuthorizedShopPayload,
    ) -> Result<Option<ShopProfile>, sqlx::Error> {
        let sql = format!(
            r#"
            WITH {}
            SELECT
              s.id, s.name, s.phone, s.email, s.address, s.logo_url,
              s.total_revenue, s.total_orders, s.total_customers, s.timezone,
              s.created_at::text AS created_at,
              COALESCE((
                SELECT json_agg(
                  json_build_object(
                    'id', sba.id,
                    'bank_name', sba.bank_name,
                    'account_number', sba.account_number,
                    'account_name', sba.account_name
                  )
                  ORDER BY sba.id ASC
                )
                FROM shop_bank_accounts sba
                WHERE sba.shop_id = s.id
              ), '[]'::json) AS bank_accounts
            FROM shops s
            WHERE s.id = $1
              AND EXISTS (SELECT 1 FROM auth_active)
            "#,
            AUTH_CTE
        );

        let row = sqlx::query(&sql)
            .bind(payload.shop_id)
            .bind(payload.device_id)
            .fetch_optional(pool)
            .await?;

        row.map(shop_profile_from_row).transpose()
    }

    pub async fn settings_summary_authorized(
        pool: &PgPool,
        payload: &AuthorizedSettingsPayload,
    ) -> Result<Option<SettingsSummary>, sqlx::Error> {
        let sql = format!(
            r#"
            WITH {},
            shop_row AS (
              SELECT
                s.id, s.name, s.phone, s.email, s.address, s.logo_url,
                s.total_revenue, s.total_orders, s.total_customers, s.timezone,
                s.created_at::text AS created_at,
                COALESCE((
                  SELECT json_agg(
                    json_build_object(
                      'id', sba.id,
                      'bank_name', sba.bank_name,
                      'account_number', sba.account_number,
                      'account_name', sba.account_name
                    )
                    ORDER BY sba.id ASC
                  )
                  FROM shop_bank_accounts sba
                  WHERE sba.shop_id = s.id
                ), '[]'::json) AS bank_accounts
              FROM shops s
              WHERE s.id = $1
                AND EXISTS (SELECT 1 FROM auth_active)
            ),
            device_rows AS (
              SELECT
                ds.id, ds.shop_id, ds.device_name, ds.device_platform, ds.device_os,
                ds.ip_address, ds.location, ds.user_agent,
                TO_CHAR(ds.created_at AT TIME ZONE s.timezone, 'YYYY-MM-DD HH24:MI:SS') AS created_at,
                TO_CHAR(ds.last_seen_at AT TIME ZONE s.timezone, 'YYYY-MM-DD HH24:MI:SS') AS last_seen_at,
                ds.deleted_at::text AS deleted_at
              FROM device_sessions ds
              JOIN shops s ON s.id = ds.shop_id
              WHERE ds.shop_id = $1
                AND ds.deleted_at IS NULL
                AND EXISTS (SELECT 1 FROM auth_active)
              ORDER BY ds.last_seen_at DESC
            )
            SELECT
              EXISTS(SELECT 1 FROM auth_active) AS is_active,
              (
                SELECT EXISTS(
                  SELECT 1
                  FROM device_sessions d
                  WHERE d.id = $2
                    AND d.shop_id = $1
                    AND d.deleted_at IS NULL
                    AND d.fcm_token IS NOT NULL
                    AND d.fcm_token <> ''
                )
              ) AS current_device_push_enabled,
              (SELECT row_to_json(shop_row) FROM shop_row) AS shop_json,
              (
                SELECT COALESCE(json_agg(
                  json_build_object(
                    'id', d.id,
                    'shop_id', d.shop_id,
                    'device_name', d.device_name,
                    'device_platform', d.device_platform,
                    'device_os', d.device_os,
                    'ip_address', d.ip_address,
                    'location', d.location,
                    'user_agent', d.user_agent,
                    'created_at', d.created_at,
                    'last_seen_at', d.last_seen_at,
                    'deleted_at', d.deleted_at
                  ) ORDER BY d.last_seen_at DESC
                ), '[]'::json)
                FROM device_rows d
              ) AS devices_json
            "#,
            AUTH_CTE
        );

        let row = sqlx::query(&sql)
            .bind(payload.shop_id)
            .bind(payload.device_id)
            .fetch_one(pool)
            .await?;

        let is_active: bool = row.get("is_active");
        if !is_active {
            return Ok(None);
        }

        let shop_value = row.get::<serde_json::Value, _>("shop_json");
        let devices_value = row.get::<serde_json::Value, _>("devices_json");
        let shop: ShopProfile = serde_json::from_value(shop_value)
            .map_err(|e| sqlx::Error::Protocol(format!("invalid shop json: {}", e).into()))?;
        let devices: Vec<DeviceSession> = serde_json::from_value(devices_value)
            .map_err(|e| sqlx::Error::Protocol(format!("invalid devices json: {}", e).into()))?;
        let current_device_push_enabled = row.get::<bool, _>("current_device_push_enabled");

        Ok(Some(SettingsSummary {
            shop,
            devices,
            current_device_push_enabled,
        }))
    }

    pub async fn update_authorized(
        pool: &PgPool,
        payload: &AuthorizedShopUpdatePayload,
    ) -> Result<Option<ShopProfile>, sqlx::Error> {
        let mut tx: Transaction<'_, Postgres> = pool.begin().await?;
        let sql = format!(
            r#"
            WITH {}
            UPDATE shops s
            SET
              name = COALESCE($3, s.name),
              phone = COALESCE($4, s.phone),
              email = COALESCE($5, s.email),
              address = COALESCE($6, s.address),
              logo_url = COALESCE($7, s.logo_url),
              timezone = COALESCE($8, s.timezone),
              password_hash = CASE
                WHEN $9 IS NULL THEN s.password_hash
                ELSE crypt($9, gen_salt('bf', 12))
              END
            WHERE s.id = $1
              AND EXISTS (SELECT 1 FROM auth_active)
            RETURNING s.id
            "#,
            AUTH_CTE
        );

        let row = sqlx::query(&sql)
            .bind(payload.shop_id)
            .bind(payload.device_id)
            .bind(payload.input.name.as_deref())
            .bind(payload.input.phone.as_deref())
            .bind(payload.input.email.as_deref())
            .bind(payload.input.address.as_deref())
            .bind(payload.input.logo_url.as_deref())
            .bind(payload.input.timezone.as_deref())
            .bind(payload.password.as_deref())
            .fetch_optional(&mut *tx)
            .await?;

        let Some(_) = row else {
            tx.rollback().await?;
            return Ok(None);
        };

        if let Some(bank_accounts) = payload.input.bank_accounts.as_ref() {
            replace_bank_accounts(&mut tx, payload.shop_id, bank_accounts).await?;
        }

        let profile = load_shop_profile_tx(&mut tx, payload.shop_id).await?;
        tx.commit().await?;
        Ok(profile)
    }
}

fn shop_profile_from_row(row: sqlx::postgres::PgRow) -> Result<ShopProfile, sqlx::Error> {
    let bank_accounts = row.get::<serde_json::Value, _>("bank_accounts");
    let bank_accounts: Vec<ShopBankAccount> = serde_json::from_value(bank_accounts)
        .map_err(|e| sqlx::Error::Protocol(format!("invalid bank accounts json: {}", e).into()))?;

    Ok(ShopProfile {
        id: row.get("id"),
        name: row.get("name"),
        phone: row.get("phone"),
        email: row.get("email"),
        address: row.get("address"),
        logo_url: row.get("logo_url"),
        total_revenue: row.get("total_revenue"),
        total_orders: row.get("total_orders"),
        total_customers: row.get("total_customers"),
        timezone: row.get("timezone"),
        created_at: row.get("created_at"),
        bank_accounts,
    })
}

async fn replace_bank_accounts(
    tx: &mut Transaction<'_, Postgres>,
    shop_id: i64,
    bank_accounts: &[ShopBankAccountInput],
) -> Result<(), sqlx::Error> {
    let ids: Vec<i16> = bank_accounts.iter().map(|entry| entry.id).collect();
    sqlx::query("DELETE FROM shop_bank_accounts WHERE shop_id = $1 AND NOT (id = ANY($2))")
        .bind(shop_id)
        .bind(&ids)
        .execute(&mut **tx)
        .await?;

    for bank_account in bank_accounts {
        sqlx::query(
            "INSERT INTO shop_bank_accounts (
                shop_id, id, bank_name, account_number, account_name, updated_at
             )
             VALUES ($1, $2, $3, $4, $5, NOW())
             ON CONFLICT (shop_id, id)
             DO UPDATE SET
               bank_name = EXCLUDED.bank_name,
               account_number = EXCLUDED.account_number,
               account_name = EXCLUDED.account_name,
                updated_at = NOW()",
        )
        .bind(shop_id)
        .bind(bank_account.id)
        .bind(&bank_account.bank_name)
        .bind(&bank_account.account_number)
        .bind(&bank_account.account_name)
        .execute(&mut **tx)
        .await?;
    }

    Ok(())
}

async fn load_shop_profile_tx(
    tx: &mut Transaction<'_, Postgres>,
    shop_id: i64,
) -> Result<Option<ShopProfile>, sqlx::Error> {
    let row = sqlx::query(
        "SELECT
            s.id, s.name, s.phone, s.email, s.address, s.logo_url,
            s.total_revenue, s.total_orders, s.total_customers, s.timezone,
            s.created_at::text AS created_at,
            COALESCE((
              SELECT json_agg(
                json_build_object(
                  'id', sba.id,
                  'bank_name', sba.bank_name,
                  'account_number', sba.account_number,
                  'account_name', sba.account_name
                )
                ORDER BY sba.id ASC
              )
              FROM shop_bank_accounts sba
              WHERE sba.shop_id = s.id
            ), '[]'::json) AS bank_accounts
         FROM shops s
         WHERE s.id = $1",
    )
    .bind(shop_id)
    .fetch_optional(&mut **tx)
    .await?;

    row.map(shop_profile_from_row).transpose()
}

