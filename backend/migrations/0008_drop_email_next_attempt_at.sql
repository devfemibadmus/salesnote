-- 0008_drop_email_next_attempt_at.sql

DROP INDEX IF EXISTS idx_email_outbox_next_attempt;

ALTER TABLE email_outbox
  DROP COLUMN IF EXISTS next_attempt_at;
