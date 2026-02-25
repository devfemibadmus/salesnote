use std::sync::Arc;

use tokio_cron_scheduler::{Job, JobScheduler};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    salesnote_backend::config::init_tracing();
    let settings = Arc::new(salesnote_backend::config::Settings::load());
    tracing::info!(
        "[worker] starting (profile={}, env_file={})",
        salesnote_backend::config::active_env_profile(),
        salesnote_backend::config::active_env_file()
    );

    let pool = salesnote_backend::db::init(
        &settings.database_url,
        settings.pool_max_size,
        settings.pool_min_idle,
    )
    .await
    .expect("failed to init database");
    let pool = Arc::new(pool);

    if let Err(e) = salesnote_backend::worker::email::check_smtp(&settings).await {
        tracing::error!("smtp startup check failed: {}", e);
        return Err(std::io::Error::new(
            std::io::ErrorKind::Other,
            format!("smtp startup check failed: {e}"),
        )
        .into());
    }

    let scheduler = JobScheduler::new().await?;

    // Email queue: every minute
    {
        let settings = settings.clone();
        let pool = pool.clone();
        let email_lock = Arc::new(tokio::sync::Mutex::new(()));
        scheduler
            .add(Job::new_async("0 * * * * *", move |_uuid, _l| {
                let settings = settings.clone();
                let pool = pool.clone();
                let email_lock = email_lock.clone();
                Box::pin(async move {
                    let _guard = email_lock.lock().await;
                    if let Err(e) =
                        salesnote_backend::worker::email::process_email_once(&settings, &pool).await
                    {
                        tracing::error!("email worker error: {}", e);
                    }
                })
            })?)
            .await?;
    }

    // Geo IP: every 5 minutes
    {
        let settings = settings.clone();
        let pool = pool.clone();
        let geo_lock = Arc::new(tokio::sync::Mutex::new(()));
        scheduler
            .add(Job::new_async("0 */5 * * * *", move |_uuid, _l| {
                let settings = settings.clone();
                let pool = pool.clone();
                let geo_lock = geo_lock.clone();
                Box::pin(async move {
                    let _guard = geo_lock.lock().await;
                    if let Err(e) =
                        salesnote_backend::worker::geo::process_geoip_once(&settings, &pool).await
                    {
                        tracing::error!("geoip worker error: {}", e);
                    }
                })
            })?)
            .await?;
    }

    // Progress notifications (worker checks per-shop timezone)
    {
        let settings = settings.clone();
        let pool = pool.clone();
        let progress_lock = Arc::new(tokio::sync::Mutex::new(()));
        scheduler
            .add(Job::new_async("0 */5 * * * *", move |_uuid, _l| {
                let settings = settings.clone();
                let pool = pool.clone();
                let progress_lock = progress_lock.clone();
                Box::pin(async move {
                    let _guard = progress_lock.lock().await;
                    if let Err(e) =
                        salesnote_backend::worker::progress::process_daily_receipt(&settings, &pool)
                            .await
                    {
                        tracing::error!("daily progress error: {}", e);
                    }
                    if let Err(e) = salesnote_backend::worker::progress::process_weekly_receipt(
                        &settings, &pool,
                    )
                    .await
                    {
                        tracing::error!("weekly progress error: {}", e);
                    }
                    if let Err(e) = salesnote_backend::worker::progress::process_monthly_receipt(
                        &settings, &pool,
                    )
                    .await
                    {
                        tracing::error!("monthly progress error: {}", e);
                    }
                    if let Err(e) = salesnote_backend::worker::progress::process_yearly_receipt(
                        &settings, &pool,
                    )
                    .await
                    {
                        tracing::error!("yearly progress error: {}", e);
                    }
                })
            })?)
            .await?;
    }

    scheduler.start().await?;
    tracing::info!("worker scheduler started");

    // Keep running
    loop {
        tokio::time::sleep(std::time::Duration::from_secs(3600)).await;
    }
}
