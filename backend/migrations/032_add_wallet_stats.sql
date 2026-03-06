-- +goose Up
ALTER TABLE wallets ADD COLUMN total_sent_amount BIGINT NOT NULL DEFAULT 0;
ALTER TABLE wallets ADD COLUMN total_received_amount BIGINT NOT NULL DEFAULT 0;

-- Backfill from current ledger_entries
UPDATE wallets w
SET total_sent_amount = COALESCE((SELECT SUM(amount) FROM ledger_entries WHERE sender_wallet_id = w.id), 0),
    total_received_amount = COALESCE((SELECT SUM(amount) FROM ledger_entries WHERE receiver_wallet_id = w.id), 0);

-- Optional: skip adding goose downs since migrate mechanism doesn't support undo.

