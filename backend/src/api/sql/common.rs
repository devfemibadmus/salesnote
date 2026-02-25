pub const AUTH_CTE: &str = r#"
auth_active AS (
  SELECT id
  FROM device_sessions
  WHERE id = $2
    AND shop_id = $1
    AND deleted_at IS NULL
),
auth_touch AS (
  UPDATE device_sessions
  SET last_seen_at = NOW()
  WHERE id IN (SELECT id FROM auth_active)
    AND (
      last_seen_at IS NULL
      OR last_seen_at < NOW() - ('5 minutes')::interval
    )
  RETURNING id
)
"#;
