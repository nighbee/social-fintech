-- Migration: 050_add_transfer_alias_to_enum.sql
-- Add 'transfer' alias to the transaction_category enum for compatibility with legacy/external clients.

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transaction_category') THEN
        ALTER TYPE transaction_category ADD VALUE IF NOT EXISTS 'transfer';
    END IF;
END $$;
