-- 0002_auth_email_retry.sql

ALTER TABLE shops
  ADD COLUMN IF NOT EXISTS failed_login_attempts INTEGER NOT NULL DEFAULT 0;

ALTER TABLE shops
  ADD COLUMN IF NOT EXISTS locked_until TIMESTAMPTZ;

ALTER TABLE email_outbox
  ADD COLUMN IF NOT EXISTS next_attempt_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_email_outbox_next_attempt
  ON email_outbox (status, next_attempt_at);
