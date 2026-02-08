-- Migration: Add Phone Authentication
-- Description: Add phone number fields to users table and create phone verification table
-- Flow: Request OTP -> Verify OTP -> Complete registration (for register) or login directly (for login)

-- Add phone fields to users table (nullable for email/OAuth users)
ALTER TABLE users
	ADD COLUMN IF NOT EXISTS phone_country_code VARCHAR(8),
	ADD COLUMN IF NOT EXISTS phone_number VARCHAR(32);

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone_unique
	ON users(phone_country_code, phone_number)
	WHERE phone_number IS NOT NULL;

-- Phone verification table for OTP codes
-- Purpose: 'login' (phone must exist) or 'register' (phone must not exist)
-- consumed_at: set when code is verified
-- used_at: set when registration is completed (register purpose only)
CREATE TABLE IF NOT EXISTS phone_verifications (
	id UUID PRIMARY KEY,
	phone_country_code VARCHAR(8) NOT NULL,
	phone_number VARCHAR(32) NOT NULL,
	purpose VARCHAR(16) NOT NULL,  -- 'login' or 'register'
	code_hash TEXT NOT NULL,  -- SHA256 hash of 4-digit OTP
	expires_at TIMESTAMP NOT NULL,  -- OTP expires after 10 minutes
	consumed_at TIMESTAMP,  -- When OTP was verified
	used_at TIMESTAMP,  -- When registration was completed
	created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_phone_verifications_phone
	ON phone_verifications(phone_country_code, phone_number);
CREATE INDEX IF NOT EXISTS idx_phone_verifications_expires
	ON phone_verifications(expires_at);

COMMENT ON TABLE phone_verifications IS 'OTP verification codes for phone authentication (4-digit codes, 10 min TTL)';
COMMENT ON COLUMN phone_verifications.purpose IS 'Authentication purpose: login or register';
COMMENT ON COLUMN phone_verifications.consumed_at IS 'Timestamp when OTP was successfully verified';
COMMENT ON COLUMN phone_verifications.used_at IS 'Timestamp when verification was used to complete registration';
