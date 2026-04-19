-- Backfill/repair migration for feed moderation controls used by smart feed.

-- Posts-level moderation controls
ALTER TABLE posts
    ADD COLUMN IF NOT EXISTS report_control_level INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS distribution_multiplier DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    ADD COLUMN IF NOT EXISTS is_hidden_by_reports BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS impressions_count BIGINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS moderation_queue_at TIMESTAMP NULL;

CREATE INDEX IF NOT EXISTS idx_posts_report_control_level
    ON posts(report_control_level);

CREATE INDEX IF NOT EXISTS idx_posts_moderation_queue_at
    ON posts(moderation_queue_at);

ALTER TABLE post_comments
    ADD COLUMN IF NOT EXISTS is_hidden_by_reports BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_posts_hidden_by_reports
    ON posts(is_hidden_by_reports)
    WHERE is_hidden_by_reports = true;

CREATE INDEX IF NOT EXISTS idx_post_comments_hidden_by_reports
    ON post_comments(is_hidden_by_reports)
    WHERE is_hidden_by_reports = true;

-- Reports table baseline (safety net if 039 was skipped/marked only)
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

CREATE UNIQUE INDEX IF NOT EXISTS uq_reports_reporter_target
    ON reports(reporter_id, target_type, target_id);

CREATE INDEX IF NOT EXISTS idx_reports_target
    ON reports(target_type, target_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_reports_status
    ON reports(moderation_status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_reports_reporter_created
    ON reports(reporter_id, created_at DESC);

-- Extended report review state
ALTER TABLE reports
    ADD COLUMN IF NOT EXISTS review_decision VARCHAR(20) NULL,
    ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMP NULL,
    ADD COLUMN IF NOT EXISTS reputation_applied BOOLEAN NOT NULL DEFAULT false;

-- Reporter quality/reputation
CREATE TABLE IF NOT EXISTS reporter_reputation (
    reporter_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    accepted_reports_count INTEGER NOT NULL DEFAULT 0,
    rejected_reports_count INTEGER NOT NULL DEFAULT 0,
    consecutive_rejected_count INTEGER NOT NULL DEFAULT 0,
    reputation_multiplier DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Author policy strikes for moderation escalation
CREATE TABLE IF NOT EXISTS author_policy_strikes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    report_id UUID NULL REFERENCES reports(id) ON DELETE SET NULL,
    strike_type VARCHAR(40) NOT NULL,
    expires_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_author_policy_strikes_author_created
    ON author_policy_strikes(author_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_author_policy_strikes_expires
    ON author_policy_strikes(expires_at);

-- Per-reporter post hides (safety net if older migration didn't run)
CREATE TABLE IF NOT EXISTS reported_post_hides (
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (reporter_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_reported_post_hides_reporter_created
    ON reported_post_hides (reporter_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_reported_post_hides_post
    ON reported_post_hides (post_id);
