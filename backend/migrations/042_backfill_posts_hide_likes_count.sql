-- Migration: Backfill Posts Hide Likes Count
-- Description: Ensures posts.hide_likes_count exists on databases where
-- earlier post-controls migrations were marked as applied during bootstrap.

ALTER TABLE posts
    ADD COLUMN IF NOT EXISTS hide_likes_count BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN posts.hide_likes_count IS 'If true, like count is hidden in post responses.';
