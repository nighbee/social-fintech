-- Migration: Enhance Feed Tables
-- Description: Adds Feed Fatigue state, privacy settings to posts, and media to comments.

-- 1. Create Feed Fatigue State Table
CREATE TABLE IF NOT EXISTS feed_fatigue_states (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    accumulated_active_seconds INTEGER NOT NULL DEFAULT 0,
    last_sync_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    is_in_cooldown BOOLEAN NOT NULL DEFAULT false
);

-- 2. Enhance Posts Table
ALTER TABLE posts
    ADD COLUMN IF NOT EXISTS visibility VARCHAR(20) NOT NULL DEFAULT 'ANYONE' CHECK (visibility IN ('ANYONE', 'ALLIES_ONLY')),
    ADD COLUMN IF NOT EXISTS comment_permission VARCHAR(20) NOT NULL DEFAULT 'ANYONE' CHECK (comment_permission IN ('ANYONE', 'ALLIES_ONLY', 'NO_ONE')),
    ADD COLUMN IF NOT EXISTS share_count INT NOT NULL DEFAULT 0;

-- 3. Enhance Comments Table
ALTER TABLE post_comments
    ADD COLUMN IF NOT EXISTS media_attachment JSONB;

-- Comments
COMMENT ON TABLE feed_fatigue_states IS 'Tracks user active feed time for Anti-Doomscroll limits';
COMMENT ON COLUMN posts.visibility IS 'ANYONE or ALLIES_ONLY visibility control';
COMMENT ON COLUMN posts.comment_permission IS 'ANYONE, ALLIES_ONLY, or NO_ONE comment control';
COMMENT ON COLUMN post_comments.media_attachment IS 'Optional single media object: {"type": "image", "url": "..."}';
