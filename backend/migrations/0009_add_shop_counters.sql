ALTER TABLE shops
ADD COLUMN IF NOT EXISTS total_revenue DOUBLE PRECISION NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_orders BIGINT NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_customers BIGINT NOT NULL DEFAULT 0;

UPDATE shops s
SET
  total_revenue = COALESCE(x.total_revenue, 0),
  total_orders = COALESCE(x.total_orders, 0),
  total_customers = COALESCE(x.total_customers, 0)
FROM (
  SELECT
    r.shop_id,
    SUM(sa.total) AS total_revenue,
    COUNT(*)::bigint AS total_orders,
    COUNT(CASE WHEN sa.customer_name IS NOT NULL AND BTRIM(sa.customer_name) <> '' THEN 1 END)::bigint AS total_customers
  FROM receipts r
  JOIN sales sa ON sa.id = r.sale_id
  GROUP BY r.shop_id
) x
WHERE s.id = x.shop_id;
