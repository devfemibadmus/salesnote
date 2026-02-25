ALTER TABLE sales
  ADD COLUMN IF NOT EXISTS subtotal DOUBLE PRECISION NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS discount_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tax_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS service_fee_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS delivery_fee_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rounding_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS other_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS other_label TEXT NOT NULL DEFAULT '';

UPDATE sales
SET subtotal = total
WHERE subtotal = 0
  AND discount_amount = 0
  AND tax_amount = 0
  AND service_fee_amount = 0
  AND delivery_fee_amount = 0
  AND rounding_amount = 0
  AND other_amount = 0
  AND other_label = '';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'sales_subtotal_nonnegative'
  ) THEN
    ALTER TABLE sales
      ADD CONSTRAINT sales_subtotal_nonnegative CHECK (subtotal >= 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'sales_discount_nonnegative'
  ) THEN
    ALTER TABLE sales
      ADD CONSTRAINT sales_discount_nonnegative CHECK (discount_amount >= 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'sales_tax_nonnegative'
  ) THEN
    ALTER TABLE sales
      ADD CONSTRAINT sales_tax_nonnegative CHECK (tax_amount >= 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'sales_service_fee_nonnegative'
  ) THEN
    ALTER TABLE sales
      ADD CONSTRAINT sales_service_fee_nonnegative CHECK (service_fee_amount >= 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'sales_delivery_fee_nonnegative'
  ) THEN
    ALTER TABLE sales
      ADD CONSTRAINT sales_delivery_fee_nonnegative CHECK (delivery_fee_amount >= 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'sales_total_nonnegative'
  ) THEN
    ALTER TABLE sales
      ADD CONSTRAINT sales_total_nonnegative CHECK (total >= 0);
  END IF;
END $$;
