CREATE TABLE IF NOT EXISTS shop_sales_daily (
  shop_id BIGINT NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  day DATE NOT NULL,
  total NUMERIC(14,2) NOT NULL DEFAULT 0,
  orders BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (shop_id, day)
);

INSERT INTO shop_sales_daily (shop_id, day, total, orders, updated_at)
SELECT
  s.shop_id,
  s.created_at::date AS day,
  COALESCE(SUM(s.total), 0)::numeric(14,2) AS total,
  COUNT(*)::bigint AS orders,
  NOW() AS updated_at
FROM sales s
GROUP BY s.shop_id, s.created_at::date
ON CONFLICT (shop_id, day)
DO UPDATE SET
  total = EXCLUDED.total,
  orders = EXCLUDED.orders,
  updated_at = NOW();
