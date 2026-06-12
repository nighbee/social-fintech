-- Phase 1 feed optimization indexes.
-- 1. Covering index for author rank lookups (avoids heap fetch on every feed/comment query).
CREATE INDEX IF NOT EXISTS idx_wallets_rank
    ON wallets (user_id, currency)
    INCLUDE (total_received_amount);

-- 2. Extend the existing feed cursor index to also exclude hidden posts.
-- Drop the old one if it was created by 072 (it might not include is_hidden_by_reports).
DROP INDEX IF EXISTS idx_posts_active_created_id;
CREATE INDEX idx_posts_feed_cursor
    ON posts (created_at DESC, id DESC)
    WHERE is_archived = false AND is_deleted = false AND is_hidden_by_reports = false;

-- 3. Composite index for the ally visibility check used in feed/profile queries.
CREATE INDEX IF NOT EXISTS idx_posts_user_visible
    ON posts (user_id)
    WHERE is_archived = false AND is_deleted = false;
