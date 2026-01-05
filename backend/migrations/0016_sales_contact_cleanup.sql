DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'sales'
      AND column_name = 'customer_phone'
  ) AND NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'sales'
      AND column_name = 'customer_contact'
  ) THEN
    ALTER TABLE sales RENAME COLUMN customer_phone TO customer_contact;
  END IF;
END$$;

ALTER TABLE sales
  ADD COLUMN IF NOT EXISTS customer_contact TEXT NOT NULL DEFAULT '';

ALTER TABLE sales
  ALTER COLUMN customer_contact SET DEFAULT '',
  ALTER COLUMN customer_contact SET NOT NULL;

ALTER TABLE sales
  DROP COLUMN IF EXISTS customer_email;
