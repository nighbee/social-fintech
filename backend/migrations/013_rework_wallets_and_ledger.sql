-- Rework economy schema to per-currency wallets and detailed ledger entries

-- Drop old tables if they exist (only if you are ok with reset on dev)
-- WARNING: keep for dev only. Comment out on production.
-- DROP TABLE IF EXISTS ledger_entries;
-- DROP TABLE IF EXISTS wallets;

CREATE TABLE IF NOT EXISTS wallets (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    currency VARCHAR(20) NOT NULL CHECK (currency IN ('SILVER_SEAL', 'GOLD_SEAL')),
    balance BIGINT NOT NULL DEFAULT 0,
    free_balance BIGINT NOT NULL DEFAULT 0,
    last_daily_accrual_at TIMESTAMP NULL,
    last_transfer_at TIMESTAMP NULL,
    version BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_wallets_user_currency ON wallets(user_id, currency);

CREATE TABLE IF NOT EXISTS ledger_entries (
    id UUID PRIMARY KEY,
    amount BIGINT NOT NULL CHECK (amount > 0),
    currency VARCHAR(20) NOT NULL CHECK (currency IN ('SILVER_SEAL', 'GOLD_SEAL')),
    sender_wallet_id UUID NULL REFERENCES wallets(id),
    receiver_wallet_id UUID NULL REFERENCES wallets(id),
    category VARCHAR(50) NOT NULL,
    reference_id VARCHAR(128) NOT NULL,
    metadata JSONB NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ledger_entries_sender ON ledger_entries(sender_wallet_id);
CREATE INDEX IF NOT EXISTS idx_ledger_entries_receiver ON ledger_entries(receiver_wallet_id);
CREATE INDEX IF NOT EXISTS idx_ledger_entries_reference ON ledger_entries(reference_id);
CREATE INDEX IF NOT EXISTS idx_ledger_entries_created_at ON ledger_entries(created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_ledger_reference_unique ON ledger_entries(reference_id);
