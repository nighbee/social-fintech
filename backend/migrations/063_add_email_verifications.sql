-- Migration: Email verification codes
-- Description: Adds the table that backs the email-confirmation-code flow
--   used during registration ("ввод кода"), password reset and email change.
-- Flow mirrors phone_verifications: Request -> Verify -> Use.

CREATE TABLE IF NOT EXISTS email_verifications (
    id UUID PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    purpose VARCHAR(32) NOT NULL,  -- 'register' | 'login' | 'email_change' | 'password_reset'
    code_hash TEXT NOT NULL,        -- SHA256 hash of 6-digit OTP
    expires_at TIMESTAMP NOT NULL,  -- 10 minutes from creation
    consumed_at TIMESTAMP,          -- set when code is verified
    used_at TIMESTAMP,              -- set when verification fully completes the higher-level action
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_email_verifications_email
    ON email_verifications(LOWER(email));
CREATE INDEX IF NOT EXISTS idx_email_verifications_expires
    ON email_verifications(expires_at);

COMMENT ON TABLE email_verifications IS 'OTP verification codes for email authentication (6-digit codes, 10 min TTL)';
COMMENT ON COLUMN email_verifications.purpose IS 'Authentication purpose: register | login | email_change | password_reset';
COMMENT ON COLUMN email_verifications.consumed_at IS 'Timestamp when OTP was successfully verified';
COMMENT ON COLUMN email_verifications.used_at IS 'Timestamp when verification was used to complete the requested action';
