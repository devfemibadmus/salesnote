CREATE INDEX IF NOT EXISTS idx_sales_shop_created_at
ON sales (shop_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id
ON sale_items (sale_id);
