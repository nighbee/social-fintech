-- Ensure transaction_category enum includes values used by current backend code.
-- This migration is safe to run multiple times.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transaction_category') THEN
        ALTER TYPE transaction_category ADD VALUE IF NOT EXISTS 'TASK_REFUND';
        ALTER TYPE transaction_category ADD VALUE IF NOT EXISTS 'POST_SEAL';
    END IF;
END $$;
