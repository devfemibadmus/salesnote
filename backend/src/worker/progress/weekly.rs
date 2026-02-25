use chrono::{Datelike, Duration, Timelike, Utc};
use chrono_tz::Tz;
use sqlx::PgPool;
use std::str::FromStr;

use crate::config::Settings;
use crate::worker::notification::fcm::send_fcm_notification;
use crate::worker::progress::message::{build_progress_message, ProgressInput};
use crate::worker::progress::repo::{
    already_sent_today, count_sales_between, fetch_shops_with_tokens, mark_sent, top_item_between,
};
use crate::worker::progress::time::local_midnight;

const KIND_WEEKLY: &str = "weekly_sales";

pub async fn process_weekly_receipt(settings: &Settings, pool: &PgPool) -> Result<(), String> {
    let shops = fetch_shops_with_tokens(pool)
        .await
        .map_err(|e| e.to_string())?;
    for shop in shops {
        let tz = Tz::from_str(&shop.timezone).unwrap_or(chrono_tz::UTC);
        let now_local = Utc::now().with_timezone(&tz);
        if now_local.hour() < 12 {
            continue;
        }

        let weekday = now_local.weekday().number_from_monday() as i64;
        let week_start_date = now_local.date_naive() - Duration::days(weekday - 1);
        let week_start_local = local_midnight(tz, week_start_date);
        let prev_week_start_local = week_start_local - Duration::days(7);
        let offset = now_local - week_start_local;
        let prev_week_end_local = prev_week_start_local + offset;

        let week_start = week_start_local.with_timezone(&Utc);
        let now_utc = now_local.with_timezone(&Utc);
        let prev_week_start = prev_week_start_local.with_timezone(&Utc);
        let prev_week_end = prev_week_end_local.with_timezone(&Utc);

        let iso = now_local.iso_week();
        let period_key = format!("{}-W{:02}", iso.year(), iso.week());

        if already_sent_today(pool, shop.id, KIND_WEEKLY, &period_key)
            .await
            .map_err(|e| e.to_string())?
        {
            continue;
        }

        let current_count = count_sales_between(pool, shop.id, week_start, now_utc).await?;
        let previous_count =
            count_sales_between(pool, shop.id, prev_week_start, prev_week_end).await?;
        let top_item = top_item_between(pool, shop.id, week_start, now_utc).await?;

        let message = build_progress_message(ProgressInput {
            period_label: "week",
            current_sales: current_count,
            previous_sales: previous_count,
            top_item,
        });
        if let Some(message) = message {
            send_fcm_notification(
                &shop.fcm_token,
                message.title,
                message.body,
                KIND_WEEKLY,
                settings,
            )
            .await?;
            mark_sent(pool, shop.id, KIND_WEEKLY, &period_key)
                .await
                .map_err(|e| e.to_string())?;
        }
    }

    Ok(())
}
