use sqlx::{migrate::Migrator, PgPool};

static MIGRATOR: Migrator = sqlx::migrate!();

pub async fn init(database_url: &str) -> Result<PgPool, sqlx::Error> {
    let pool = PgPool::connect(database_url).await?;
    MIGRATOR.run(&pool).await?;
    Ok(pool)
}
