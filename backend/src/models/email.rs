use serde::Serialize;
use serde_json::Value;
use sqlx::{PgPool, Row};
use tracing::warn;

#[derive(Debug, Serialize)]
pub struct EmailOutbox {
    pub id: i64,
    pub to_email: String,
    pub template: Option<String>,
    pub payload: Option<Value>,
    pub status: String,
    pub attempts: i32,
    pub last_error: Option<String>,
    pub created_at: String,
    pub sent_at: Option<String>,
}

#[derive(Debug, Clone)]
pub struct EmailEnqueuePayload {
    pub to_email: String,
    pub template: Option<String>,
    pub payload: Option<Value>,
}

#[derive(Debug, Clone)]
pub struct EmailFetchPayload {
    pub limit: i64,
}

#[derive(Debug, Clone)]
pub struct EmailMarkPayload {
    pub id: i64,
    pub error: Option<String>,
}

#[derive(Debug, Clone)]
pub struct EmailFailPayload {
    pub id: i64,
    pub error: Option<String>,
    pub status: String,
}

impl EmailOutbox {
    pub async fn enqueue(pool: &PgPool, payload: &EmailEnqueuePayload) -> Result<(), sqlx::Error> {
        sqlx::query(
            "INSERT INTO email_outbox (to_email, template, payload)
             VALUES ($1, $2, $3)",
        )
        .bind(&payload.to_email)
        .bind(&payload.template)
        .bind(&payload.payload)
        .execute(pool)
        .await?;

        Ok(())
    }

    pub async fn fetch_pending(
        pool: &PgPool,
        payload: &EmailFetchPayload,
    ) -> Result<Vec<EmailOutbox>, sqlx::Error> {
        let rows = sqlx::query(
            "SELECT id, to_email, template, payload, status, attempts, last_error,
                    created_at::text as created_at,
                    sent_at::text as sent_at
             FROM email_outbox
             WHERE status = 'pending'
               AND attempts < 2
             ORDER BY created_at ASC
             LIMIT $1",
        )
        .bind(payload.limit)
        .fetch_all(pool)
        .await?;

        Ok(rows
            .into_iter()
            .map(|row| EmailOutbox {
                id: row.get("id"),
                to_email: row.get("to_email"),
                template: row.get("template"),
                payload: row.get("payload"),
                status: row.get("status"),
                attempts: row.get("attempts"),
                last_error: row.get("last_error"),
                created_at: row.get("created_at"),
                sent_at: row.get("sent_at"),
            })
            .collect())
    }

    pub async fn mark_sent(pool: &PgPool, payload: &EmailMarkPayload) -> Result<(), sqlx::Error> {
        let row = sqlx::query(
            "UPDATE email_outbox
             SET status = 'sent', sent_at = NOW(), last_error = NULL
             WHERE id = $1
             RETURNING id",
        )
        .bind(payload.id)
        .fetch_optional(pool)
        .await?;
        if row.is_none() {
            warn!("email_outbox mark_sent no rows for id {}", payload.id);
        }
        Ok(())
    }

    pub async fn mark_failed(pool: &PgPool, payload: &EmailFailPayload) -> Result<(), sqlx::Error> {
        let row = sqlx::query(
            "UPDATE email_outbox
             SET status = $1, attempts = attempts + 1, last_error = $2
             WHERE id = $3
             RETURNING id",
        )
        .bind(&payload.status)
        .bind(&payload.error)
        .bind(payload.id)
        .fetch_optional(pool)
        .await?;
        if row.is_none() {
            warn!("email_outbox mark_failed no rows for id {}", payload.id);
        }
        Ok(())
    }
}
