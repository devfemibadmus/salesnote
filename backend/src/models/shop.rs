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
    pub currency_code: String,
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
                s.id, s.name, s.phone, s.currency_code, s.email, s.address, s.logo_url,
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
        let currency_code = payload
            .input
            .phone
            .as_deref()
            .map(currency_code_from_phone)
            .transpose()?;
        sqlx::query(
            "UPDATE shops SET
                name = COALESCE($1, name),
                phone = COALESCE($2, phone),
                currency_code = COALESCE($3, currency_code),
                email = COALESCE($4, email),
                address = COALESCE($5, address),
                logo_url = COALESCE($6, logo_url),
                timezone = COALESCE($7, timezone),
                password_hash = CASE
                  WHEN $8 IS NULL THEN password_hash
                  ELSE crypt($8, gen_salt('bf', 12))
                END
             WHERE id = $9",
        )
        .bind(&payload.input.name)
        .bind(&payload.input.phone)
        .bind(currency_code)
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
              s.currency_code,
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
                s.currency_code,
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
        let currency_code = payload
            .input
            .phone
            .as_deref()
            .map(currency_code_from_phone)
            .transpose()?;
        let sql = format!(
            r#"
            WITH {}
            UPDATE shops s
            SET
              name = COALESCE($3, s.name),
              phone = COALESCE($4, s.phone),
              currency_code = COALESCE($5, s.currency_code),
              email = COALESCE($6, s.email),
              address = COALESCE($7, s.address),
              logo_url = COALESCE($8, s.logo_url),
              timezone = COALESCE($9, s.timezone),
              password_hash = CASE
                WHEN $10 IS NULL THEN s.password_hash
                ELSE crypt($10, gen_salt('bf', 12))
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
            .bind(currency_code)
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

    pub async fn currency_code_by_id(pool: &PgPool, shop_id: i64) -> Result<String, sqlx::Error> {
        let row = sqlx::query("SELECT currency_code FROM shops WHERE id = $1")
            .bind(shop_id)
            .fetch_optional(pool)
            .await?;

        row.and_then(|row| row.try_get::<String, _>("currency_code").ok())
            .map(|value| value.trim().to_uppercase())
            .filter(|value| !value.is_empty())
            .ok_or_else(|| {
                sqlx::Error::Protocol(format!("missing currency_code for shop {}", shop_id).into())
            })
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
        currency_code: row.get("currency_code"),
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
            s.id, s.name, s.phone, s.currency_code, s.email, s.address, s.logo_url,
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

pub fn currency_code_from_phone(phone: &str) -> Result<&'static str, sqlx::Error> {
    let normalized = phone.trim();
    let digits = normalized.trim_start_matches('+');
    if digits.is_empty() {
        return Err(sqlx::Error::Protocol(
            "cannot derive currency_code from empty shop phone".into(),
        ));
    }

    for (code, currency) in PHONE_CODE_TO_CURRENCY {
        if digits.starts_with(code) {
            return Ok(currency);
        }
    }

    Err(sqlx::Error::Protocol(
        format!("unsupported phone code for currency derivation: {}", phone).into(),
    ))
}

pub fn currency_symbol(code: &str) -> Option<&'static str> {
    Some(match code {
        "NGN" => "₦",
        "GHS" => "GH₵",
        "KES" => "KSh",
        "UGX" => "USh",
        "TZS" => "TSh",
        "RWF" => "RF",
        "ZAR" => "R",
        "AFN" => "Af",
        "ALL" => "L",
        "AMD" => "֏",
        "AOA" => "Kz",
        "AWG" => "Afl",
        "BAM" => "KM",
        "BIF" => "FBu",
        "BND" => "B$",
        "BWP" => "P",
        "BYN" => "Br",
        "BZD" => "BZ$",
        "CDF" => "FC",
        "CUP" => "₱",
        "CVE" => "Esc",
        "DJF" => "Fdj",
        "EGP" => "E£",
        "ETB" => "Br",
        "FKP" => "FK£",
        "FJD" => "FJ$",
        "GMD" => "D",
        "GNF" => "FG",
        "GYD" => "GY$",
        "HTG" => "G",
        "ILS" => "₪",
        "IRR" => "﷼",
        "ISK" => "kr",
        "KHR" => "៛",
        "KMF" => "CF",
        "KPW" => "₩",
        "LAK" => "₭",
        "LRD" => "L$",
        "LSL" => "L",
        "LYD" => "LD",
        "MAD" => "MAD",
        "MDL" => "L",
        "MGA" => "Ar",
        "MKD" => "ден",
        "MMK" => "K",
        "MOP" => "MOP$",
        "MRU" => "UM",
        "MUR" => "₨",
        "MWK" => "MK",
        "MZN" => "MT",
        "NAD" => "N$",
        "EUR" => "€",
        "GBP" => "£",
        "AED" => "AED",
        "SAR" => "SAR",
        "QAR" => "QAR",
        "BHD" => "BHD",
        "KWD" => "KWD",
        "OMR" => "OMR",
        "JOD" => "JOD",
        "INR" => "₹",
        "PKR" => "₨",
        "BDT" => "৳",
        "LKR" => "Rs",
        "CNY" => "¥",
        "JPY" => "¥",
        "KRW" => "₩",
        "HKD" => "HK$",
        "TWD" => "NT$",
        "SGD" => "S$",
        "MYR" => "RM",
        "IDR" => "Rp",
        "PHP" => "₱",
        "THB" => "฿",
        "VND" => "₫",
        "AUD" => "A$",
        "NZD" => "NZ$",
        "CAD" => "C$",
        "USD" => "$",
        "BRL" => "R$",
        "MXN" => "MX$",
        "ARS" => "AR$",
        "COP" => "COP",
        "CLP" => "CLP",
        "PEN" => "S/",
        "PGK" => "K",
        "RSD" => "дин.",
        "SBD" => "SI$",
        "SCR" => "₨",
        "SDG" => "SDG",
        "SHP" => "£",
        "SLL" => "Le",
        "SOS" => "Sh",
        "SRD" => "SRD$",
        "SSP" => "SSP£",
        "STN" => "Db",
        "SZL" => "L",
        "TND" => "DT",
        "TOP" => "T$",
        "UYU" => "$U",
        "PYG" => "₲",
        "BOB" => "Bs",
        "VES" => "Bs.",
        "VUV" => "VT",
        "WST" => "WS$",
        "XAF" => "FCFA",
        "XOF" => "CFA",
        "XPF" => "CFPF",
        "ZMW" => "ZK",
        "CRC" => "₡",
        "GTQ" => "Q",
        "HNL" => "L",
        "NIO" => "C$",
        "DOP" => "RD$",
        "JMD" => "J$",
        "CHF" => "CHF",
        "SEK" => "kr",
        "NOK" => "kr",
        "DKK" => "kr",
        "PLN" => "zł",
        "CZK" => "Kč",
        "HUF" => "Ft",
        "RON" => "lei",
        "BGN" => "лв",
        "UAH" => "₴",
        "TRY" => "₺",
        "RUB" => "₽",
        _ => return None,
    })
}

