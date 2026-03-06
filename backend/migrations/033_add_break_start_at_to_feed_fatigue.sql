-- Migration 033: Add break_start_at column to feed_fatigue_states
-- Supports the hard-break cycle: 20-min active → 5-min break → reset.
-- NULL means not currently in a break.

ALTER TABLE feed_fatigue_states
    ADD COLUMN IF NOT EXISTS break_start_at TIMESTAMPTZ NULL;

-- Index for background worker that sweeps expired breaks (optional, low priority)
CREATE INDEX IF NOT EXISTS idx_feed_fatigue_break_start_at
    ON feed_fatigue_states (break_start_at)
    WHERE break_start_at IS NOT NULL;
