-- Migration: Create reporter-specific hidden posts mapping
-- Description: Hides reported posts from the reporting user's feed immediately.

CREATE TABLE IF NOT EXISTS reported_post_hides (
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (reporter_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_reported_post_hides_reporter_created
    ON reported_post_hides (reporter_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_reported_post_hides_post
    ON reported_post_hides (post_id);
