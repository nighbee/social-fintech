-- Migration: 051_add_signup_bonus_category.sql
-- Add SIGNUP_BONUS to the transaction_category enum.

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transaction_category') THEN
        ALTER TYPE transaction_category ADD VALUE IF NOT EXISTS 'SIGNUP_BONUS';
    END IF;
END $$;
