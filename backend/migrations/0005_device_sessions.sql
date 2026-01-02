-- 0005_device_sessions.sql

CREATE TABLE IF NOT EXISTS device_sessions (
  id BIGSERIAL PRIMARY KEY,
  shop_id BIGINT NOT NULL REFERENCES shops(id),
  device_name TEXT,
  device_platform TEXT,
  device_os TEXT,
  ip_address TEXT,
  location TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_device_sessions_shop
  ON device_sessions (shop_id);

CREATE INDEX IF NOT EXISTS idx_device_sessions_seen
  ON device_sessions (last_seen_at);

ALTER TABLE refresh_tokens
  ADD COLUMN IF NOT EXISTS device_session_id BIGINT REFERENCES device_sessions(id);
