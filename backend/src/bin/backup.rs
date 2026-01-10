use std::path::PathBuf;
use std::process::Command;

use chrono::Utc;
use salesnote_backend::config;

fn default_backup_path() -> PathBuf {
    let ts = Utc::now().format("%Y%m%d_%H%M%S").to_string();
    PathBuf::from("backups").join(format!("salesnote_{}.dump", ts))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    config::init_tracing();
    let settings = config::Settings::load();

    let backup_path = std::env::var("SALESNOTE__BACKUP_PATH")
        .map(PathBuf::from)
        .unwrap_or_else(|_| default_backup_path());

    if let Some(parent) = backup_path.parent() {
        std::fs::create_dir_all(parent).expect("failed to create backup directory");
    }

    tracing::info!(
        "backing up postgres database -> {}",
        backup_path.display()
    );

    let status = Command::new("pg_dump")
        .arg("--dbname")
        .arg(&settings.database_url)
        .arg("--format")
        .arg("custom")
        .arg("--file")
        .arg(&backup_path)
        .status();

    match status {
        Ok(s) if s.success() => {
            tracing::info!("backup completed");
        }
        Ok(s) => {
            tracing::error!("backup failed: pg_dump exited with {}", s);
        }
        Err(e) => {
            tracing::error!("backup failed: {}", e);
        }
    }

    Ok(())
}
