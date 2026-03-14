-- Migration: Add Post Controls
-- Description: Adds hide_likes_count flag used by feed APIs.

ALTER TABLE posts
    ADD COLUMN IF NOT EXISTS hide_likes_count BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN posts.hide_likes_count IS 'If true, like count is hidden in post responses.';
