ALTER TABLE password_reset_codes
ADD COLUMN IF NOT EXISTS failed_attempts INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_password_reset_codes_shop_created_at
  ON password_reset_codes (shop_id, created_at DESC);
