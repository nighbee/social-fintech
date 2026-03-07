-- Migration 034: Add accumulated_break_seconds to feed_fatigue_states
-- Purpose: Track off-feed break time separately so the break countdown only
--          runs while the user is away from the feed, not on wall-clock time.

ALTER TABLE feed_fatigue_states
    ADD COLUMN IF NOT EXISTS accumulated_break_seconds INTEGER NOT NULL DEFAULT 0;

COMMENT ON COLUMN feed_fatigue_states.accumulated_break_seconds IS
    'Seconds the user has spent OFF the feed during the current break phase. '
    'Break resolves when this reaches 300 (BreakDurationSeconds). '
    'Resets to 0 whenever a new break starts or the full state resets.';
