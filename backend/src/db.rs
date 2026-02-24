use sqlx::{migrate::Migrator, postgres::PgPoolOptions, PgPool};

static MIGRATOR: Migrator = sqlx::migrate!();

pub async fn init(
    database_url: &str,
    pool_max_size: u32,
    pool_min_idle: u32,
) -> Result<PgPool, sqlx::Error> {
    let max_size = pool_max_size.max(1);
    let min_idle = pool_min_idle.min(max_size);

    let pool = PgPoolOptions::new()
        .max_connections(max_size)
        .min_connections(min_idle)
        .connect(database_url)
        .await?;
    MIGRATOR.run(&pool).await?;
    Ok(pool)
}
