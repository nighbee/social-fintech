-- Migration: Create Comment Likes and Threading Fixes
-- Description: Adds comment_interactions, likes_count, and root_comment_id columns

-- Add interactions table for comments
CREATE TABLE IF NOT EXISTS comment_interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comment_id UUID NOT NULL REFERENCES post_comments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    interaction_type VARCHAR(20) NOT NULL CHECK (interaction_type IN ('like')),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    UNIQUE(comment_id, user_id, interaction_type)
);

CREATE INDEX IF NOT EXISTS idx_comment_interactions_comment ON comment_interactions(comment_id, interaction_type);
CREATE INDEX IF NOT EXISTS idx_comment_interactions_user ON comment_interactions(user_id, created_at DESC);

-- Enhance Comments Table
ALTER TABLE post_comments
    ADD COLUMN IF NOT EXISTS likes_count INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS root_comment_id UUID REFERENCES post_comments(id) ON DELETE CASCADE;

-- Backfill root_comment_id for existing shallow replies
UPDATE post_comments 
SET root_comment_id = parent_comment_id 
WHERE parent_comment_id IS NOT NULL AND root_comment_id IS NULL;

-- Comments
COMMENT ON TABLE comment_interactions IS 'User interactions with comments (likes)';
COMMENT ON COLUMN post_comments.likes_count IS 'Number of likes received by this comment';
COMMENT ON COLUMN post_comments.root_comment_id IS 'Points to top-level comment to support threading logic';
