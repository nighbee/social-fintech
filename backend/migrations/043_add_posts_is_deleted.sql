-- Migration: Add posts.is_deleted soft-delete flag
ALTER TABLE posts
    ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_posts_not_deleted_created
    ON posts(created_at DESC)
    WHERE is_deleted = false AND is_archived = false;

COMMENT ON COLUMN posts.is_deleted IS 'Soft delete flag: deleted posts are hidden from all read endpoints.';
