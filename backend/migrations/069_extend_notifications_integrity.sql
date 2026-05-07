-- Extend device_tokens for debugging and localization
ALTER TABLE device_tokens ADD COLUMN IF NOT EXISTS app_version VARCHAR(20);
ALTER TABLE device_tokens ADD COLUMN IF NOT EXISTS locale VARCHAR(10);

-- Create sent_notifications for idempotency tracking and auditing
CREATE TABLE IF NOT EXISTS sent_notifications (
    id UUID PRIMARY KEY,
    idempotency_key VARCHAR(255) NOT NULL,
    device_token VARCHAR(255) NOT NULL,
    platform VARCHAR(20) NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status VARCHAR(20) NOT NULL, -- 'sent', 'failed', 'duplicate'
    error_message TEXT,
    
    CONSTRAINT unique_idempotency_per_token UNIQUE (idempotency_key, device_token)
);

-- Index for idempotency lookups
CREATE INDEX IF NOT EXISTS idx_sent_notifications_idempotency ON sent_notifications(idempotency_key);
