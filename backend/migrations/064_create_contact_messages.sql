-- Migration: Contact us messages
-- Description: Backs the in-app "Contact us" form. Each submission is also
-- attempted via SMTP to the support inbox (config.support_email_recipient,
-- defaults to 19thZaratustra@gmail.com), but the row is the source of truth
-- and is preserved even if outbound email transport fails.

CREATE TABLE IF NOT EXISTS contact_messages (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    category VARCHAR(32) NOT NULL,        -- 'bug' | 'error' | 'suggestion' | 'other'
    subject VARCHAR(255),
    message TEXT NOT NULL,
    contact_email VARCHAR(255),           -- optional reply-to override
    app_version VARCHAR(64),
    device_os VARCHAR(64),
    delivered_at TIMESTAMP,               -- set after the SMTP send succeeds
    delivery_error TEXT,                  -- last transport error if any
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_contact_messages_user
    ON contact_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_contact_messages_category
    ON contact_messages(category);
CREATE INDEX IF NOT EXISTS idx_contact_messages_created
    ON contact_messages(created_at DESC);

COMMENT ON TABLE contact_messages IS 'In-app Contact Us submissions. Persisted before email transport so support tickets are never lost on SMTP failure.';
COMMENT ON COLUMN contact_messages.category IS 'Submission category: bug | error | suggestion | other';
COMMENT ON COLUMN contact_messages.delivered_at IS 'Set when the message has been successfully relayed to the support inbox';
