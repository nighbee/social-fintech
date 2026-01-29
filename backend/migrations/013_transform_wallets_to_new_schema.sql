ALTER TABLE wallets DROP CONSTRAINT IF EXISTS wallets_pkey;

ALTER TABLE wallets ADD COLUMN id UUID;
UPDATE wallets SET id = uuid_generate_v4();
ALTER TABLE wallets ALTER COLUMN id SET NOT NULL;
ALTER TABLE wallets ALTER COLUMN id SET DEFAULT uuid_generate_v4();
ALTER TABLE wallets ADD PRIMARY KEY (id);

DROP TYPE IF EXISTS currency_code CASCADE;
CREATE TYPE currency_code AS ENUM ('SILVER_SEAL', 'GOLD_SEAL');

ALTER TABLE wallets ADD COLUMN currency currency_code;

ALTER TABLE wallets ADD COLUMN balance BIGINT DEFAULT 0;
ALTER TABLE wallets ADD COLUMN free_balance BIGINT DEFAULT 0;
ALTER TABLE wallets ADD COLUMN last_daily_accrual_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE wallets ADD COLUMN last_transfer_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE wallets ADD COLUMN version BIGINT DEFAULT 0 NOT NULL;

UPDATE wallets SET 
    currency = 'SILVER_SEAL',
    balance = silver_balance,
    free_balance = LEAST(silver_balance, 500),
    version = 0;

INSERT INTO wallets (user_id, currency, balance, free_balance, version, created_at, updated_at)
SELECT user_id, 'GOLD_SEAL', gold_balance, 0, 0, created_at, updated_at
FROM wallets 
WHERE currency = 'SILVER_SEAL';

ALTER TABLE wallets ALTER COLUMN currency SET NOT NULL;
ALTER TABLE wallets ALTER COLUMN balance SET NOT NULL;
ALTER TABLE wallets ALTER COLUMN free_balance SET NOT NULL;

ALTER TABLE wallets ADD CONSTRAINT positive_balance CHECK (balance >= 0);
ALTER TABLE wallets ADD CONSTRAINT free_balance_limit CHECK (free_balance >= 0 AND free_balance <= 500);
ALTER TABLE wallets ADD CONSTRAINT unique_user_currency UNIQUE(user_id, currency);

ALTER TABLE wallets DROP COLUMN IF EXISTS silver_balance;
ALTER TABLE wallets DROP COLUMN IF EXISTS gold_balance;

CREATE INDEX idx_wallets_lookup ON wallets(user_id, currency);
CREATE INDEX idx_wallets_accrual ON wallets(last_daily_accrual_at) WHERE currency = 'SILVER_SEAL';
CREATE INDEX idx_wallets_last_transfer ON wallets(last_transfer_at) WHERE last_transfer_at IS NOT NULL;

CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_wallets_timestamp ON wallets;
CREATE TRIGGER update_wallets_timestamp
BEFORE UPDATE ON wallets
FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

ALTER TABLE wallets ALTER COLUMN created_at TYPE TIMESTAMP WITH TIME ZONE;
ALTER TABLE wallets ALTER COLUMN updated_at TYPE TIMESTAMP WITH TIME ZONE;
ALTER TABLE wallets ALTER COLUMN created_at SET DEFAULT NOW();
ALTER TABLE wallets ALTER COLUMN updated_at SET DEFAULT NOW();

DROP INDEX IF EXISTS idx_wallets_updated_at;
