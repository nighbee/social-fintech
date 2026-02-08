ALTER TABLE wallets 
ADD COLUMN last_transfer_at TIMESTAMP WITH TIME ZONE;

CREATE INDEX idx_wallets_last_transfer ON wallets(last_transfer_at) WHERE last_transfer_at IS NOT NULL;

COMMENT ON COLUMN wallets.last_transfer_at IS 'Timestamp of last P2P transfer for cooldown enforcement';
