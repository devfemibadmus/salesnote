use chrono::{DateTime, Utc};
use sqlx::{PgPool, Row};

use crate::worker::progress::message::TopItem;

#[derive(Debug)]
pub struct ShopToken {
    pub id: i64,
    pub fcm_token: String,
    pub timezone: String,
}

pub async fn fetch_shops_with_tokens(pool: &PgPool) -> Result<Vec<ShopToken>, sqlx::Error> {
    let rows = sqlx::query(
        "SELECT DISTINCT ds.shop_id as id, ds.fcm_token, s.timezone
         FROM device_sessions ds
         JOIN shops s ON s.id = ds.shop_id
         WHERE ds.deleted_at IS NULL
           AND ds.fcm_token IS NOT NULL
           AND ds.fcm_token <> ''
         ORDER BY ds.shop_id ASC",
    )
    .fetch_all(pool)
    .await?;

    Ok(rows
        .into_iter()
        .map(|row| ShopToken {
            id: row.get("id"),
            fcm_token: row.get("fcm_token"),
            timezone: row.get("timezone"),
        })
        .collect())
}

pub async fn already_sent_today(
    pool: &PgPool,
    shop_id: i64,
    kind: &str,
    day: &str,
) -> Result<bool, sqlx::Error> {
    let row = sqlx::query(
        "SELECT COUNT(*) as cnt FROM notification_logs WHERE shop_id = $1 AND kind = $2 AND day = $3",
    )
    .bind(shop_id)
    .bind(kind)
    .bind(day)
    .fetch_one(pool)
    .await?;

    Ok(row.get::<i64, _>("cnt") > 0)
}

pub async fn mark_sent(
    pool: &PgPool,
    shop_id: i64,
    kind: &str,
    day: &str,
) -> Result<(), sqlx::Error> {
    sqlx::query("INSERT INTO notification_logs (shop_id, kind, day) VALUES ($1, $2, $3)")
        .bind(shop_id)
        .bind(kind)
        .bind(day)
        .execute(pool)
        .await?;
    Ok(())
}

pub async fn count_sales_between(
    pool: &PgPool,
    shop_id: i64,
    start_dt: DateTime<Utc>,
    end_dt: DateTime<Utc>,
) -> Result<i64, String> {
    let row = sqlx::query(
        "SELECT COUNT(*) as cnt FROM sales WHERE shop_id = $1 AND created_at >= $2 AND created_at < $3",
    )
    .bind(shop_id)
    .bind(start_dt)
    .bind(end_dt)
    .fetch_one(pool)
    .await
    .map_err(|e| e.to_string())?;

    Ok(row.get::<i64, _>("cnt"))
}

pub async fn top_item_between(
    pool: &PgPool,
    shop_id: i64,
    start_dt: DateTime<Utc>,
    end_dt: DateTime<Utc>,
) -> Result<Option<TopItem>, String> {
    let row = sqlx::query(
        "SELECT si.product_name as name, SUM(si.quantity) as qty
         FROM sale_items si
         JOIN sales s ON s.id = si.sale_id
         WHERE s.shop_id = $1 AND s.created_at >= $2 AND s.created_at < $3
         GROUP BY si.product_name
         ORDER BY qty DESC
         LIMIT 1",
    )
    .bind(shop_id)
    .bind(start_dt)
    .bind(end_dt)
    .fetch_optional(pool)
    .await
    .map_err(|e| e.to_string())?;

    Ok(row.map(|row| TopItem {
        name: row.get("name"),
        quantity: row.get::<f64, _>("qty"),
    }))
}
