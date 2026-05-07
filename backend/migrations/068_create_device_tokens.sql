-- Migration: Device tokens for push notifications
-- Description: Stores push tokens for iOS (APNs), Android (FCM), and Huawei (HMS).

CREATE TYPE device_platform AS ENUM ('ios', 'android', 'huawei');

CREATE TABLE IF NOT EXISTS device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform device_platform NOT NULL,
    device_id TEXT, -- Optional hardware identifier for better tracking
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_seen_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON device_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_device_tokens_active_token ON device_tokens(token) WHERE is_active = TRUE;

COMMENT ON TABLE device_tokens IS 'Registry of push notification tokens for mobile devices.';
COMMENT ON COLUMN device_tokens.token IS 'Unique registration token provided by the push service (FCM, APNs, HMS).';
COMMENT ON COLUMN device_tokens.platform IS 'The OS platform: ios, android, or huawei.';
