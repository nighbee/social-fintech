-- Unified moderation reports table for posts/comments
CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_type VARCHAR(20) NOT NULL CHECK (target_type IN ('post', 'comment')),
    target_id UUID NOT NULL,
    reason VARCHAR(30) NOT NULL CHECK (
        reason IN (
            'spam',
            'hate',
            'nudity',
            'violence',
            'illegal',
            'gambling',
            'copyright',
            'fake_account',
            'manipulation'
        )
    ),
    moderation_status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (moderation_status IN ('pending', 'reviewed')),
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Dedup: same reporter cannot report the same target twice.
CREATE UNIQUE INDEX IF NOT EXISTS uq_reports_reporter_target
    ON reports(reporter_id, target_type, target_id);

CREATE INDEX IF NOT EXISTS idx_reports_target
    ON reports(target_type, target_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_reports_status
    ON reports(moderation_status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_reports_reporter_created
    ON reports(reporter_id, created_at DESC);

-- Auto-hide flags used by the feed/comments queries when report threshold is reached.
ALTER TABLE posts
    ADD COLUMN IF NOT EXISTS is_hidden_by_reports BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE post_comments
    ADD COLUMN IF NOT EXISTS is_hidden_by_reports BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_posts_hidden_by_reports
    ON posts(is_hidden_by_reports)
    WHERE is_hidden_by_reports = true;

CREATE INDEX IF NOT EXISTS idx_post_comments_hidden_by_reports
    ON post_comments(is_hidden_by_reports)
    WHERE is_hidden_by_reports = true;
