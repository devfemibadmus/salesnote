use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::{Postgres, Row, Transaction, PgPool};

use crate::models::{IdPayload, Sale, ShopProfile, Signature};

#[derive(Debug, Deserialize, Clone)]
pub struct ReceiptCreateInput {
    pub sale_id: i64,
    pub signature_id: i64,
    pub customer_name: String,
    pub customer_email: String,
    pub customer_phone: String,
}

#[derive(Debug, Serialize, Clone)]
pub struct Receipt {
    pub id: i64,
    pub sale_id: i64,
    pub shop_id: i64,
    pub signature_id: i64,
    pub customer_name: String,
    pub customer_email: String,
    pub customer_phone: String,
    pub created_at: String,
}

#[derive(Debug, Serialize)]
pub struct ReceiptDetail {
    pub receipt: Receipt,
    pub shop: ShopProfile,
    pub sale: Sale,
    pub signature: Option<Signature>,
}

#[derive(Debug, Clone)]
pub struct ReceiptInsertPayload {
    pub shop_id: i64,
    pub input: ReceiptCreateInput,
}


impl Receipt {
    pub async fn set_created_at(
        pool: &PgPool,
        payload: &IdPayload,
        created_at: DateTime<Utc>,
    ) -> Result<(), sqlx::Error> {
        sqlx::query("UPDATE receipts SET created_at = $1 WHERE id = $2")
            .bind(created_at)
            .bind(payload.id)
            .execute(pool)
            .await?;

        Ok(())
    }

    pub async fn insert(
        pool: &PgPool,
        payload: &ReceiptInsertPayload,
    ) -> Result<Receipt, sqlx::Error> {
        let mut tx: Transaction<'_, Postgres> = pool.begin().await?;

        let sale_row = sqlx::query(
            "SELECT total, customer_name
             FROM sales
             WHERE id = $1 AND shop_id = $2",
        )
        .bind(payload.input.sale_id)
        .bind(payload.shop_id)
        .fetch_one(&mut *tx)
        .await?;

        let sale_total: f64 = sale_row.get("total");
        let customer_name: Option<String> = sale_row.get("customer_name");
        let has_customer = customer_name
            .as_ref()
            .map(|v| !v.trim().is_empty())
            .unwrap_or(false);
        let customer_increment: i64 = if has_customer { 1 } else { 0 };

        let row = sqlx::query(
            "INSERT INTO receipts (shop_id, sale_id, signature_id, customer_name, customer_email, customer_phone)
             VALUES ($1, $2, $3, $4, $5, $6)
             RETURNING id, created_at::text as created_at",
        )
        .bind(payload.shop_id)
        .bind(payload.input.sale_id)
        .bind(payload.input.signature_id)
        .bind(&payload.input.customer_name)
        .bind(&payload.input.customer_email)
        .bind(&payload.input.customer_phone)
        .fetch_one(&mut *tx)
        .await?;

        sqlx::query(
            "UPDATE shops
             SET total_revenue = total_revenue + $1,
                 total_orders = total_orders + 1,
                 total_customers = total_customers + $2
             WHERE id = $3",
        )
        .bind(sale_total)
        .bind(customer_increment)
        .bind(payload.shop_id)
        .execute(&mut *tx)
        .await?;

        let sale_items = sqlx::query(
            "SELECT product_name, quantity
             FROM sale_items
             WHERE sale_id = $1",
        )
        .bind(payload.input.sale_id)
        .fetch_all(&mut *tx)
        .await?;

        for item in sale_items {
            let product_name: String = item.get("product_name");
            let quantity: f64 = item.get("quantity");
            sqlx::query(
                "INSERT INTO shop_product_daily (shop_id, product_name, day, quantity)
                 VALUES ($1, $2, CURRENT_DATE, $3)
                 ON CONFLICT (shop_id, product_name, day)
                 DO UPDATE
                 SET quantity = shop_product_daily.quantity + EXCLUDED.quantity,
                     updated_at = NOW()",
            )
            .bind(payload.shop_id)
            .bind(product_name)
            .bind(quantity)
            .execute(&mut *tx)
            .await?;
        }

        tx.commit().await?;

        let receipt_id = row.get::<i64, _>("id");
        let created_at = row.get::<String, _>("created_at");

        Ok(Receipt {
            id: receipt_id,
            sale_id: payload.input.sale_id,
            shop_id: payload.shop_id,
            signature_id: payload.input.signature_id,
            customer_name: payload.input.customer_name.clone(),
            customer_email: payload.input.customer_email.clone(),
            customer_phone: payload.input.customer_phone.clone(),
            created_at,
        })
    }

    pub async fn list(
        pool: &PgPool,
        payload: &IdPayload,
    ) -> Result<Vec<Receipt>, sqlx::Error> {
        let rows = sqlx::query(
            "SELECT id, shop_id, sale_id, signature_id,
                    customer_name, customer_email, customer_phone,
                    created_at::text as created_at
             FROM receipts WHERE shop_id = $1 ORDER BY created_at DESC",
        )
        .bind(&payload.id)
        .fetch_all(pool)
        .await?;

        Ok(rows.into_iter().map(Receipt::from_row).collect())
    }

    pub async fn find(
        pool: &PgPool,
        payload: &IdPayload,
    ) -> Result<Option<Receipt>, sqlx::Error> {
        let row = sqlx::query(
            "SELECT id, shop_id, sale_id, signature_id,
                    customer_name, customer_email, customer_phone,
                    created_at::text as created_at
             FROM receipts WHERE id = $1",
        )
        .bind(&payload.id)
        .fetch_optional(pool)
        .await?;

        Ok(row.map(Receipt::from_row))
    }

    fn from_row(row: sqlx::postgres::PgRow) -> Receipt {
        Receipt {
            id: row.get("id"),
            shop_id: row.get("shop_id"),
            sale_id: row.get("sale_id"),
            signature_id: row.get("signature_id"),
            customer_name: row.get("customer_name"),
            customer_email: row.get("customer_email"),
            customer_phone: row.get("customer_phone"),
            created_at: row.get("created_at"),
        }
    }
}
