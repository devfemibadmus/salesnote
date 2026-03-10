use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use sqlx::{PgPool, Postgres, Row, Transaction};
use std::collections::HashMap;

use crate::api::sql::common::AUTH_CTE;
use crate::models::IdPayload;

#[derive(Debug, Serialize, Deserialize, Clone, Copy, PartialEq, Eq, Default)]
#[serde(rename_all = "snake_case")]
pub enum SaleStatus {
    #[default]
    Paid,
    Invoice,
}

impl SaleStatus {
    pub fn as_str(self) -> &'static str {
        match self {
            SaleStatus::Paid => "paid",
            SaleStatus::Invoice => "invoice",
        }
    }

    pub fn is_paid(self) -> bool {
        matches!(self, SaleStatus::Paid)
    }

    fn from_db(value: &str) -> Self {
        match value {
            "invoice" => SaleStatus::Invoice,
            _ => SaleStatus::Paid,
        }
    }
}

#[derive(Debug, Deserialize, Clone)]
pub struct SaleItemInput {
    pub product_name: String,
    pub quantity: f64,
    pub unit_price: f64,
}

#[derive(Debug, Deserialize, Clone)]
pub struct SaleInput {
    pub signature_id: i64,
    pub customer_name: String,
    pub customer_contact: String,
    #[serde(default)]
    pub status: SaleStatus,
    pub created_at: Option<String>,
    #[serde(default)]
    pub discount_amount: f64,
    #[serde(default, alias = "tax_amount")]
    pub vat_amount: f64,
    #[serde(default)]
    pub service_fee_amount: f64,
    #[serde(default)]
    pub delivery_fee_amount: f64,
    #[serde(default)]
    pub rounding_amount: f64,
    #[serde(default)]
    pub other_amount: f64,
    #[serde(default)]
    pub other_label: String,
    pub items: Vec<SaleItemInput>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct SaleUpdateInput {
    pub signature_id: Option<i64>,
    pub customer_name: Option<String>,
    pub customer_contact: Option<String>,
    pub status: Option<SaleStatus>,
    pub items: Option<Vec<SaleItemInput>>,
    pub discount_amount: Option<f64>,
    #[serde(alias = "tax_amount")]
    pub vat_amount: Option<f64>,
    pub service_fee_amount: Option<f64>,
    pub delivery_fee_amount: Option<f64>,
    pub rounding_amount: Option<f64>,
    pub other_amount: Option<f64>,
    pub other_label: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct SaleItem {
    pub id: i64,
    pub sale_id: i64,
    pub product_name: String,
    pub quantity: f64,
    pub unit_price: f64,
    pub line_total: f64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Sale {
    pub id: i64,
    pub shop_id: i64,
    pub signature_id: i64,
    #[serde(default)]
    pub status: SaleStatus,
    pub customer_name: Option<String>,
    pub customer_contact: Option<String>,
    #[serde(default)]
    pub subtotal: f64,
    #[serde(default)]
    pub discount_amount: f64,
    #[serde(default)]
    pub vat_amount: f64,
    #[serde(default)]
    pub service_fee_amount: f64,
    #[serde(default)]
    pub delivery_fee_amount: f64,
    #[serde(default)]
    pub rounding_amount: f64,
    #[serde(default)]
    pub other_amount: f64,
    #[serde(default)]
    pub other_label: String,
    pub total: f64,
    pub created_at: String,
    pub items: Vec<SaleItem>,
}

#[derive(Debug)]
pub struct SaleMeta {
    pub created_at: String,
}

#[derive(Debug, Clone)]
pub struct SaleMetaPayload {
    pub shop_id: i64,
    pub sale_id: i64,
}

#[derive(Debug, Clone)]
pub struct AuthorizedSaleCreatePayload {
    pub shop_id: i64,
    pub device_id: i64,
    pub input: SaleInput,
    pub created_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone)]
pub struct SaleUpdatePayload {
    pub sale_id: i64,
    pub input: SaleUpdateInput,
}

#[derive(Debug, Clone)]
pub struct AuthorizedSaleListPayload {
    pub shop_id: i64,
    pub device_id: i64,
    pub page: i64,
    pub per_page: i64,
    pub include_items: bool,
    pub status: Option<SaleStatus>,
    pub search_query: Option<String>,
    pub start_date: Option<NaiveDate>,
    pub end_date: Option<NaiveDate>,
}

#[derive(Debug, Clone)]
pub struct AuthorizedSaleUpdatePayload {
    pub shop_id: i64,
    pub device_id: i64,
    pub sale_id: i64,
    pub input: SaleUpdateInput,
}

#[derive(Debug, Clone)]
pub struct AuthorizedSaleDeletePayload {
    pub shop_id: i64,
    pub device_id: i64,
    pub sale_id: i64,
}

#[derive(Debug, Clone)]
pub struct AuthorizedSaleGetPayload {
    pub shop_id: i64,
    pub device_id: i64,
    pub sale_id: i64,
}

#[derive(Debug)]
pub enum AuthorizedSaleListResult {
    Unauthorized,
    Sales(Vec<Sale>),
}

#[derive(Debug)]
pub enum AuthorizedSaleUpdateResult {
    Unauthorized,
    NotFound,
    WindowExpired,
    SignatureNotFound,
    Updated(Sale),
}

#[derive(Debug)]
pub enum AuthorizedSaleDeleteResult {
    Unauthorized,
    NotFound,
    WindowExpired,
    Deleted,
}

#[derive(Debug)]
pub enum AuthorizedSaleGetResult {
    Unauthorized,
    NotFound,
    Sale(Sale),
}

#[derive(Debug)]
pub enum AuthorizedSaleCreateResult {
    Unauthorized,
    SignatureNotFound,
    ShopMismatch,
    Created(Sale),
}

impl Sale {
    pub async fn get_authorized(
        pool: &PgPool,
        payload: &AuthorizedSaleGetPayload,
    ) -> Result<AuthorizedSaleGetResult, sqlx::Error> {
        let sql = format!(
            r#"
            WITH {},
            sale_row AS (
              SELECT id, shop_id, signature_id, status, customer_name, customer_contact,
                     subtotal, discount_amount, vat_amount, service_fee_amount,
                     delivery_fee_amount, rounding_amount, other_amount, other_label,
                     total, created_at
              FROM sales
              WHERE id = $3
                AND shop_id = $1
                AND EXISTS (SELECT 1 FROM auth_active)
            )
            SELECT
              EXISTS(SELECT 1 FROM auth_active) AS is_active,
              (
                SELECT json_build_object(
                  'id', s.id,
                  'shop_id', s.shop_id,
                  'signature_id', s.signature_id,
                  'status', s.status,
                  'customer_name', s.customer_name,
                  'customer_contact', s.customer_contact,
                  'subtotal', s.subtotal,
                  'discount_amount', s.discount_amount,
                  'vat_amount', s.vat_amount,
                  'service_fee_amount', s.service_fee_amount,
                  'delivery_fee_amount', s.delivery_fee_amount,
                  'rounding_amount', s.rounding_amount,
                  'other_amount', s.other_amount,
                  'other_label', s.other_label,
                  'total', s.total,
                  'created_at', s.created_at::text,
                  'items', COALESCE((
                    SELECT json_agg(json_build_object(
                      'id', si.id,
                      'sale_id', si.sale_id,
                      'product_name', si.product_name,
                      'quantity', si.quantity,
                      'unit_price', si.unit_price,
                      'line_total', si.line_total
                    ) ORDER BY si.id ASC)
                    FROM sale_items si
                    WHERE si.sale_id = s.id
                  ), '[]'::json)
                )
                FROM sale_row s
              ) AS sale_json
            "#,
            AUTH_CTE
        );

        let row = sqlx::query(&sql)
            .bind(payload.shop_id)
            .bind(payload.device_id)
            .bind(payload.sale_id)
            .fetch_one(pool)
            .await?;

        let is_active: bool = row.get("is_active");
        if !is_active {
            return Ok(AuthorizedSaleGetResult::Unauthorized);
        }

        let sale_json: Option<serde_json::Value> = row.try_get("sale_json").ok();
        let Some(sale_json) = sale_json else {
            return Ok(AuthorizedSaleGetResult::NotFound);
        };
        let sale = serde_json::from_value::<Sale>(sale_json)
            .map_err(|e| sqlx::Error::Protocol(format!("invalid sale json: {}", e).into()))?;
        Ok(AuthorizedSaleGetResult::Sale(sale))
    }

    pub async fn list_authorized_paged(
        pool: &PgPool,
        payload: &AuthorizedSaleListPayload,
    ) -> Result<AuthorizedSaleListResult, sqlx::Error> {
        let offset = (payload.page - 1) * payload.per_page;
        let sql = format!(
            r#"
            WITH {},
            paged_sales AS (
              SELECT id, shop_id, signature_id, status, customer_name, customer_contact,
                     subtotal, discount_amount, vat_amount, service_fee_amount,
                     delivery_fee_amount, rounding_amount, other_amount, other_label,
                     total, created_at
              FROM sales
              WHERE shop_id = $1
                AND EXISTS (SELECT 1 FROM auth_active)
                AND ($9::text IS NULL OR status = $9::text)
                AND (
                  $5::text IS NULL
                  OR customer_name ILIKE CONCAT('%', $5::text, '%')
                  OR customer_contact ILIKE CONCAT('%', $5::text, '%')
                  OR CAST(id AS text) ILIKE CONCAT('%', $5::text, '%')
                  OR EXISTS (
                    SELECT 1
                    FROM sale_items si_search
                    WHERE si_search.sale_id = sales.id
                      AND si_search.product_name ILIKE CONCAT('%', $5::text, '%')
                  )
                )
                AND ($7::date IS NULL OR created_at::date >= $7)
                AND ($8::date IS NULL OR created_at::date <= $8)
              ORDER BY created_at DESC
              LIMIT $3 OFFSET $4
            )
            SELECT
              EXISTS(SELECT 1 FROM auth_active) AS is_active,
              COALESCE(json_agg(
                json_build_object(
                  'id', s.id,
                  'shop_id', s.shop_id,
                  'signature_id', s.signature_id,
                  'status', s.status,
                  'customer_name', s.customer_name,
                  'customer_contact', s.customer_contact,
                  'subtotal', s.subtotal,
                  'discount_amount', s.discount_amount,
                  'vat_amount', s.vat_amount,
                  'service_fee_amount', s.service_fee_amount,
                  'delivery_fee_amount', s.delivery_fee_amount,
                  'rounding_amount', s.rounding_amount,
                  'other_amount', s.other_amount,
                  'other_label', s.other_label,
                  'total', s.total,
                  'created_at', s.created_at::text,
                  'items',
                    CASE
                      WHEN $6 THEN (
                        SELECT COALESCE(json_agg(json_build_object(
                          'id', si.id,
                          'sale_id', si.sale_id,
                          'product_name', si.product_name,
                          'quantity', si.quantity,
                          'unit_price', si.unit_price,
                          'line_total', si.line_total
                        ) ORDER BY si.id ASC), '[]'::json)
                        FROM sale_items si
                        WHERE si.sale_id = s.id
                      )
                      ELSE '[]'::json
                    END
                )
                ORDER BY s.created_at DESC
              ), '[]'::json) AS sales_json
            FROM paged_sales s
            "#,
            AUTH_CTE
        );

        let row = sqlx::query(&sql)
            .bind(payload.shop_id)
            .bind(payload.device_id)
            .bind(payload.per_page)
            .bind(offset)
            .bind(payload.search_query.as_deref())
            .bind(payload.include_items)
            .bind(payload.start_date)
            .bind(payload.end_date)
            .bind(payload.status.map(|status| status.as_str()))
            .fetch_one(pool)
            .await?;

        let is_active: bool = row.get("is_active");
        if !is_active {
            return Ok(AuthorizedSaleListResult::Unauthorized);
        }

        let sales_json: serde_json::Value = row.get("sales_json");
        let sales = serde_json::from_value::<Vec<Sale>>(sales_json).unwrap_or_default();
        Ok(AuthorizedSaleListResult::Sales(sales))
    }

    pub async fn update_authorized(
        pool: &PgPool,
        payload: &AuthorizedSaleUpdatePayload,
    ) -> Result<AuthorizedSaleUpdateResult, sqlx::Error> {
        let input = payload.input.clone();
        let replace_items = input.items.is_some();
        let items = input.items.unwrap_or_default();
        let product_names: Vec<String> = items.iter().map(|i| i.product_name.clone()).collect();
        let quantities: Vec<f64> = items.iter().map(|i| i.quantity).collect();
        let unit_prices: Vec<f64> = items.iter().map(|i| i.unit_price).collect();
        let line_totals: Vec<f64> = items.iter().map(|i| i.quantity * i.unit_price).collect();

        let sql = format!(
            r#"
            WITH {},
            sale_row AS (
              SELECT id, shop_id, signature_id, status, customer_name, customer_contact,
                     subtotal, discount_amount, vat_amount, service_fee_amount,
                     delivery_fee_amount, rounding_amount, other_amount, other_label,
                     total, created_at, created_at::date AS day
              FROM sales
              WHERE id = $3
                AND shop_id = $1
                AND EXISTS (SELECT 1 FROM auth_active)
            ),
            window_ok AS (
              SELECT *
              FROM sale_row
              WHERE created_at >= NOW() - interval '24 hours'
            ),
            sig_ok AS (
              SELECT
                CASE
                  WHEN $4::bigint IS NULL THEN TRUE
                  ELSE EXISTS(SELECT 1 FROM signatures WHERE id = $4 AND shop_id = $1)
                END AS ok
            ),
            old_items AS (
              SELECT product_name, SUM(quantity)::float8 AS qty
              FROM sale_items
              WHERE sale_id IN (SELECT id FROM window_ok)
              GROUP BY product_name
            ),
            deleted_old AS (
              DELETE FROM sale_items
              WHERE sale_id IN (SELECT id FROM window_ok)
                AND $5::bool
                AND (SELECT ok FROM sig_ok)
              RETURNING id
            ),
            input_items AS (
              SELECT *
              FROM unnest(
                $6::text[],
                $7::float8[],
                $8::float8[],
                $9::float8[]
              ) WITH ORDINALITY AS i(product_name, quantity, unit_price, line_total, ord)
            ),
            inserted_items AS (
              INSERT INTO sale_items (sale_id, product_name, quantity, unit_price, line_total)
              SELECT w.id, i.product_name, i.quantity, i.unit_price, i.line_total
              FROM window_ok w
              JOIN input_items i ON TRUE
              WHERE $5::bool
                AND (SELECT ok FROM sig_ok)
              ORDER BY i.ord
              RETURNING id, sale_id, product_name, quantity, unit_price, line_total
            ),
            new_total AS (
              SELECT
                CASE
                  WHEN $5::bool THEN COALESCE((SELECT SUM(line_total)::float8 FROM input_items), 0.0)
                  ELSE COALESCE((SELECT subtotal FROM sale_row), 0.0)
                END AS subtotal,
                COALESCE($19::text, (SELECT status FROM sale_row)) AS status,
                COALESCE($12::float8, (SELECT discount_amount FROM sale_row)) AS discount_amount,
                COALESCE($13::float8, (SELECT vat_amount FROM sale_row)) AS vat_amount,
                COALESCE($14::float8, (SELECT service_fee_amount FROM sale_row)) AS service_fee_amount,
                COALESCE($15::float8, (SELECT delivery_fee_amount FROM sale_row)) AS delivery_fee_amount,
                COALESCE($16::float8, (SELECT rounding_amount FROM sale_row)) AS rounding_amount,
                COALESCE($17::float8, (SELECT other_amount FROM sale_row)) AS other_amount,
                COALESCE($18::text, (SELECT other_label FROM sale_row)) AS other_label,
                (
                  CASE
                    WHEN $5::bool THEN COALESCE((SELECT SUM(line_total)::float8 FROM input_items), 0.0)
                    ELSE COALESCE((SELECT subtotal FROM sale_row), 0.0)
                  END
                  - COALESCE($12::float8, (SELECT discount_amount FROM sale_row))
                  + COALESCE($13::float8, (SELECT vat_amount FROM sale_row))
                  + COALESCE($14::float8, (SELECT service_fee_amount FROM sale_row))
                  + COALESCE($15::float8, (SELECT delivery_fee_amount FROM sale_row))
                  + COALESCE($16::float8, (SELECT rounding_amount FROM sale_row))
                  + COALESCE($17::float8, (SELECT other_amount FROM sale_row))
                ) AS total
            ),
            updated_sale AS (
              UPDATE sales s
              SET signature_id = COALESCE($4, s.signature_id),
                  status = (SELECT status FROM new_total),
                  customer_name = COALESCE($10, s.customer_name),
                  customer_contact = COALESCE($11, s.customer_contact),
                  subtotal = (SELECT subtotal FROM new_total),
                  discount_amount = (SELECT discount_amount FROM new_total),
                  vat_amount = (SELECT vat_amount FROM new_total),
                  service_fee_amount = (SELECT service_fee_amount FROM new_total),
                  delivery_fee_amount = (SELECT delivery_fee_amount FROM new_total),
                  rounding_amount = (SELECT rounding_amount FROM new_total),
                  other_amount = (SELECT other_amount FROM new_total),
                  other_label = (SELECT other_label FROM new_total),
                  total = (SELECT total FROM new_total)
              WHERE s.id IN (SELECT id FROM window_ok)
                AND (SELECT ok FROM sig_ok)
              RETURNING s.id, s.shop_id, s.signature_id, s.status, s.customer_name, s.customer_contact,
                        s.subtotal, s.discount_amount, s.vat_amount, s.service_fee_amount,
                        s.delivery_fee_amount, s.rounding_amount, s.other_amount, s.other_label,
                        s.total,
                        s.created_at::text AS created_at, s.created_at::date AS day,
                        (SELECT total FROM sale_row) AS old_total,
                        (SELECT status FROM sale_row) AS old_status
            ),
            shop_delta AS (
              SELECT
                u.id,
                CASE
                  WHEN u.old_status = 'paid' AND u.status = 'paid' THEN u.total - u.old_total
                  WHEN u.old_status <> 'paid' AND u.status = 'paid' THEN u.total
                  WHEN u.old_status = 'paid' AND u.status <> 'paid' THEN -u.old_total
                  ELSE 0.0
                END AS revenue_delta,
                CASE
                  WHEN u.old_status = 'paid' AND u.status <> 'paid' THEN -1
                  WHEN u.old_status <> 'paid' AND u.status = 'paid' THEN 1
                  ELSE 0
                END AS orders_delta,
                CASE
                  WHEN COALESCE(TRIM(u.customer_name), '') = '' THEN 0
                  WHEN u.old_status = 'paid' AND u.status <> 'paid' THEN -1
                  WHEN u.old_status <> 'paid' AND u.status = 'paid' THEN 1
                  ELSE 0
                END AS customers_delta
              FROM updated_sale u
            ),
            update_shop AS (
              UPDATE shops sh
              SET total_revenue = GREATEST(0, sh.total_revenue + d.revenue_delta),
                  total_orders = GREATEST(0, sh.total_orders + d.orders_delta),
                  total_customers = GREATEST(0, sh.total_customers + d.customers_delta)
              FROM updated_sale u
              JOIN shop_delta d ON d.id = u.id
              WHERE sh.id = u.shop_id
                AND (d.revenue_delta <> 0 OR d.orders_delta <> 0 OR d.customers_delta <> 0)
              RETURNING sh.id
            ),
            upsert_sales_daily AS (
              INSERT INTO shop_sales_daily (shop_id, day, total, orders)
              SELECT u.shop_id, u.day, d.revenue_delta, d.orders_delta
              FROM updated_sale u
              JOIN shop_delta d ON d.id = u.id
              WHERE d.revenue_delta <> 0 OR d.orders_delta <> 0
              ON CONFLICT (shop_id, day)
              DO UPDATE
              SET total = shop_sales_daily.total + EXCLUDED.total,
                  orders = shop_sales_daily.orders + EXCLUDED.orders,
                  updated_at = NOW()
              RETURNING shop_id
            ),
            new_items_agg AS (
              SELECT
                CASE
                  WHEN $5::bool THEN i.product_name
                  ELSE o.product_name
                END AS product_name,
                CASE
                  WHEN $5::bool THEN COALESCE(SUM(i.quantity)::float8, 0.0)
                  ELSE COALESCE(MAX(o.qty), 0.0)
                END AS qty
              FROM input_items i
              FULL JOIN old_items o ON o.product_name = i.product_name
              GROUP BY
                CASE
                  WHEN $5::bool THEN i.product_name
                  ELSE o.product_name
                END
            ),
            delta AS (
              SELECT
                COALESCE(n.product_name, o.product_name) AS product_name,
                (
                  CASE
                    WHEN (SELECT status FROM new_total) = 'paid' THEN COALESCE(n.qty, 0.0)
                    ELSE 0.0
                  END
                  - CASE
                    WHEN (SELECT old_status FROM updated_sale LIMIT 1) = 'paid' THEN COALESCE(o.qty, 0.0)
                    ELSE 0.0
                  END
                ) AS qty
              FROM old_items o
              FULL JOIN new_items_agg n
                ON n.product_name = o.product_name
            ),
            upsert_product_daily AS (
              INSERT INTO shop_product_daily (shop_id, product_name, day, quantity)
              SELECT u.shop_id, d.product_name, u.day, d.qty
              FROM updated_sale u
              JOIN delta d ON d.qty <> 0
              ON CONFLICT (shop_id, product_name, day)
              DO UPDATE
              SET quantity = shop_product_daily.quantity + EXCLUDED.quantity,
                  updated_at = NOW()
              RETURNING shop_id
            ),
            cleanup_product_daily AS (
              DELETE FROM shop_product_daily p
              USING updated_sale u
              WHERE p.shop_id = u.shop_id
                AND p.day = u.day
                AND p.quantity <= 0
              RETURNING p.shop_id
            ),
            cleanup_sales_daily AS (
              DELETE FROM shop_sales_daily d
              USING updated_sale u
              WHERE d.shop_id = u.shop_id
                AND d.day = u.day
                AND d.total <= 0
                AND d.orders <= 0
              RETURNING d.shop_id
            ),
            sale_json AS (
              SELECT
                json_build_object(
                  'id', u.id,
                  'shop_id', u.shop_id,
                  'signature_id', u.signature_id,
                  'status', u.status,
                  'customer_name', u.customer_name,
                  'customer_contact', u.customer_contact,
                  'subtotal', u.subtotal,
                  'discount_amount', u.discount_amount,
                  'vat_amount', u.vat_amount,
                  'service_fee_amount', u.service_fee_amount,
                  'delivery_fee_amount', u.delivery_fee_amount,
                  'rounding_amount', u.rounding_amount,
                  'other_amount', u.other_amount,
                  'other_label', u.other_label,
                  'total', u.total,
                  'created_at', u.created_at,
                  'items',
                    CASE
                      WHEN $5::bool THEN COALESCE((
                        SELECT json_agg(json_build_object(
                          'id', ii.id,
                          'sale_id', ii.sale_id,
                          'product_name', ii.product_name,
                          'quantity', ii.quantity,
                          'unit_price', ii.unit_price,
                          'line_total', ii.line_total
                        ) ORDER BY ii.id ASC)
                        FROM inserted_items ii
                      ), '[]'::json)
                      ELSE COALESCE((
                        SELECT json_agg(json_build_object(
                          'id', si.id,
                          'sale_id', si.sale_id,
                          'product_name', si.product_name,
                          'quantity', si.quantity,
                          'unit_price', si.unit_price,
                          'line_total', si.line_total
                        ) ORDER BY si.id ASC)
                        FROM sale_items si
                        WHERE si.sale_id = u.id
                      ), '[]'::json)
                    END
                ) AS v
              FROM updated_sale u
            )
            SELECT
              EXISTS(SELECT 1 FROM auth_active) AS auth_ok,
              EXISTS(SELECT 1 FROM sale_row) AS sale_exists,
              EXISTS(SELECT 1 FROM window_ok) AS window_ok,
              (SELECT ok FROM sig_ok) AS sig_ok,
              (SELECT v FROM sale_json) AS sale_json
            "#,
            AUTH_CTE
        );

        let row = sqlx::query(&sql)
            .bind(payload.shop_id)
            .bind(payload.device_id)
            .bind(payload.sale_id)
            .bind(input.signature_id)
            .bind(replace_items)
            .bind(&product_names)
            .bind(&quantities)
            .bind(&unit_prices)
            .bind(&line_totals)
            .bind(input.customer_name)
            .bind(input.customer_contact)
            .bind(input.discount_amount)
            .bind(input.vat_amount)
            .bind(input.service_fee_amount)
            .bind(input.delivery_fee_amount)
            .bind(input.rounding_amount)
            .bind(input.other_amount)
            .bind(input.other_label)
            .bind(input.status.map(|status| status.as_str()))
            .fetch_one(pool)
            .await?;

        let auth_ok: bool = row.get("auth_ok");
        if !auth_ok {
            return Ok(AuthorizedSaleUpdateResult::Unauthorized);
        }
        let sale_exists: bool = row.get("sale_exists");
        if !sale_exists {
            return Ok(AuthorizedSaleUpdateResult::NotFound);
        }
        let window_ok: bool = row.get("window_ok");
        if !window_ok {
            return Ok(AuthorizedSaleUpdateResult::WindowExpired);
        }
        let sig_ok: bool = row.get("sig_ok");
        if !sig_ok {
            return Ok(AuthorizedSaleUpdateResult::SignatureNotFound);
        }
        let sale_json: Option<serde_json::Value> = row.try_get("sale_json").ok();
        let Some(sale_json) = sale_json else {
            return Ok(AuthorizedSaleUpdateResult::NotFound);
        };
        let sale = serde_json::from_value::<Sale>(sale_json)
            .map_err(|e| sqlx::Error::Protocol(format!("invalid sale json: {}", e).into()))?;
        Ok(AuthorizedSaleUpdateResult::Updated(sale))
    }

    pub async fn delete_authorized(
        pool: &PgPool,
        payload: &AuthorizedSaleDeletePayload,
    ) -> Result<AuthorizedSaleDeleteResult, sqlx::Error> {
        let sql = format!(
            r#"
            WITH {},
            sale_row AS (
              SELECT id, shop_id, status, total, created_at, created_at::date AS day, customer_name
              FROM sales
              WHERE id = $3
                AND shop_id = $1
                AND EXISTS (SELECT 1 FROM auth_active)
            ),
            window_ok AS (
              SELECT *
              FROM sale_row
              WHERE created_at >= NOW() - interval '24 hours'
            ),
            old_items AS (
              SELECT product_name, SUM(quantity)::float8 AS qty
              FROM sale_items
              WHERE sale_id IN (SELECT id FROM window_ok)
              GROUP BY product_name
            ),
            deleted_items AS (
              DELETE FROM sale_items
              WHERE sale_id IN (SELECT id FROM window_ok)
              RETURNING id
            ),
            deleted_sale AS (
              DELETE FROM sales
              WHERE id IN (SELECT id FROM window_ok)
              RETURNING id, shop_id, status, total, created_at::date AS day, customer_name
            ),
            update_shop AS (
              UPDATE shops sh
              SET total_revenue = GREATEST(0, sh.total_revenue - ds.total),
                  total_orders = GREATEST(0, sh.total_orders - 1),
                  total_customers = GREATEST(
                    0,
                    sh.total_customers - CASE
                      WHEN COALESCE(TRIM(ds.customer_name), '') <> '' THEN 1
                      ELSE 0
                    END
                  )
              FROM deleted_sale ds
              WHERE sh.id = ds.shop_id
                AND ds.status = 'paid'
              RETURNING sh.id
            ),
            upsert_sales_daily AS (
              INSERT INTO shop_sales_daily (shop_id, day, total, orders)
              SELECT ds.shop_id, ds.day, -ds.total, -1
              FROM deleted_sale ds
              WHERE ds.status = 'paid'
              ON CONFLICT (shop_id, day)
              DO UPDATE
              SET total = shop_sales_daily.total + EXCLUDED.total,
                  orders = shop_sales_daily.orders + EXCLUDED.orders,
                  updated_at = NOW()
              RETURNING shop_id
            ),
            delta AS (
              SELECT product_name, -qty AS qty
              FROM old_items
              WHERE EXISTS (SELECT 1 FROM deleted_sale WHERE status = 'paid')
            ),
            upsert_product_daily AS (
              INSERT INTO shop_product_daily (shop_id, product_name, day, quantity)
              SELECT ds.shop_id, d.product_name, ds.day, d.qty
              FROM deleted_sale ds
              JOIN delta d ON TRUE
              ON CONFLICT (shop_id, product_name, day)
              DO UPDATE
              SET quantity = shop_product_daily.quantity + EXCLUDED.quantity,
                  updated_at = NOW()
              RETURNING shop_id
            ),
            cleanup_product_daily AS (
              DELETE FROM shop_product_daily p
              USING deleted_sale ds
              WHERE p.shop_id = ds.shop_id
                AND p.day = ds.day
                AND p.quantity <= 0
              RETURNING p.shop_id
            ),
            cleanup_sales_daily AS (
              DELETE FROM shop_sales_daily d
              USING deleted_sale ds
              WHERE d.shop_id = ds.shop_id
                AND d.day = ds.day
                AND d.total <= 0
                AND d.orders <= 0
              RETURNING d.shop_id
            )
            SELECT
              EXISTS(SELECT 1 FROM auth_active) AS auth_ok,
              EXISTS(SELECT 1 FROM sale_row) AS sale_exists,
              EXISTS(SELECT 1 FROM window_ok) AS window_ok,
              EXISTS(SELECT 1 FROM deleted_sale) AS deleted
            "#,
            AUTH_CTE
        );

        let row = sqlx::query(&sql)
            .bind(payload.shop_id)
            .bind(payload.device_id)
            .bind(payload.sale_id)
            .fetch_one(pool)
            .await?;

        let auth_ok: bool = row.get("auth_ok");
        if !auth_ok {
            return Ok(AuthorizedSaleDeleteResult::Unauthorized);
        }
        let sale_exists: bool = row.get("sale_exists");
        if !sale_exists {
            return Ok(AuthorizedSaleDeleteResult::NotFound);
        }
        let window_ok: bool = row.get("window_ok");
        if !window_ok {
            return Ok(AuthorizedSaleDeleteResult::WindowExpired);
        }
        let deleted: bool = row.get("deleted");
        if deleted {
            Ok(AuthorizedSaleDeleteResult::Deleted)
        } else {
            Ok(AuthorizedSaleDeleteResult::NotFound)
        }
    }

    async fn upsert_shop_product_daily_batch(
        tx: &mut Transaction<'_, Postgres>,
        shop_id: i64,
        day: NaiveDate,
        deltas: &HashMap<String, f64>,
    ) -> Result<(), sqlx::Error> {
        if deltas.is_empty() {
            return Ok(());
        }

        let mut product_names = Vec::with_capacity(deltas.len());
        let mut quantities = Vec::with_capacity(deltas.len());
        for (name, qty) in deltas {
            product_names.push(name.clone());
            quantities.push(*qty);
        }

        sqlx::query(
            "INSERT INTO shop_product_daily (shop_id, product_name, day, quantity)
             SELECT $1, x.product_name, $2, x.quantity
             FROM unnest($3::text[], $4::float8[]) AS x(product_name, quantity)
             ON CONFLICT (shop_id, product_name, day)
             DO UPDATE
             SET quantity = shop_product_daily.quantity + EXCLUDED.quantity,
                 updated_at = NOW()",
        )
        .bind(shop_id)
        .bind(day)
        .bind(&product_names)
        .bind(&quantities)
        .execute(&mut **tx)
        .await?;

        sqlx::query(
            "DELETE FROM shop_product_daily
             WHERE shop_id = $1
               AND day = $2
               AND quantity <= 0",
        )
        .bind(shop_id)
        .bind(day)
        .execute(&mut **tx)
        .await?;

        Ok(())
    }

    async fn upsert_shop_sales_daily(
        tx: &mut Transaction<'_, Postgres>,
        shop_id: i64,
        day: NaiveDate,
        total_delta: f64,
        orders_delta: i64,
    ) -> Result<(), sqlx::Error> {
        sqlx::query(
            "INSERT INTO shop_sales_daily (shop_id, day, total, orders)
             VALUES ($1, $2, $3, $4)
             ON CONFLICT (shop_id, day)
             DO UPDATE
             SET total = shop_sales_daily.total + EXCLUDED.total,
                 orders = shop_sales_daily.orders + EXCLUDED.orders,
                 updated_at = NOW()",
        )
        .bind(shop_id)
        .bind(day)
        .bind(total_delta)
        .bind(orders_delta)
        .execute(&mut **tx)
        .await?;

        sqlx::query(
            "DELETE FROM shop_sales_daily
             WHERE shop_id = $1
               AND day = $2
               AND total <= 0
               AND orders <= 0",
        )
        .bind(shop_id)
        .bind(day)
        .execute(&mut **tx)
        .await?;

        Ok(())
    }

    pub async fn count_by_shop(pool: &PgPool, payload: &IdPayload) -> Result<i64, sqlx::Error> {
        let row =
            sqlx::query("SELECT COUNT(*) as cnt FROM sales WHERE shop_id = $1 AND status = 'paid'")
                .bind(payload.id)
                .fetch_one(pool)
                .await?;

        Ok(row.get("cnt"))
    }

    pub async fn set_created_at(
        pool: &PgPool,
        payload: &IdPayload,
        created_at: DateTime<Utc>,
    ) -> Result<(), sqlx::Error> {
        let mut tx: Transaction<'_, Postgres> = pool.begin().await?;

        let sale_row = sqlx::query(
            "SELECT shop_id, status, total, created_at::date AS created_day
             FROM sales
             WHERE id = $1",
        )
        .bind(payload.id)
        .fetch_optional(&mut *tx)
        .await?;

        let Some(sale_row) = sale_row else {
            tx.commit().await?;
            return Ok(());
        };

        let shop_id: i64 = sale_row.get("shop_id");
        let status = SaleStatus::from_db(&sale_row.get::<String, _>("status"));
        let total: f64 = sale_row.get("total");
        let old_day: NaiveDate = sale_row.get("created_day");
        let new_day = created_at.date_naive();

        sqlx::query("UPDATE sales SET created_at = $1 WHERE id = $2")
            .bind(created_at)
            .bind(payload.id)
            .execute(&mut *tx)
            .await?;

        if old_day != new_day && status.is_paid() {
            Self::upsert_shop_sales_daily(&mut tx, shop_id, old_day, -total, -1).await?;
            Self::upsert_shop_sales_daily(&mut tx, shop_id, new_day, total, 1).await?;
        }

        tx.commit().await?;
        Ok(())
    }

    pub async fn list_by_shop(
        pool: &PgPool,
        payload: &IdPayload,
    ) -> Result<Vec<Sale>, sqlx::Error> {
        Self::list_by_shop_paged(pool, payload, None, None, true).await
    }

    pub async fn list_by_shop_paged(
        pool: &PgPool,
        payload: &IdPayload,
        page: Option<i64>,
        per_page: Option<i64>,
        include_items: bool,
    ) -> Result<Vec<Sale>, sqlx::Error> {
        let page_value = page.unwrap_or(1).max(1);
        let per_page_value = per_page.unwrap_or(50).clamp(1, 200);
        let offset = (page_value - 1) * per_page_value;

        let sales_rows = sqlx::query(
            "SELECT id, shop_id, signature_id, status, customer_name, customer_contact,
                    subtotal, discount_amount, vat_amount, service_fee_amount,
                    delivery_fee_amount, rounding_amount, other_amount, other_label,
                    total, created_at::text as created_at
             FROM sales
             WHERE shop_id = $1
             ORDER BY created_at DESC
             LIMIT $2 OFFSET $3",
        )
        .bind(&payload.id)
        .bind(per_page_value)
        .bind(offset)
        .fetch_all(pool)
        .await?;

        if sales_rows.is_empty() {
            return Ok(Vec::new());
        }

        let mut items_by_sale_id: HashMap<i64, Vec<SaleItem>> = HashMap::new();
        if include_items {
            let sale_ids: Vec<i64> = sales_rows.iter().map(|row| row.get("id")).collect();
            let items_rows = sqlx::query(
                "SELECT id, sale_id, product_name, quantity, unit_price, line_total
                 FROM sale_items
                 WHERE sale_id = ANY($1)
                 ORDER BY id ASC",
            )
            .bind(&sale_ids)
            .fetch_all(pool)
            .await?;

            for item in items_rows {
                let sale_id: i64 = item.get("sale_id");
                items_by_sale_id.entry(sale_id).or_default().push(SaleItem {
                    id: item.get("id"),
                    sale_id,
                    product_name: item.get("product_name"),
                    quantity: item.get("quantity"),
                    unit_price: item.get("unit_price"),
                    line_total: item.get("line_total"),
                });
            }
        }

        let mut sales = Vec::with_capacity(sales_rows.len());
        for row in sales_rows {
            let sale_id: i64 = row.get("id");
            sales.push(Sale {
                id: sale_id,
                shop_id: row.get("shop_id"),
                signature_id: row.get("signature_id"),
                status: SaleStatus::from_db(&row.get::<String, _>("status")),
                customer_name: row.get("customer_name"),
                customer_contact: row.get("customer_contact"),
                subtotal: row.get("subtotal"),
                discount_amount: row.get("discount_amount"),
                vat_amount: row.get("vat_amount"),
                service_fee_amount: row.get("service_fee_amount"),
                delivery_fee_amount: row.get("delivery_fee_amount"),
                rounding_amount: row.get("rounding_amount"),
                other_amount: row.get("other_amount"),
                other_label: row.get("other_label"),
                total: row.get("total"),
                created_at: row.get("created_at"),
                items: if include_items {
                    items_by_sale_id.remove(&sale_id).unwrap_or_default()
                } else {
                    Vec::new()
                },
            });
        }

        Ok(sales)
    }

    pub async fn get_meta_for_shop(
        pool: &PgPool,
        payload: &SaleMetaPayload,
    ) -> Result<Option<SaleMeta>, sqlx::Error> {
        let row = sqlx::query(
            "SELECT created_at::text as created_at FROM sales WHERE id = $1 AND shop_id = $2",
        )
        .bind(payload.sale_id)
        .bind(payload.shop_id)
        .fetch_optional(pool)
        .await?;

        Ok(row.map(|row| SaleMeta {
            created_at: row.get("created_at"),
        }))
    }

    pub async fn create_authorized(
        pool: &PgPool,
        payload: &AuthorizedSaleCreatePayload,
    ) -> Result<AuthorizedSaleCreateResult, sqlx::Error> {
        let product_names: Vec<String> = payload
            .input
            .items
            .iter()
            .map(|i| i.product_name.clone())
            .collect();
        let quantities: Vec<f64> = payload.input.items.iter().map(|i| i.quantity).collect();
        let unit_prices: Vec<f64> = payload.input.items.iter().map(|i| i.unit_price).collect();
        let line_totals: Vec<f64> = payload
            .input
            .items
            .iter()
            .map(|i| i.quantity * i.unit_price)
            .collect();

        let sql = format!(
            r#"
            WITH {},
            signature_row AS (
              SELECT id, shop_id
              FROM signatures
              WHERE id = $3
            ),
            signature_ok AS (
              SELECT id
              FROM signature_row
              WHERE shop_id = $1
            ),
            input_items AS (
              SELECT *
              FROM unnest(
                $15::text[],
                $16::float8[],
                $17::float8[],
                $18::float8[]
              ) WITH ORDINALITY AS i(product_name, quantity, unit_price, line_total, ord)
            ),
            sale_totals AS (
              SELECT
                COALESCE(SUM(line_total), 0.0)::float8 AS subtotal,
                (
                  COALESCE(SUM(line_total), 0.0)::float8
                  - $8::float8
                  + $9::float8
                  + $10::float8
                  + $11::float8
                  + $12::float8
                  + $13::float8
                )::float8 AS total
              FROM input_items
            ),
            inserted_sale AS (
              INSERT INTO sales (
                shop_id, signature_id, status, customer_name, customer_contact,
                subtotal, discount_amount, vat_amount, service_fee_amount,
                delivery_fee_amount, rounding_amount, other_amount, other_label,
                total, created_at
              )
              SELECT
                $1,
                $3,
                $4,
                $5,
                $6,
                st.subtotal,
                $8,
                $9,
                $10,
                $11,
                $12,
                $13,
                $14,
                st.total,
                COALESCE($7, NOW())
              FROM sale_totals st
              WHERE EXISTS (SELECT 1 FROM auth_active)
                AND EXISTS (SELECT 1 FROM signature_ok)
              RETURNING id, shop_id, signature_id, status, customer_name, customer_contact,
                        subtotal, discount_amount, vat_amount, service_fee_amount,
                        delivery_fee_amount, rounding_amount, other_amount, other_label,
                        total, created_at, created_at::date AS created_day
            ),
            inserted_items AS (
              INSERT INTO sale_items (sale_id, product_name, quantity, unit_price, line_total)
              SELECT s.id, i.product_name, i.quantity, i.unit_price, i.line_total
              FROM inserted_sale s
              JOIN input_items i ON TRUE
              ORDER BY i.ord
              RETURNING id, sale_id, product_name, quantity, unit_price, line_total
            ),
            update_shop AS (
              UPDATE shops sh
              SET total_revenue = sh.total_revenue + s.total,
                  total_orders = sh.total_orders + 1,
                  total_customers = sh.total_customers + 1
              FROM inserted_sale s
              WHERE sh.id = s.shop_id
                AND s.status = 'paid'
              RETURNING sh.id
            ),
            upsert_sales_daily AS (
              INSERT INTO shop_sales_daily (shop_id, day, total, orders)
              SELECT s.shop_id, s.created_day, s.total, 1
              FROM inserted_sale s
              WHERE s.status = 'paid'
              ON CONFLICT (shop_id, day)
              DO UPDATE
              SET total = shop_sales_daily.total + EXCLUDED.total,
                  orders = shop_sales_daily.orders + EXCLUDED.orders,
                  updated_at = NOW()
              RETURNING shop_id
            ),
            product_rollup AS (
              SELECT
                s.shop_id AS shop_id,
                s.created_day AS day,
                i.product_name AS product_name,
                SUM(i.quantity)::float8 AS quantity
              FROM inserted_sale s
              JOIN input_items i ON TRUE
              WHERE s.status = 'paid'
              GROUP BY s.shop_id, s.created_day, i.product_name
            ),
            upsert_product_daily AS (
              INSERT INTO shop_product_daily (shop_id, product_name, day, quantity)
              SELECT p.shop_id, p.product_name, p.day, p.quantity
              FROM product_rollup p
              ON CONFLICT (shop_id, product_name, day)
              DO UPDATE
              SET quantity = shop_product_daily.quantity + EXCLUDED.quantity,
                  updated_at = NOW()
              RETURNING shop_id
            ),
            sale_json AS (
              SELECT json_build_object(
                'id', s.id,
                'shop_id', s.shop_id,
                'signature_id', s.signature_id,
                'status', s.status,
                'customer_name', s.customer_name,
                'customer_contact', s.customer_contact,
                'subtotal', s.subtotal,
                'discount_amount', s.discount_amount,
                'vat_amount', s.vat_amount,
                'service_fee_amount', s.service_fee_amount,
                'delivery_fee_amount', s.delivery_fee_amount,
                'rounding_amount', s.rounding_amount,
                'other_amount', s.other_amount,
                'other_label', s.other_label,
                'total', s.total,
                'created_at', s.created_at::text,
                'items',
                  COALESCE(
                    (
                      SELECT json_agg(
                        json_build_object(
                          'id', ii.id,
                          'sale_id', ii.sale_id,
                          'product_name', ii.product_name,
                          'quantity', ii.quantity,
                          'unit_price', ii.unit_price,
                          'line_total', ii.line_total
                        )
                        ORDER BY ii.id ASC
                      )
                      FROM inserted_items ii
                    ),
                    '[]'::json
                  )
              ) AS sale_json
              FROM inserted_sale s
            )
            SELECT
              EXISTS(SELECT 1 FROM auth_active) AS is_active,
              EXISTS(SELECT 1 FROM signature_row) AS signature_exists,
              EXISTS(SELECT 1 FROM signature_ok) AS signature_for_shop,
              (SELECT sale_json FROM sale_json) AS sale_json
            "#,
            AUTH_CTE
        );

        let row = sqlx::query(&sql)
            .bind(payload.shop_id)
            .bind(payload.device_id)
            .bind(payload.input.signature_id)
            .bind(payload.input.status.as_str())
            .bind(&payload.input.customer_name)
            .bind(&payload.input.customer_contact)
            .bind(payload.created_at)
            .bind(payload.input.discount_amount)
            .bind(payload.input.vat_amount)
            .bind(payload.input.service_fee_amount)
            .bind(payload.input.delivery_fee_amount)
            .bind(payload.input.rounding_amount)
            .bind(payload.input.other_amount)
            .bind(&payload.input.other_label)
            .bind(&product_names)
            .bind(&quantities)
            .bind(&unit_prices)
            .bind(&line_totals)
            .fetch_one(pool)
            .await?;

        let is_active: bool = row.get("is_active");
        if !is_active {
            return Ok(AuthorizedSaleCreateResult::Unauthorized);
        }

        let signature_exists: bool = row.get("signature_exists");
        if !signature_exists {
            return Ok(AuthorizedSaleCreateResult::SignatureNotFound);
        }

        let signature_for_shop: bool = row.get("signature_for_shop");
        if !signature_for_shop {
            return Ok(AuthorizedSaleCreateResult::ShopMismatch);
        }

        let sale_json: Option<serde_json::Value> = row.try_get("sale_json").ok();
        let Some(sale_json) = sale_json else {
            return Err(sqlx::Error::Protocol(
                "sale create returned no row despite valid auth/signature".into(),
            ));
        };

        let sale = serde_json::from_value::<Sale>(sale_json)
            .map_err(|e| sqlx::Error::Protocol(format!("invalid sale json: {}", e).into()))?;
        Ok(AuthorizedSaleCreateResult::Created(sale))
    }

    pub async fn update(pool: &PgPool, payload: &SaleUpdatePayload) -> Result<Sale, sqlx::Error> {
        let mut tx: Transaction<'_, Postgres> = pool.begin().await?;

        let sale_row = sqlx::query(
            "SELECT id, shop_id, signature_id, status, customer_name, customer_contact,
                    subtotal, discount_amount, vat_amount, service_fee_amount,
                    delivery_fee_amount, rounding_amount, other_amount, other_label,
                    total, created_at::text as created_at, created_at::date AS created_day
             FROM sales
             WHERE id = $1
             FOR UPDATE",
        )
        .bind(&payload.sale_id)
        .fetch_one(&mut *tx)
        .await?;

        let shop_id: i64 = sale_row.get("shop_id");
        let created_day: NaiveDate = sale_row.get("created_day");
        let old_total: f64 = sale_row.get("total");
        let old_status = SaleStatus::from_db(&sale_row.get::<String, _>("status"));

        let mut items_result: Vec<SaleItem> = Vec::new();
        let mut product_delta_map: HashMap<String, f64> = HashMap::new();
        let mut old_quantities_by_product: HashMap<String, f64> = HashMap::new();
        let subtotal = if let Some(items) = &payload.input.items {
            let old_item_rows = sqlx::query(
                "SELECT product_name, SUM(quantity)::float8 AS quantity
                 FROM sale_items
                 WHERE sale_id = $1
                 GROUP BY product_name",
            )
            .bind(payload.sale_id)
            .fetch_all(&mut *tx)
            .await?;

            let subtotal: f64 = items.iter().map(|i| i.quantity * i.unit_price).sum();

            sqlx::query("DELETE FROM sale_items WHERE sale_id = $1")
                .bind(payload.sale_id)
                .execute(&mut *tx)
                .await?;

            let product_names: Vec<String> = items.iter().map(|i| i.product_name.clone()).collect();
            let quantities: Vec<f64> = items.iter().map(|i| i.quantity).collect();
            let unit_prices: Vec<f64> = items.iter().map(|i| i.unit_price).collect();
            let line_totals: Vec<f64> = items.iter().map(|i| i.quantity * i.unit_price).collect();

            let item_rows = sqlx::query(
                "WITH input AS (
                   SELECT * FROM unnest(
                     $2::text[],
                     $3::float8[],
                     $4::float8[],
                     $5::float8[]
                   ) WITH ORDINALITY AS i(product_name, quantity, unit_price, line_total, ord)
                 )
                 INSERT INTO sale_items (sale_id, product_name, quantity, unit_price, line_total)
                 SELECT $1, product_name, quantity, unit_price, line_total
                 FROM input
                 ORDER BY ord
                 RETURNING id, sale_id, product_name, quantity, unit_price, line_total",
            )
            .bind(payload.sale_id)
            .bind(&product_names)
            .bind(&quantities)
            .bind(&unit_prices)
            .bind(&line_totals)
            .fetch_all(&mut *tx)
            .await?;

            items_result = item_rows
                .into_iter()
                .map(|row| SaleItem {
                    id: row.get("id"),
                    sale_id: row.get("sale_id"),
                    product_name: row.get("product_name"),
                    quantity: row.get("quantity"),
                    unit_price: row.get("unit_price"),
                    line_total: row.get("line_total"),
                })
                .collect();

            for row in old_item_rows {
                let product_name: String = row.get("product_name");
                let quantity: f64 = row.get("quantity");
                old_quantities_by_product.insert(product_name.clone(), quantity);
                *product_delta_map.entry(product_name).or_insert(0.0) -= quantity;
            }
            for item in items {
                *product_delta_map
                    .entry(item.product_name.clone())
                    .or_insert(0.0) += item.quantity;
            }

            subtotal
        } else {
            sale_row.get::<f64, _>("subtotal")
        };

        let discount_amount = payload
            .input
            .discount_amount
            .unwrap_or_else(|| sale_row.get("discount_amount"));
        let vat_amount = payload
            .input
            .vat_amount
            .unwrap_or_else(|| sale_row.get("vat_amount"));
        let service_fee_amount = payload
            .input
            .service_fee_amount
            .unwrap_or_else(|| sale_row.get("service_fee_amount"));
        let delivery_fee_amount = payload
            .input
            .delivery_fee_amount
            .unwrap_or_else(|| sale_row.get("delivery_fee_amount"));
        let rounding_amount = payload
            .input
            .rounding_amount
            .unwrap_or_else(|| sale_row.get("rounding_amount"));
        let other_amount = payload
            .input
            .other_amount
            .unwrap_or_else(|| sale_row.get("other_amount"));
        let other_label = payload
            .input
            .other_label
            .clone()
            .unwrap_or_else(|| sale_row.get("other_label"));
        let status = payload.input.status.unwrap_or(old_status);
        let total = subtotal - discount_amount
            + vat_amount
            + service_fee_amount
            + delivery_fee_amount
            + rounding_amount
            + other_amount;

        if old_quantities_by_product.is_empty() && old_status != status {
            let old_item_rows = sqlx::query(
                "SELECT product_name, SUM(quantity)::float8 AS quantity
                 FROM sale_items
                 WHERE sale_id = $1
                 GROUP BY product_name",
            )
            .bind(payload.sale_id)
            .fetch_all(&mut *tx)
            .await?;
            for row in old_item_rows {
                old_quantities_by_product.insert(row.get("product_name"), row.get("quantity"));
            }
        }

        sqlx::query(
            "UPDATE sales SET
                signature_id = COALESCE($1, signature_id),
                customer_name = COALESCE($2, customer_name),
                customer_contact = COALESCE($3, customer_contact),
                subtotal = $4,
                discount_amount = $5,
                vat_amount = $6,
                service_fee_amount = $7,
                delivery_fee_amount = $8,
                rounding_amount = $9,
                other_amount = $10,
                other_label = $11,
                total = $12,
                status = $13
             WHERE id = $14",
        )
        .bind(&payload.input.signature_id)
        .bind(&payload.input.customer_name)
        .bind(&payload.input.customer_contact)
        .bind(subtotal)
        .bind(discount_amount)
        .bind(vat_amount)
        .bind(service_fee_amount)
        .bind(delivery_fee_amount)
        .bind(rounding_amount)
        .bind(other_amount)
        .bind(&other_label)
        .bind(total)
        .bind(status.as_str())
        .bind(payload.sale_id)
        .execute(&mut *tx)
        .await?;

        let total_delta = match (old_status.is_paid(), status.is_paid()) {
            (true, true) => total - old_total,
            (false, true) => total,
            (true, false) => -old_total,
            (false, false) => 0.0,
        };
        if total_delta != 0.0 {
            Self::upsert_shop_sales_daily(&mut tx, shop_id, created_day, total_delta, 0).await?;
        }
        match (old_status.is_paid(), status.is_paid()) {
            (false, false) => {
                product_delta_map.clear();
            }
            (false, true) => {
                product_delta_map.clear();
                if let Some(items) = &payload.input.items {
                    for item in items {
                        *product_delta_map
                            .entry(item.product_name.clone())
                            .or_insert(0.0) += item.quantity;
                    }
                } else {
                    for (name, qty) in &old_quantities_by_product {
                        *product_delta_map.entry(name.clone()).or_insert(0.0) += *qty;
                    }
                }
            }
            (true, false) => {
                product_delta_map.clear();
                for (name, qty) in &old_quantities_by_product {
                    *product_delta_map.entry(name.clone()).or_insert(0.0) -= *qty;
                }
            }
            (true, true) => {}
        }
        if !product_delta_map.is_empty() {
            Self::upsert_shop_product_daily_batch(
                &mut tx,
                shop_id,
                created_day,
                &product_delta_map,
            )
            .await?;
        }

        tx.commit().await?;

        let items = if items_result.is_empty() {
            Self::load_items(pool, payload.sale_id).await?
        } else {
            items_result
        };

        Ok(Sale {
            id: payload.sale_id,
            shop_id,
            signature_id: payload
                .input
                .signature_id
                .unwrap_or_else(|| sale_row.get::<i64, _>("signature_id")),
            status,
            customer_name: payload
                .input
                .customer_name
                .clone()
                .or_else(|| sale_row.get::<Option<String>, _>("customer_name")),
            customer_contact: payload
                .input
                .customer_contact
                .clone()
                .or_else(|| sale_row.get::<Option<String>, _>("customer_contact")),
            subtotal,
            discount_amount,
            vat_amount,
            service_fee_amount,
            delivery_fee_amount,
            rounding_amount,
            other_amount,
            other_label,
            total,
            created_at: sale_row.get("created_at"),
            items,
        })
    }

    pub async fn delete(pool: &PgPool, payload: &IdPayload) -> Result<(), sqlx::Error> {
        let mut tx: Transaction<'_, Postgres> = pool.begin().await?;

        let sale_row = sqlx::query(
            "SELECT shop_id, status, total, customer_name, created_at::date as created_day
             FROM sales
             WHERE id = $1",
        )
        .bind(payload.id)
        .fetch_optional(&mut *tx)
        .await?;

        let (shop_id, status, sale_total, has_customer, created_day) = match sale_row {
            Some(row) => {
                let customer_name: Option<String> = row.get("customer_name");
                let has_customer = customer_name
                    .as_ref()
                    .map(|v| !v.trim().is_empty())
                    .unwrap_or(false);
                (
                    row.get::<i64, _>("shop_id"),
                    SaleStatus::from_db(&row.get::<String, _>("status")),
                    row.get::<f64, _>("total"),
                    has_customer,
                    row.get::<NaiveDate, _>("created_day"),
                )
            }
            None => {
                tx.commit().await?;
                return Ok(());
            }
        };

        let sale_items_rows = sqlx::query(
            "SELECT product_name, SUM(quantity)::float8 AS quantity
             FROM sale_items
             WHERE sale_id = $1
             GROUP BY product_name",
        )
        .bind(payload.id)
        .fetch_all(&mut *tx)
        .await?;

        if status.is_paid() {
            let customer_delta = if has_customer { 1 } else { 0 };
            sqlx::query(
                "UPDATE shops
                 SET total_revenue = GREATEST(0, total_revenue - $1),
                     total_orders = GREATEST(0, total_orders - 1),
                     total_customers = GREATEST(0, total_customers - $2)
                 WHERE id = $3",
            )
            .bind(sale_total)
            .bind(customer_delta)
            .bind(shop_id)
            .execute(&mut *tx)
            .await?;

            Self::upsert_shop_sales_daily(&mut tx, shop_id, created_day, -sale_total, -1).await?;

            let mut product_delta_map: HashMap<String, f64> = HashMap::new();
            for item_row in &sale_items_rows {
                let product_name: String = item_row.get("product_name");
                let quantity: f64 = item_row.get("quantity");
                *product_delta_map.entry(product_name).or_insert(0.0) -= quantity;
            }
            Self::upsert_shop_product_daily_batch(
                &mut tx,
                shop_id,
                created_day,
                &product_delta_map,
            )
            .await?;
        }

        sqlx::query("DELETE FROM sale_items WHERE sale_id = $1")
            .bind(payload.id)
            .execute(&mut *tx)
            .await?;

        sqlx::query("DELETE FROM sales WHERE id = $1")
            .bind(payload.id)
            .execute(&mut *tx)
            .await?;

        tx.commit().await?;

        Ok(())
    }

    pub async fn load_with_items(
        pool: &PgPool,
        payload: &IdPayload,
    ) -> Result<Option<Sale>, sqlx::Error> {
        let sale_row = sqlx::query(
            "SELECT id, shop_id, signature_id, status, customer_name, customer_contact,
                    subtotal, discount_amount, vat_amount, service_fee_amount,
                    delivery_fee_amount, rounding_amount, other_amount, other_label,
                    total, created_at::text as created_at
             FROM sales
             WHERE id = $1",
        )
        .bind(payload.id)
        .fetch_optional(pool)
        .await?;

        let sale_row = match sale_row {
            Some(row) => row,
            None => return Ok(None),
        };

        let items = Self::load_items(pool, payload.id).await?;

        Ok(Some(Sale {
            id: sale_row.get("id"),
            shop_id: sale_row.get("shop_id"),
            signature_id: sale_row.get("signature_id"),
            status: SaleStatus::from_db(&sale_row.get::<String, _>("status")),
            customer_name: sale_row.get("customer_name"),
            customer_contact: sale_row.get("customer_contact"),
            subtotal: sale_row.get("subtotal"),
            discount_amount: sale_row.get("discount_amount"),
            vat_amount: sale_row.get("vat_amount"),
            service_fee_amount: sale_row.get("service_fee_amount"),
            delivery_fee_amount: sale_row.get("delivery_fee_amount"),
            rounding_amount: sale_row.get("rounding_amount"),
            other_amount: sale_row.get("other_amount"),
            other_label: sale_row.get("other_label"),
            total: sale_row.get("total"),
            created_at: sale_row.get("created_at"),
            items,
        }))
    }

    async fn load_items(pool: &PgPool, sale_id: i64) -> Result<Vec<SaleItem>, sqlx::Error> {
        let items_rows = sqlx::query(
            "SELECT id, sale_id, product_name, quantity, unit_price, line_total
             FROM sale_items WHERE sale_id = $1",
        )
        .bind(sale_id)
        .fetch_all(pool)
        .await?;

        Ok(items_rows
            .into_iter()
            .map(|item| SaleItem {
                id: item.get("id"),
                sale_id: item.get("sale_id"),
                product_name: item.get("product_name"),
                quantity: item.get("quantity"),
                unit_price: item.get("unit_price"),
                line_total: item.get("line_total"),
            })
            .collect())
    }
}
