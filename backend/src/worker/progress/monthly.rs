use chrono::{Datelike, Timelike, Utc};
use chrono_tz::Tz;
use sqlx::PgPool;
use std::str::FromStr;

use crate::config::Settings;
use crate::worker::notification::fcm::send_fcm_notification;
use crate::worker::progress::message::{build_progress_message, ProgressInput};
use crate::worker::progress::repo::{
    already_sent_today, count_sales_between, fetch_shops_with_tokens, mark_sent,
    top_item_between,
};
use crate::worker::progress::time::local_midnight;

const KIND_MONTHLY: &str = "monthly_sales";

pub async fn process_monthly_receipt(settings: &Settings, pool: &PgPool) -> Result<(), String> {
    let shops = fetch_shops_with_tokens(pool)
        .await
        .map_err(|e| e.to_string())?;
    for shop in shops {
        let tz = Tz::from_str(&shop.timezone).unwrap_or(chrono_tz::UTC);
        let now_local = Utc::now().with_timezone(&tz);
        if now_local.hour() < 12 {
            continue;
        }

        let month_start_date = now_local.date_naive().with_day(1).unwrap();
        let month_start_local = local_midnight(tz, month_start_date);

        let (prev_year, prev_month) = if now_local.month() == 1 {
            (now_local.year() - 1, 12)
        } else {
            (now_local.year(), now_local.month() - 1)
        };
        let prev_start_date = chrono::NaiveDate::from_ymd_opt(prev_year, prev_month, 1).unwrap();
        let prev_month_start_local = local_midnight(tz, prev_start_date);
        let offset = now_local - month_start_local;
        let prev_month_end_local = prev_month_start_local + offset;

        let month_start = month_start_local.with_timezone(&Utc);
        let now_utc = now_local.with_timezone(&Utc);
        let prev_start = prev_month_start_local.with_timezone(&Utc);
        let prev_end = prev_month_end_local.with_timezone(&Utc);

        let period_key = format!("{}-{:02}", now_local.year(), now_local.month());

        if already_sent_today(pool, shop.id, KIND_MONTHLY, &period_key)
            .await
            .map_err(|e| e.to_string())?
        {
            continue;
        }

        let current_count = count_sales_between(pool, shop.id, month_start, now_utc).await?;
        let previous_count = count_sales_between(pool, shop.id, prev_start, prev_end).await?;
        let top_item = top_item_between(pool, shop.id, month_start, now_utc).await?;

        let message = build_progress_message(ProgressInput {
            period_label: "month",
            current_sales: current_count,
            previous_sales: previous_count,
            top_item,
        });
        if let Some(message) = message {
            send_fcm_notification(
                &shop.fcm_token,
                message.title,
                message.body,
                KIND_MONTHLY,
                settings,
            )
            .await?;
            mark_sent(pool, shop.id, KIND_MONTHLY, &period_key)
                .await
                .map_err(|e| e.to_string())?;
        }
    }

    Ok(())
}
