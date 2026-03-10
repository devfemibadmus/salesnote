ALTER TABLE sales
ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'paid';

UPDATE sales
SET status = 'paid'
WHERE status IS NULL
   OR BTRIM(status) = '';

ALTER TABLE sales
DROP CONSTRAINT IF EXISTS sales_status_check;

ALTER TABLE sales
ADD CONSTRAINT sales_status_check
CHECK (status IN ('paid', 'invoice'));
