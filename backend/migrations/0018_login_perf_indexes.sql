-- Speed up login CTE hot paths.

-- Match the existing-device lookup in auth login.
CREATE INDEX IF NOT EXISTS idx_device_sessions_login_match
  ON device_sessions (
    shop_id,
    device_name,
    device_platform,
    device_os,
    last_seen_at DESC
  )
  WHERE deleted_at IS NULL;

-- Match refresh token revoke query in auth login.
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_active_device
  ON refresh_tokens (shop_id, device_session_id)
  WHERE revoked_at IS NULL;

