CREATE INDEX IF NOT EXISTS idx_sales_shop_created_recent
ON sales (shop_id, created_at DESC, id);

CREATE INDEX IF NOT EXISTS idx_sale_items_sale_product
ON sale_items (sale_id, product_name);
