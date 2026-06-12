-- Phase 2 feed optimization: pre-computed strike count with trigger.
-- This eliminates the per-row LATERAL subquery in GetSmartFeed (previously ran 200+ per feed request).

-- Add column.
ALTER TABLE posts
    ADD COLUMN IF NOT EXISTS current_strike_count INTEGER NOT NULL DEFAULT 0;

-- Function to update current_strike_count when author_policy_strikes change.
CREATE OR REPLACE FUNCTION update_post_strike_counts()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        UPDATE posts
        SET current_strike_count = (
            SELECT COUNT(1)
            FROM author_policy_strikes aps
            WHERE aps.author_id = posts.user_id
              AND aps.strike_type IN ('post_removed', 'comment_removed', 'content_violation')
              AND aps.created_at >= NOW() - INTERVAL '30 days'
        )
        WHERE user_id = OLD.author_id;
        RETURN OLD;
    END IF;

    UPDATE posts
    SET current_strike_count = (
        SELECT COUNT(1)
        FROM author_policy_strikes aps
        WHERE aps.author_id = posts.user_id
          AND aps.strike_type IN ('post_removed', 'comment_removed', 'content_violation')
          AND aps.created_at >= NOW() - INTERVAL '30 days'
    )
    WHERE user_id = NEW.author_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop if exists to make migration idempotent.
DROP TRIGGER IF EXISTS trg_update_post_strike_counts ON author_policy_strikes;

CREATE TRIGGER trg_update_post_strike_counts
    AFTER INSERT OR UPDATE OR DELETE ON author_policy_strikes
    FOR EACH ROW EXECUTE FUNCTION update_post_strike_counts();

-- Backfill existing data.
UPDATE posts
SET current_strike_count = (
    SELECT COUNT(1)
    FROM author_policy_strikes aps
    WHERE aps.author_id = posts.user_id
      AND aps.strike_type IN ('post_removed', 'comment_removed', 'content_violation')
      AND aps.created_at >= NOW() - INTERVAL '30 days'
);
