-- Migration: Create Payment Tables
-- Description: Creates payment_logs table for tracking IAP purchases

-- Create payment_logs table
CREATE TABLE IF NOT EXISTS payment_logs (
    id UUID PRIMARY KEY,
    event_id VARCHAR(255) NOT NULL UNIQUE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id VARCHAR(255) NOT NULL,
    amount BIGINT NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_payment_logs_user_id ON payment_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_logs_event_id ON payment_logs(event_id);
CREATE INDEX IF NOT EXISTS idx_payment_logs_created_at ON payment_logs(created_at DESC);

-- Add comments
COMMENT ON TABLE payment_logs IS 'Logs of processed IAP purchases from RevenueCat';
COMMENT ON COLUMN payment_logs.event_id IS 'Unique event ID from RevenueCat for idempotency';
COMMENT ON COLUMN payment_logs.amount IS 'Amount of Silver Seals credited';
