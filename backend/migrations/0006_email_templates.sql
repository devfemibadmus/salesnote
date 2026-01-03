-- 0006_email_templates.sql

ALTER TABLE email_outbox
  ADD COLUMN IF NOT EXISTS template TEXT,
  ADD COLUMN IF NOT EXISTS payload JSONB;

ALTER TABLE email_outbox
  ALTER COLUMN subject DROP NOT NULL,
  ALTER COLUMN body DROP NOT NULL;
