-- телефонный auth + verificatiosn поля
ALTER TABLE users
	ADD COLUMN IF NOT EXISTS phone_country_code VARCHAR(8),
	ADD COLUMN IF NOT EXISTS phone_number VARCHAR(32);

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone_unique
	ON users(phone_country_code, phone_number)
	WHERE phone_number IS NOT NULL;

CREATE TABLE IF NOT EXISTS phone_verifications (
	id UUID PRIMARY KEY,
	phone_country_code VARCHAR(8) NOT NULL,
	phone_number VARCHAR(32) NOT NULL,
	purpose VARCHAR(16) NOT NULL,
	code_hash TEXT NOT NULL,
	expires_at TIMESTAMP NOT NULL,
	consumed_at TIMESTAMP,
	used_at TIMESTAMP,
	created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_phone_verifications_phone
	ON phone_verifications(phone_country_code, phone_number);
CREATE INDEX IF NOT EXISTS idx_phone_verifications_expires
	ON phone_verifications(expires_at);
