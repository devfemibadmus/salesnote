use chrono::{Duration, Timelike, Utc};
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

const KIND_DAILY: &str = "daily_sales";

pub async fn process_daily_receipt(settings: &Settings, pool: &PgPool) -> Result<(), String> {
    let shops = fetch_shops_with_tokens(pool)
        .await
        .map_err(|e| e.to_string())?;
    for shop in shops {
        let tz = Tz::from_str(&shop.timezone).unwrap_or(chrono_tz::UTC);
        let now_local = Utc::now().with_timezone(&tz);
        if now_local.hour() < 12 {
            continue;
        }

        let today_start_local = local_midnight(tz, now_local.date_naive());
        let yesterday_start_local = today_start_local - Duration::days(1);
        let yesterday_end_local = now_local - Duration::days(1);

        let today_start = today_start_local.with_timezone(&Utc);
        let now_utc = now_local.with_timezone(&Utc);
        let yesterday_start = yesterday_start_local.with_timezone(&Utc);
        let yesterday_end = yesterday_end_local.with_timezone(&Utc);

        let day_key = now_local.date_naive().format("%Y-%m-%d").to_string();

        if already_sent_today(pool, shop.id, KIND_DAILY, &day_key)
            .await
            .map_err(|e| e.to_string())?
        {
            continue;
        }

        let today_count = count_sales_between(pool, shop.id, today_start, now_utc).await?;
        let yesterday_count =
            count_sales_between(pool, shop.id, yesterday_start, yesterday_end).await?;
        let top_item = top_item_between(pool, shop.id, today_start, now_utc).await?;

        let message = build_progress_message(ProgressInput {
            period_label: "day",
            current_sales: today_count,
            previous_sales: yesterday_count,
            top_item,
        });
        if let Some(message) = message {
            send_fcm_notification(
                &shop.fcm_token,
                message.title,
                message.body,
                KIND_DAILY,
                settings,
            )
            .await?;
            mark_sent(pool, shop.id, KIND_DAILY, &day_key)
                .await
                .map_err(|e| e.to_string())?;
        }
    }

    Ok(())
}
