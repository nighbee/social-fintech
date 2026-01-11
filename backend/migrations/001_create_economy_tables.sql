-- Migration: Create Economy Tables
-- Description: Creates wallets and ledger_entries tables for double-entry bookkeeping

CREATE TABLE IF NOT EXISTS wallets (
    user_id UUID PRIMARY KEY,
    silver_balance BIGINT NOT NULL DEFAULT 0 CHECK (silver_balance >= 0),
    gold_balance BIGINT NOT NULL DEFAULT 0 CHECK (gold_balance >= 0),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_wallets_updated_at ON wallets(updated_at);

CREATE TABLE IF NOT EXISTS ledger_entries (
    id UUID PRIMARY KEY,
    transaction_id UUID NOT NULL,
    account_id UUID NOT NULL,
    amount BIGINT NOT NULL CHECK (amount > 0),
    currency VARCHAR(10) NOT NULL CHECK (currency IN ('SILVER', 'GOLD')),
    type VARCHAR(10) NOT NULL CHECK (type IN ('DEBIT', 'CREDIT')),
    reason VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ledger_entries_transaction_id ON ledger_entries(transaction_id);
CREATE INDEX idx_ledger_entries_account_id ON ledger_entries(account_id);
CREATE INDEX idx_ledger_entries_created_at ON ledger_entries(created_at DESC);
CREATE INDEX idx_ledger_entries_account_created ON ledger_entries(account_id, created_at DESC);

CREATE INDEX idx_ledger_entries_tx_account ON ledger_entries(transaction_id, account_id);

COMMENT ON TABLE wallets IS 'User wallets storing silver and gold balances';
COMMENT ON TABLE ledger_entries IS 'Double-entry ledger for all economic transactions';

COMMENT ON COLUMN wallets.silver_balance IS 'Silver seal balance (cannot be negative)';
COMMENT ON COLUMN wallets.gold_balance IS 'Gold seal balance (cannot be negative)';
COMMENT ON COLUMN ledger_entries.transaction_id IS 'Groups debit and credit entries together';
COMMENT ON COLUMN ledger_entries.type IS 'DEBIT removes from account, CREDIT adds to account';
