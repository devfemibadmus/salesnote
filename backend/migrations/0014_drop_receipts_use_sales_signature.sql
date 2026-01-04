-- 0014_drop_receipts_use_sales_signature.sql
-- Every sale is its own receipt: move receipt linkage into sales and drop receipts table.

ALTER TABLE sales
  ADD COLUMN IF NOT EXISTS signature_id BIGINT,
  ADD COLUMN IF NOT EXISTS customer_email TEXT,
  ADD COLUMN IF NOT EXISTS customer_phone TEXT;

ALTER TABLE sales
  ALTER COLUMN customer_name SET DEFAULT '',
  ALTER COLUMN customer_email SET DEFAULT '',
  ALTER COLUMN customer_phone SET DEFAULT '';

UPDATE sales
SET customer_name = COALESCE(customer_name, ''),
    customer_email = COALESCE(customer_email, ''),
    customer_phone = COALESCE(customer_phone, '');

ALTER TABLE sales
  ALTER COLUMN customer_name SET NOT NULL,
  ALTER COLUMN customer_email SET NOT NULL,
  ALTER COLUMN customer_phone SET NOT NULL;

-- Backfill sale signature and customer fields from latest receipt for each sale.
UPDATE sales s
SET signature_id = r.signature_id,
    customer_name = CASE WHEN s.customer_name = '' THEN COALESCE(r.customer_name, '') ELSE s.customer_name END,
    customer_email = CASE WHEN s.customer_email = '' THEN COALESCE(r.customer_email, '') ELSE s.customer_email END,
    customer_phone = CASE WHEN s.customer_phone = '' THEN COALESCE(r.customer_phone, '') ELSE s.customer_phone END
FROM (
  SELECT DISTINCT ON (sale_id)
    sale_id,
    signature_id,
    customer_name,
    customer_email,
    customer_phone
  FROM receipts
  ORDER BY sale_id, created_at DESC
) r
WHERE s.id = r.sale_id;

-- Backfill missing signature from shop signatures.
UPDATE sales s
SET signature_id = (
  SELECT sig.id
  FROM signatures sig
  WHERE sig.shop_id = s.shop_id
  ORDER BY sig.created_at ASC
  LIMIT 1
)
WHERE s.signature_id IS NULL;

-- Create default signatures if any shop still has sales without a signature.
WITH shops_missing_signature AS (
  SELECT DISTINCT s.shop_id
  FROM sales s
  WHERE s.signature_id IS NULL
)
INSERT INTO signatures (shop_id, name, image_url)
SELECT
  sms.shop_id,
  'Default Signature',
  'https://aisignator.com/wp-content/uploads/2025/05/Amanda-signature.jpg'
FROM shops_missing_signature sms
ON CONFLICT DO NOTHING;

UPDATE sales s
SET signature_id = (
  SELECT sig.id
  FROM signatures sig
  WHERE sig.shop_id = s.shop_id
  ORDER BY sig.created_at ASC
  LIMIT 1
)
WHERE s.signature_id IS NULL;

ALTER TABLE sales
  ALTER COLUMN signature_id SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'sales_signature_id_fkey'
  ) THEN
    ALTER TABLE sales
      ADD CONSTRAINT sales_signature_id_fkey
      FOREIGN KEY (signature_id) REFERENCES signatures(id);
  END IF;
END $$;

DROP TABLE IF EXISTS receipts;
