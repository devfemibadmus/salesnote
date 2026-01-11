use serde::{Deserialize, Serialize};
use sqlx::Row;
use std::collections::HashMap;

use crate::models::{Sale, ShopProfile};

use crate::models::IdPayload;

#[derive(Debug, Serialize, Deserialize)]
pub struct AnalyticsSummary {
    pub daily: Vec<TimeSeriesPoint>,
    pub weekly: Vec<TimeSeriesPoint>,
    pub monthly: Vec<TimeSeriesPoint>,
    pub fast_moving: Vec<ProductMovement>,
    pub slow_moving: Vec<ProductMovement>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TimeSeriesPoint {
    pub period: String,
    pub total: f64,
    pub units: f64,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ProductMovement {
    pub product_name: String,
    pub quantity: f64,
    pub sold_30_days: f64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct HomeSummaryData {
    pub shop: ShopProfile,
    pub analytics: AnalyticsSummary,
    pub recent_sales: Vec<Sale>,
}

impl AnalyticsSummary {
    pub async fn authorized_home_summary(
        pool: &sqlx::PgPool,
        shop_id: i64,
        device_id: i64,
    ) -> Result<Option<HomeSummaryData>, sqlx::Error> {
        let row = sqlx::query(
            "
            WITH auth_active AS (
              SELECT id
              FROM device_sessions
              WHERE id = $2
                AND shop_id = $1
                AND deleted_at IS NULL
            ),
            auth_touch AS (
              UPDATE device_sessions
              SET last_seen_at = NOW()
              WHERE id IN (SELECT id FROM auth_active)
                AND (
                  last_seen_at IS NULL
                  OR last_seen_at < NOW() - ('5 minutes')::interval
                )
              RETURNING id
            ),
            shop_row AS (
              SELECT
                id, name, phone, email, address, logo_url,
                total_revenue, total_orders, total_customers, timezone,
                created_at::text AS created_at
              FROM shops
              WHERE id = $1
                AND EXISTS (SELECT 1 FROM auth_active)
            ),
            tz_data AS (
              SELECT
                COALESCE(NULLIF(timezone, ''), 'UTC') AS tz,
                (NOW() AT TIME ZONE COALESCE(NULLIF(timezone, ''), 'UTC'))::date AS local_today
              FROM shops
              WHERE id = $1
              LIMIT 1
            ),
            daily_labels AS (
              SELECT gs::date AS day
              FROM tz_data t
              CROSS JOIN generate_series(
                t.local_today - interval '29 days',
                t.local_today,
                interval '1 day'
              ) gs
            ),
            daily_sales AS (
              SELECT
                TO_CHAR(l.day::timestamp, 'YYYY-MM-DD') AS period,
                COALESCE(SUM(s.total)::float8, 0.0) AS total
              FROM daily_labels l
              LEFT JOIN shop_sales_daily s
                ON s.shop_id = $1
               AND s.day = l.day
              GROUP BY l.day
            ),
            daily_units AS (
              SELECT
                TO_CHAR(l.day::timestamp, 'YYYY-MM-DD') AS period,
                COALESCE(SUM(p.quantity)::float8, 0.0) AS units
              FROM daily_labels l
              LEFT JOIN shop_product_daily p
                ON p.shop_id = $1
               AND p.day = l.day
              GROUP BY l.day
            ),
            weekly_labels AS (
              SELECT gs::date AS week_start
              FROM tz_data t
              CROSS JOIN generate_series(
                date_trunc('week', t.local_today::timestamp)::date - interval '11 weeks',
                date_trunc('week', t.local_today::timestamp)::date,
                interval '1 week'
              ) gs
            ),
            weekly_sales AS (
              SELECT
                TO_CHAR(l.week_start::timestamp, 'IYYY-IW') AS period,
                COALESCE(SUM(s.total)::float8, 0.0) AS total
              FROM weekly_labels l
              LEFT JOIN shop_sales_daily s
                ON s.shop_id = $1
               AND date_trunc('week', s.day::timestamp)::date = l.week_start
              GROUP BY l.week_start
            ),
            weekly_units AS (
              SELECT
                TO_CHAR(l.week_start::timestamp, 'IYYY-IW') AS period,
                COALESCE(SUM(p.quantity)::float8, 0.0) AS units
              FROM weekly_labels l
              LEFT JOIN shop_product_daily p
                ON p.shop_id = $1
               AND date_trunc('week', p.day::timestamp)::date = l.week_start
              GROUP BY l.week_start
            ),
            monthly_labels AS (
              SELECT gs::date AS month_start
              FROM tz_data t
              CROSS JOIN generate_series(
                date_trunc('month', t.local_today::timestamp)::date - interval '11 months',
                date_trunc('month', t.local_today::timestamp)::date,
                interval '1 month'
              ) gs
            ),
            monthly_sales AS (
              SELECT
                TO_CHAR(l.month_start::timestamp, 'YYYY-MM') AS period,
                COALESCE(SUM(s.total)::float8, 0.0) AS total
              FROM monthly_labels l
              LEFT JOIN shop_sales_daily s
                ON s.shop_id = $1
               AND date_trunc('month', s.day::timestamp)::date = l.month_start
              GROUP BY l.month_start
            ),
            monthly_units AS (
              SELECT
                TO_CHAR(l.month_start::timestamp, 'YYYY-MM') AS period,
                COALESCE(SUM(p.quantity)::float8, 0.0) AS units
              FROM monthly_labels l
              LEFT JOIN shop_product_daily p
                ON p.shop_id = $1
               AND date_trunc('month', p.day::timestamp)::date = l.month_start
              GROUP BY l.month_start
            ),
            movement AS (
              SELECT product_name, SUM(quantity)::float8 AS qty
              FROM shop_product_daily
              WHERE shop_id = $1
                AND day >= ((SELECT local_today FROM tz_data) - INTERVAL '29 days')
              GROUP BY product_name
              ORDER BY qty DESC
              LIMIT 100
            ),
            recent_sales AS (
              SELECT
                id, shop_id, signature_id, customer_name, customer_contact, total,
                created_at::text AS created_at
              FROM sales
              WHERE shop_id = $1
              ORDER BY created_at DESC
              LIMIT 4
            )
            SELECT
              EXISTS(SELECT 1 FROM auth_active) AS is_active,
              (
                SELECT row_to_json(shop_row)
                FROM shop_row
              ) AS shop_json,
              (
                SELECT COALESCE(json_agg(
                  json_build_object(
                    'period', s.period,
                    'total', s.total,
                    'units', COALESCE(u.units, 0.0)
                  ) ORDER BY s.period DESC
                ), '[]'::json)
                FROM daily_sales s
                LEFT JOIN daily_units u ON u.period = s.period
              ) AS daily_json,
              (
                SELECT COALESCE(json_agg(
                  json_build_object(
                    'period', s.period,
                    'total', s.total,
                    'units', COALESCE(u.units, 0.0)
                  ) ORDER BY s.period DESC
                ), '[]'::json)
                FROM weekly_sales s
                LEFT JOIN weekly_units u ON u.period = s.period
              ) AS weekly_json,
              (
                SELECT COALESCE(json_agg(
                  json_build_object(
                    'period', s.period,
                    'total', s.total,
                    'units', COALESCE(u.units, 0.0)
                  ) ORDER BY s.period DESC
                ), '[]'::json)
                FROM monthly_sales s
                LEFT JOIN monthly_units u ON u.period = s.period
              ) AS monthly_json,
              (
                SELECT COALESCE(json_agg(
                  json_build_object(
                    'product_name', m.product_name,
                    'quantity', m.qty,
                    'sold_30_days', m.qty
                  ) ORDER BY m.qty DESC
                ), '[]'::json)
                FROM (
                  SELECT product_name, qty
                  FROM movement
                  ORDER BY qty DESC
                  LIMIT 5
                ) m
              ) AS fast_json,
              (
                SELECT COALESCE(json_agg(
                  json_build_object(
                    'product_name', m.product_name,
                    'quantity', m.qty,
                    'sold_30_days', m.qty
                  ) ORDER BY m.qty ASC
                ), '[]'::json)
                FROM (
                  SELECT product_name, qty
                  FROM movement
                  ORDER BY qty ASC
                  LIMIT 5
                ) m
              ) AS slow_json,
              (
                SELECT COALESCE(json_agg(
                  json_build_object(
                    'id', s.id,
                    'shop_id', s.shop_id,
                    'signature_id', s.signature_id,
                    'customer_name', s.customer_name,
                    'customer_contact', s.customer_contact,
                    'total', s.total,
                    'created_at', s.created_at,
                    'items', '[]'::json
                  ) ORDER BY s.created_at DESC
                ), '[]'::json)
                FROM recent_sales s
              ) AS recent_sales_json
            ",
        )
        .bind(shop_id)
        .bind(device_id)
        .fetch_one(pool)
        .await?;

        let is_active: bool = row.get("is_active");
        if !is_active {
            return Ok(None);
        }

        let shop_json: Option<serde_json::Value> = row.get("shop_json");
        let Some(shop_json) = shop_json else {
            return Ok(None);
        };
        let daily_json: serde_json::Value = row.get("daily_json");
        let weekly_json: serde_json::Value = row.get("weekly_json");
        let monthly_json: serde_json::Value = row.get("monthly_json");
        let fast_json: serde_json::Value = row.get("fast_json");
        let slow_json: serde_json::Value = row.get("slow_json");
        let recent_sales_json: serde_json::Value = row.get("recent_sales_json");

        let shop: ShopProfile = serde_json::from_value(shop_json)
            .map_err(|e| sqlx::Error::Protocol(format!("invalid home shop json: {}", e).into()))?;
        let analytics: AnalyticsSummary = serde_json::from_value(serde_json::json!({
            "daily": daily_json,
            "weekly": weekly_json,
            "monthly": monthly_json,
            "fast_moving": fast_json,
            "slow_moving": slow_json
        }))
        .map_err(|e| sqlx::Error::Protocol(format!("invalid home analytics json: {}", e).into()))?;
        let recent_sales: Vec<Sale> = serde_json::from_value(recent_sales_json)
            .map_err(|e| sqlx::Error::Protocol(format!("invalid home recent sales json: {}", e).into()))?;

        Ok(Some(HomeSummaryData {
            shop,
            analytics,
            recent_sales,
        }))
    }

    pub async fn authorized_summary(
        pool: &sqlx::PgPool,
        shop_id: i64,
        device_id: i64,
    ) -> Result<Option<AnalyticsSummary>, sqlx::Error> {
        let sql = r#"
        WITH auth_active AS (
          SELECT id
          FROM device_sessions
          WHERE id = $2
            AND shop_id = $1
            AND deleted_at IS NULL
        ),
        auth_touch AS (
          UPDATE device_sessions
          SET last_seen_at = NOW()
          WHERE id IN (SELECT id FROM auth_active)
            AND (
              last_seen_at IS NULL
              OR last_seen_at < NOW() - ('5 minutes')::interval
            )
          RETURNING id
        ),
        tz_data AS (
          SELECT
            COALESCE(NULLIF(timezone, ''), 'UTC') AS tz,
            (NOW() AT TIME ZONE COALESCE(NULLIF(timezone, ''), 'UTC'))::date AS local_today
          FROM shops
          WHERE id = $1
          LIMIT 1
        ),
        daily_labels AS (
          SELECT gs::date AS day
          FROM tz_data t
          CROSS JOIN generate_series(
            t.local_today - interval '29 days',
            t.local_today,
            interval '1 day'
          ) gs
        ),
        daily_sales AS (
          SELECT
            TO_CHAR(l.day::timestamp, 'YYYY-MM-DD') AS period,
            COALESCE(SUM(s.total)::float8, 0.0) AS total
          FROM daily_labels l
          LEFT JOIN shop_sales_daily s
            ON s.shop_id = $1
           AND s.day = l.day
          GROUP BY l.day
        ),
        daily_units AS (
          SELECT
            TO_CHAR(l.day::timestamp, 'YYYY-MM-DD') AS period,
            COALESCE(SUM(p.quantity)::float8, 0.0) AS units
          FROM daily_labels l
          LEFT JOIN shop_product_daily p
            ON p.shop_id = $1
           AND p.day = l.day
          GROUP BY l.day
        ),
        weekly_labels AS (
          SELECT gs::date AS week_start
          FROM tz_data t
          CROSS JOIN generate_series(
            date_trunc('week', t.local_today::timestamp)::date - interval '11 weeks',
            date_trunc('week', t.local_today::timestamp)::date,
            interval '1 week'
          ) gs
        ),
        weekly_sales AS (
          SELECT
            TO_CHAR(l.week_start::timestamp, 'IYYY-IW') AS period,
            COALESCE(SUM(s.total)::float8, 0.0) AS total
          FROM weekly_labels l
          LEFT JOIN shop_sales_daily s
            ON s.shop_id = $1
           AND date_trunc('week', s.day::timestamp)::date = l.week_start
          GROUP BY l.week_start
        ),
        weekly_units AS (
          SELECT
            TO_CHAR(l.week_start::timestamp, 'IYYY-IW') AS period,
            COALESCE(SUM(p.quantity)::float8, 0.0) AS units
          FROM weekly_labels l
          LEFT JOIN shop_product_daily p
            ON p.shop_id = $1
           AND date_trunc('week', p.day::timestamp)::date = l.week_start
          GROUP BY l.week_start
        ),
        monthly_labels AS (
          SELECT gs::date AS month_start
          FROM tz_data t
          CROSS JOIN generate_series(
            date_trunc('month', t.local_today::timestamp)::date - interval '11 months',
            date_trunc('month', t.local_today::timestamp)::date,
            interval '1 month'
          ) gs
        ),
        monthly_sales AS (
          SELECT
            TO_CHAR(l.month_start::timestamp, 'YYYY-MM') AS period,
            COALESCE(SUM(s.total)::float8, 0.0) AS total
          FROM monthly_labels l
          LEFT JOIN shop_sales_daily s
            ON s.shop_id = $1
           AND date_trunc('month', s.day::timestamp)::date = l.month_start
          GROUP BY l.month_start
        ),
        monthly_units AS (
          SELECT
            TO_CHAR(l.month_start::timestamp, 'YYYY-MM') AS period,
            COALESCE(SUM(p.quantity)::float8, 0.0) AS units
          FROM monthly_labels l
          LEFT JOIN shop_product_daily p
            ON p.shop_id = $1
           AND date_trunc('month', p.day::timestamp)::date = l.month_start
          GROUP BY l.month_start
        ),
        movement AS (
          SELECT product_name, SUM(quantity)::float8 AS qty
          FROM shop_product_daily
          WHERE shop_id = $1
            AND day >= ((SELECT local_today FROM tz_data) - INTERVAL '29 days')
          GROUP BY product_name
          ORDER BY qty DESC
          LIMIT 100
        )
        SELECT
          EXISTS(SELECT 1 FROM auth_active) AS is_active,
          (
            SELECT COALESCE(json_agg(
              json_build_object(
                'period', s.period,
                'total', s.total,
                'units', COALESCE(u.units, 0.0)
              ) ORDER BY s.period DESC
            ), '[]'::json)
            FROM daily_sales s
            LEFT JOIN daily_units u ON u.period = s.period
          ) AS daily_json,
          (
            SELECT COALESCE(json_agg(
              json_build_object(
                'period', s.period,
                'total', s.total,
                'units', COALESCE(u.units, 0.0)
              ) ORDER BY s.period DESC
            ), '[]'::json)
            FROM weekly_sales s
            LEFT JOIN weekly_units u ON u.period = s.period
          ) AS weekly_json,
          (
            SELECT COALESCE(json_agg(
              json_build_object(
                'period', s.period,
                'total', s.total,
                'units', COALESCE(u.units, 0.0)
              ) ORDER BY s.period DESC
            ), '[]'::json)
            FROM monthly_sales s
            LEFT JOIN monthly_units u ON u.period = s.period
          ) AS monthly_json,
          (
            SELECT COALESCE(json_agg(
              json_build_object(
                'product_name', m.product_name,
                'quantity', m.qty,
                'sold_30_days', m.qty
              ) ORDER BY m.qty DESC
            ), '[]'::json)
            FROM (
              SELECT product_name, qty
              FROM movement
              ORDER BY qty DESC
              LIMIT 5
            ) m
          ) AS fast_json,
          (
            SELECT COALESCE(json_agg(
              json_build_object(
                'product_name', m.product_name,
                'quantity', m.qty,
                'sold_30_days', m.qty
              ) ORDER BY m.qty ASC
            ), '[]'::json)
            FROM (
              SELECT product_name, qty
              FROM movement
              ORDER BY qty ASC
              LIMIT 5
            ) m
          ) AS slow_json
        "#;

        let row = sqlx::query(sql)
            .bind(shop_id)
            .bind(device_id)
            .fetch_one(pool)
            .await?;

        let is_active: bool = row.get("is_active");
        if !is_active {
            return Ok(None);
        }

        let daily_json: serde_json::Value = row.get("daily_json");
        let weekly_json: serde_json::Value = row.get("weekly_json");
        let monthly_json: serde_json::Value = row.get("monthly_json");
        let fast_json: serde_json::Value = row.get("fast_json");
        let slow_json: serde_json::Value = row.get("slow_json");

        let summary: AnalyticsSummary = serde_json::from_value(serde_json::json!({
            "daily": daily_json,
            "weekly": weekly_json,
            "monthly": monthly_json,
            "fast_moving": fast_json,
            "slow_moving": slow_json
        }))
        .map_err(|e| sqlx::Error::Protocol(format!("invalid analytics json: {}", e).into()))?;

        Ok(Some(summary))
    }

    pub async fn build(
        pool: &sqlx::PgPool,
        payload: &IdPayload,
    ) -> Result<AnalyticsSummary, sqlx::Error> {
        let daily = Self::fetch_timeseries(pool, &payload.id, "day", 30).await?;
        let weekly = Self::fetch_timeseries(pool, &payload.id, "week", 12).await?;
        let monthly = Self::fetch_timeseries(pool, &payload.id, "month", 12).await?;
        let (fast_moving, slow_moving) = Self::fetch_movement(pool, &payload.id).await?;

        Ok(AnalyticsSummary {
            daily,
            weekly,
            monthly,
            fast_moving,
            slow_moving,
        })
    }

    async fn fetch_timeseries(
        pool: &sqlx::PgPool,
        shop_id: &i64,
        granularity: &str,
        limit: i64,
    ) -> Result<Vec<TimeSeriesPoint>, sqlx::Error> {
        let (format, range) = match granularity {
            "week" => ("IYYY-IW", "84 days"),
            "month" => ("YYYY-MM", "365 days"),
            _ => ("YYYY-MM-DD", "30 days"),
        };

        let sales_query = format!(
            "SELECT TO_CHAR(day::timestamp, '{format}') as period, SUM(total)::float8 as total
             FROM shop_sales_daily
             WHERE shop_id = $1 AND day >= CURRENT_DATE - interval '{range}'
             GROUP BY period
             ORDER BY period DESC
             LIMIT $2"
        );

        let units_query = format!(
            "SELECT TO_CHAR(day::timestamp, '{format}') as period, SUM(quantity)::float8 as units
             FROM shop_product_daily
             WHERE shop_id = $1 AND day >= CURRENT_DATE - interval '{range}'
             GROUP BY period"
        );

        let sales_rows = sqlx::query(&sales_query)
            .bind(shop_id)
            .bind(limit)
            .fetch_all(pool)
            .await?;

        let units_rows = sqlx::query(&units_query)
            .bind(shop_id)
            .fetch_all(pool)
            .await?;

        let mut units_by_period: HashMap<String, f64> = HashMap::new();
        for row in units_rows {
            let period: String = row.get("period");
            let units: f64 = row.get("units");
            units_by_period.insert(period, units);
        }

        Ok(sales_rows
            .into_iter()
            .map(|row| TimeSeriesPoint {
                period: {
                    let period: String = row.get("period");
                    period
                },
                total: row.get("total"),
                units: {
                    let period: String = row.get("period");
                    *units_by_period.get(&period).unwrap_or(&0.0)
                },
            })
            .collect())
    }

    async fn fetch_movement(
        pool: &sqlx::PgPool,
        shop_id: &i64,
    ) -> Result<(Vec<ProductMovement>, Vec<ProductMovement>), sqlx::Error> {
        let mut rows = sqlx::query(
            "SELECT product_name, SUM(quantity)::float8 AS qty
             FROM shop_product_daily
             WHERE shop_id = $1
               AND day >= (CURRENT_DATE - INTERVAL '29 days')
             GROUP BY product_name
             ORDER BY qty DESC
             LIMIT 100
            ",
        )
        .bind(shop_id)
        .fetch_all(pool)
        .await?;

        // Backward-compatible fallback for shops created before aggregate table population.
        if rows.is_empty() {
            rows = sqlx::query(
                "SELECT si.product_name, SUM(si.quantity)::float8 AS qty
                 FROM sales s
                 INNER JOIN sale_items si ON si.sale_id = s.id
                 WHERE s.shop_id = $1
                   AND s.created_at >= NOW() - interval '30 days'
                 GROUP BY si.product_name
                 ORDER BY qty DESC
                 LIMIT 100",
            )
            .bind(shop_id)
            .fetch_all(pool)
            .await?;
        }

        let mut items: Vec<ProductMovement> = rows
            .into_iter()
            .map(|row| ProductMovement {
                product_name: row.get("product_name"),
                quantity: row.get("qty"),
                sold_30_days: row.get("qty"),
            })
            .collect();

        items.sort_by(|a, b| b.quantity.partial_cmp(&a.quantity).unwrap());
        let fast = items.iter().take(5).cloned().collect();
        let slow = items.iter().rev().take(5).cloned().collect();

        Ok((fast, slow))
    }
}
