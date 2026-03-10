CREATE TABLE IF NOT EXISTS shop_bank_accounts (
    shop_id BIGINT NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    id SMALLINT NOT NULL CHECK (id IN (1, 2)),
    bank_name TEXT NOT NULL,
    account_number TEXT NOT NULL,
    account_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (shop_id, id)
);

CREATE INDEX IF NOT EXISTS idx_shop_bank_accounts_shop_id
    ON shop_bank_accounts (shop_id);
