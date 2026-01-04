CREATE TABLE IF NOT EXISTS shop_product_daily (
  shop_id BIGINT NOT NULL REFERENCES shops(id),
  product_name TEXT NOT NULL,
  day DATE NOT NULL,
  quantity DOUBLE PRECISION NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (shop_id, product_name, day)
);

CREATE INDEX IF NOT EXISTS idx_shop_product_daily_shop_day
ON shop_product_daily (shop_id, day DESC);
