-- Settings module core tables

CREATE TABLE IF NOT EXISTS user_settings (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    feed_time_limit_current_mins INTEGER NOT NULL DEFAULT 20 CHECK (feed_time_limit_current_mins IN (0, 20, 30, 40)),
    feed_time_limit_pending_mins INTEGER NULL CHECK (feed_time_limit_pending_mins IN (0, 20, 30, 40)),
    feed_time_limit_pending_apply_at TIMESTAMP NULL,

    messages_who_can_message VARCHAR(20) NOT NULL DEFAULT 'everyone' CHECK (messages_who_can_message IN ('everyone', 'no_one', 'allies_only')),
    messages_read_status_enabled BOOLEAN NOT NULL DEFAULT true,
    messages_safe_mode_enabled BOOLEAN NOT NULL DEFAULT false,

    comments_who_can_comment VARCHAR(20) NOT NULL DEFAULT 'everyone' CHECK (comments_who_can_comment IN ('everyone', 'no_one', 'allies_only')),
    comments_filter_unwanted_enabled BOOLEAN NOT NULL DEFAULT false,

    mentions_who_can_mention VARCHAR(20) NOT NULL DEFAULT 'everyone' CHECK (mentions_who_can_mention IN ('everyone', 'no_one', 'allies_only')),
    participate_district_ranking BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS message_keyword_filters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    keyword VARCHAR(120) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, keyword)
);

CREATE INDEX IF NOT EXISTS idx_message_keyword_filters_user ON message_keyword_filters(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS bug_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    description TEXT NOT NULL CHECK (char_length(description) <= 2000),
    screenshot_url TEXT NULL,
    app_version VARCHAR(50) NULL,
    device_os VARCHAR(100) NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'in_review', 'resolved')),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bug_reports_status ON bug_reports(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bug_reports_user ON bug_reports(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS two_factor_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    method VARCHAR(20) NOT NULL CHECK (method IN ('sms', 'email', 'authenticator')),
    is_active BOOLEAN NOT NULL DEFAULT true,
    secret_encrypted TEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, method)
);

CREATE INDEX IF NOT EXISTS idx_two_factor_methods_user ON two_factor_methods(user_id, is_active);

CREATE TABLE IF NOT EXISTS delete_account_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason VARCHAR(64) NOT NULL,
    verification_method VARCHAR(20) NOT NULL CHECK (verification_method IN ('password', 'otp')),
    otp_code_hash TEXT NULL,
    verification_token VARCHAR(255) NULL,
    verification_expires_at TIMESTAMP NULL,
    verified_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_delete_account_requests_user ON delete_account_requests(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS settings_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action VARCHAR(64) NOT NULL,
    details JSONB NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_settings_audit_logs_user ON settings_audit_logs(user_id, created_at DESC);

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP NULL,
    ADD COLUMN IF NOT EXISTS hard_delete_scheduled_at TIMESTAMP NULL;

-- Auto-create settings row at registration.
CREATE OR REPLACE FUNCTION create_default_user_settings()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_settings(user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_create_default_user_settings ON users;
CREATE TRIGGER trg_create_default_user_settings
AFTER INSERT ON users
FOR EACH ROW
EXECUTE FUNCTION create_default_user_settings();

-- Backfill for existing users.
INSERT INTO user_settings(user_id)
SELECT u.id
FROM users u
LEFT JOIN user_settings s ON s.user_id = u.id
WHERE s.user_id IS NULL;
