-- 0007_drop_email_subject_body.sql

ALTER TABLE email_outbox
  DROP COLUMN IF EXISTS subject,
  DROP COLUMN IF EXISTS body;
