ALTER TABLE device_sessions
  ADD COLUMN IF NOT EXISTS fcm_token TEXT;

CREATE INDEX IF NOT EXISTS idx_device_sessions_fcm_token
  ON device_sessions (fcm_token)
  WHERE deleted_at IS NULL AND fcm_token IS NOT NULL AND fcm_token <> '';

ALTER TABLE shops
  DROP COLUMN IF EXISTS fcm_token;
