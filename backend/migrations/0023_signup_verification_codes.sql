CREATE TABLE IF NOT EXISTS signup_verification_codes (
  id BIGSERIAL PRIMARY KEY,
  phone TEXT NOT NULL,
  email TEXT NOT NULL,
  code TEXT NOT NULL,
  failed_attempts INTEGER NOT NULL DEFAULT 0,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_signup_verification_codes_phone_created_at
  ON signup_verification_codes (phone, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_signup_verification_codes_email_created_at
  ON signup_verification_codes (email, created_at DESC);
