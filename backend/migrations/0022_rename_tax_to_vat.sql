DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'sales'
      AND column_name = 'tax_amount'
  ) AND EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'sales'
      AND column_name = 'vat_amount'
  ) THEN
    UPDATE sales
    SET vat_amount = tax_amount
    WHERE vat_amount = 0
      AND tax_amount <> 0;

    ALTER TABLE sales
      DROP COLUMN tax_amount;
  ELSIF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'sales'
      AND column_name = 'tax_amount'
  ) THEN
    ALTER TABLE sales
      RENAME COLUMN tax_amount TO vat_amount;
  END IF;
END $$;

ALTER TABLE sales
  ADD COLUMN IF NOT EXISTS vat_amount DOUBLE PRECISION NOT NULL DEFAULT 0;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'sales_tax_nonnegative'
  ) THEN
    ALTER TABLE sales
      DROP CONSTRAINT sales_tax_nonnegative;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'sales_vat_nonnegative'
  ) THEN
    ALTER TABLE sales
      ADD CONSTRAINT sales_vat_nonnegative CHECK (vat_amount >= 0);
  END IF;
END $$;