pub fn format_currency_amount(amount: f64, currency_code: &str) -> String {
    let formatted_amount = format_decimal_amount(amount);
    if let Some(symbol) = currency_symbol(currency_code) {
        format!("{symbol}{formatted_amount}")
    } else {
        format!("{currency_code} {formatted_amount}")
    }
}

fn format_decimal_amount(amount: f64) -> String {
    let sign = if amount.is_sign_negative() { "-" } else { "" };
    let rendered = format!("{:.2}", amount.abs());
    let mut parts = rendered.split('.');
    let integer = parts.next().unwrap_or("0");
    let fraction = parts.next().unwrap_or("00");
    let grouped_integer = group_thousands(integer);
    format!("{sign}{grouped_integer}.{fraction}")
}

fn group_thousands(integer: &str) -> String {
    let mut grouped = String::with_capacity(integer.len() + (integer.len() / 3));
    for (index, ch) in integer.chars().rev().enumerate() {
        if index > 0 && index % 3 == 0 {
            grouped.push(',');
        }
        grouped.push(ch);
    }
    grouped.chars().rev().collect()
}

const PHONE_CODE_TO_CURRENCY: &[(&str, &str)] = &[
    ("971", "AED"),
    ("966", "SAR"),
    ("974", "QAR"),
    ("973", "BHD"),
    ("965", "KWD"),
    ("968", "OMR"),
    ("962", "JOD"),
    ("972", "ILS"),
    ("880", "BDT"),
    ("886", "TWD"),
    ("856", "LAK"),
    ("855", "KHR"),
    ("853", "MOP"),
    ("852", "HKD"),
    ("850", "KPW"),
    ("692", "USD"),
    ("691", "USD"),
    ("689", "XPF"),
    ("688", "AUD"),
    ("687", "XPF"),
    ("686", "AUD"),
    ("685", "WST"),
    ("683", "NZD"),
    ("682", "NZD"),
    ("681", "XPF"),
    ("680", "USD"),
    ("679", "FJD"),
    ("678", "VUV"),
    ("677", "SBD"),
    ("676", "TOP"),
    ("675", "PGK"),
    ("673", "BND"),
    ("670", "USD"),
    ("599", "USD"),
    ("598", "UYU"),
    ("597", "SRD"),
    ("596", "EUR"),
    ("595", "PYG"),
    ("594", "EUR"),
    ("593", "USD"),
    ("592", "GYD"),
    ("591", "BOB"),
    ("590", "EUR"),
    ("509", "HTG"),
    ("508", "EUR"),
    ("507", "USD"),
    ("506", "CRC"),
    ("505", "NIO"),
    ("504", "HNL"),
    ("503", "USD"),
    ("502", "GTQ"),
    ("501", "BZD"),
    ("500", "FKP"),
    ("421", "EUR"),
    ("420", "CZK"),
    ("389", "MKD"),
    ("387", "BAM"),
    ("386", "EUR"),
    ("385", "EUR"),
    ("382", "EUR"),
    ("381", "RSD"),
    ("380", "UAH"),
    ("377", "EUR"),
    ("376", "EUR"),
    ("375", "BYN"),
    ("374", "AMD"),
    ("373", "MDL"),
    ("372", "EUR"),
    ("371", "EUR"),
    ("370", "EUR"),
    ("359", "BGN"),
    ("358", "EUR"),
    ("357", "EUR"),
    ("356", "EUR"),
    ("355", "ALL"),
    ("354", "ISK"),
    ("353", "EUR"),
    ("352", "EUR"),
    ("351", "EUR"),
    ("299", "DKK"),
    ("298", "DKK"),
    ("297", "AWG"),
    ("290", "SHP"),
    ("269", "KMF"),
    ("268", "SZL"),
    ("267", "BWP"),
    ("266", "LSL"),
    ("265", "MWK"),
    ("264", "NAD"),
    ("263", "USD"),
    ("262", "EUR"),
    ("261", "MGA"),
    ("260", "ZMW"),
    ("258", "MZN"),
    ("257", "BIF"),
    ("256", "UGX"),
    ("255", "TZS"),
    ("254", "KES"),
    ("253", "DJF"),
    ("252", "SOS"),
    ("251", "ETB"),
    ("250", "RWF"),
    ("249", "SDG"),
    ("248", "SCR"),
    ("247", "SHP"),
    ("246", "USD"),
    ("245", "XOF"),
    ("244", "AOA"),
    ("243", "CDF"),
    ("242", "XAF"),
    ("241", "XAF"),
    ("240", "XAF"),
    ("239", "STN"),
    ("238", "CVE"),
    ("237", "XAF"),
    ("236", "XAF"),
    ("235", "XAF"),
    ("234", "NGN"),
    ("233", "GHS"),
    ("232", "SLL"),
    ("231", "LRD"),
    ("230", "MUR"),
    ("229", "XOF"),
    ("228", "XOF"),
    ("227", "XOF"),
    ("226", "XOF"),
    ("225", "XOF"),
    ("224", "GNF"),
    ("223", "XOF"),
    ("222", "MRU"),
    ("221", "XOF"),
    ("220", "GMD"),
    ("218", "LYD"),
    ("216", "TND"),
    ("213", "DZD"),
    ("212", "MAD"),
    ("211", "SSP"),
    ("98", "IRR"),
    ("95", "MMK"),
    ("94", "LKR"),
    ("93", "AFN"),
    ("92", "PKR"),
    ("91", "INR"),
    ("90", "TRY"),
    ("86", "CNY"),
    ("84", "VND"),
    ("82", "KRW"),
    ("81", "JPY"),
    ("66", "THB"),
    ("65", "SGD"),
    ("64", "NZD"),
    ("63", "PHP"),
    ("62", "IDR"),
    ("61", "AUD"),
    ("60", "MYR"),
    ("58", "VES"),
    ("57", "COP"),
    ("56", "CLP"),
    ("55", "BRL"),
    ("54", "ARS"),
    ("53", "CUP"),
    ("52", "MXN"),
    ("51", "PEN"),
    ("49", "EUR"),
    ("48", "PLN"),
    ("47", "NOK"),
    ("46", "SEK"),
    ("45", "DKK"),
    ("44", "GBP"),
    ("43", "EUR"),
    ("41", "CHF"),
    ("40", "RON"),
    ("39", "EUR"),
    ("36", "HUF"),
    ("34", "EUR"),
    ("33", "EUR"),
    ("32", "EUR"),
    ("31", "EUR"),
    ("30", "EUR"),
    ("27", "ZAR"),
    ("20", "EGP"),
    ("7", "RUB"),
    ("1", "USD"),
];
