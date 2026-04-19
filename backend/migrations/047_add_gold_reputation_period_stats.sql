-- Migration 047: Gold reputation period stats + ledger query indexes

BEGIN;

CREATE TABLE IF NOT EXISTS gold_reputation_period_stats (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    period_type VARCHAR(20) NOT NULL CHECK (period_type IN ('weekly', 'seasonal')),
    period_year INTEGER NOT NULL,
    period_week INTEGER NOT NULL CHECK (period_week >= 1 AND period_week <= 53),
    gold_received_centinels BIGINT NOT NULL DEFAULT 0,
    computed_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, period_type, period_year, period_week)
);

CREATE INDEX IF NOT EXISTS idx_gold_period_leaderboard
    ON gold_reputation_period_stats (period_type, period_year, period_week, gold_received_centinels DESC);

CREATE INDEX IF NOT EXISTS idx_gold_period_user_lookup
    ON gold_reputation_period_stats (user_id, period_type, period_year, period_week);

CREATE INDEX IF NOT EXISTS idx_ledger_entries_category_created_at
    ON ledger_entries (category, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ledger_entries_metadata_receiver_user_id
    ON ledger_entries ((metadata ->> 'receiver_user_id'));

CREATE INDEX IF NOT EXISTS idx_ledger_entries_metadata_post_id
    ON ledger_entries ((metadata ->> 'post_id'));

COMMIT;
