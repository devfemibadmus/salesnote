-- 0010_receipt_customer_and_drop_suggestions.sql
-- - drop suggestions table
-- - make receipts.signature_id required
-- - add receipt customer fields

-- Ensure each shop with receipts has at least one signature.
WITH shops_missing_signature AS (
  SELECT DISTINCT r.shop_id
  FROM receipts r
  LEFT JOIN signatures s ON s.shop_id = r.shop_id
  WHERE s.id IS NULL
)
INSERT INTO signatures (shop_id, name, image_url)
SELECT
  sms.shop_id,
  'Default Signature',
  'https://aisignator.com/wp-content/uploads/2025/05/Amanda-signature.jpg'
FROM shops_missing_signature sms;

-- Backfill null receipt signature_id with shop's earliest signature.
UPDATE receipts r
SET signature_id = (
  SELECT s.id
  FROM signatures s
  WHERE s.shop_id = r.shop_id
  ORDER BY s.created_at ASC
  LIMIT 1
)
WHERE r.signature_id IS NULL;

-- Add customer fields directly on receipt.
ALTER TABLE receipts
  ADD COLUMN IF NOT EXISTS customer_name TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS customer_email TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS customer_phone TEXT NOT NULL DEFAULT '';

-- Backfill customer_name from sale if empty.
UPDATE receipts r
SET customer_name = COALESCE(s.customer_name, '')
FROM sales s
WHERE r.sale_id = s.id
  AND r.customer_name = '';

-- Enforce required signature_id.
ALTER TABLE receipts
  ALTER COLUMN signature_id SET NOT NULL;

-- Suggestions are no longer used.
DROP TABLE IF EXISTS suggestions;
