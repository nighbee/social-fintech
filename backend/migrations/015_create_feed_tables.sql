-- Migration: Create Feed/Posts Tables
-- Description: Creates posts, post_media, comments, and post_interactions tables

-- Posts table
CREATE TABLE IF NOT EXISTS posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    caption TEXT,
    location_city VARCHAR(100),
    location_country VARCHAR(100),
    location_lat DECIMAL(10, 8),
    location_lon DECIMAL(11, 8),
    
    -- Visibility and status
    is_public BOOLEAN NOT NULL DEFAULT true,
    is_archived BOOLEAN NOT NULL DEFAULT false,
    
    -- Statistics (cached, updated by triggers/workers)
    likes_count INT NOT NULL DEFAULT 0,
    comments_count INT NOT NULL DEFAULT 0,
    seals_count INT NOT NULL DEFAULT 0,
    seals_amount BIGINT NOT NULL DEFAULT 0,
    
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Indexes for posts
CREATE INDEX idx_posts_user_id ON posts(user_id, created_at DESC);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC) WHERE is_archived = false;
CREATE INDEX idx_posts_location ON posts 
    USING GIST(ST_SetSRID(ST_MakePoint(location_lon, location_lat), 4326))
    WHERE location_lat IS NOT NULL AND location_lon IS NOT NULL AND is_archived = false;

-- Post media items (images/videos) - support up to 10 per post
CREATE TABLE IF NOT EXISTS post_media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    media_type VARCHAR(20) NOT NULL CHECK (media_type IN ('image', 'video')),
    media_url TEXT NOT NULL,
    thumbnail_url TEXT,
    media_order INT NOT NULL,
    width INT,
    height INT,
    duration_seconds INT,  -- For videos
    file_size_bytes BIGINT,
    mime_type VARCHAR(50),
    
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    CHECK (media_order >= 0 AND media_order < 10),
    UNIQUE(post_id, media_order)
);

CREATE INDEX idx_post_media_post_id ON post_media(post_id, media_order);

-- Comments on posts
CREATE TABLE IF NOT EXISTS post_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    parent_comment_id UUID REFERENCES post_comments(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    CHECK (LENGTH(content) > 0 AND LENGTH(content) <= 2000)
);

CREATE INDEX idx_post_comments_post_id ON post_comments(post_id, created_at DESC) WHERE is_deleted = false;
CREATE INDEX idx_post_comments_user_id ON post_comments(user_id, created_at DESC);
CREATE INDEX idx_post_comments_parent ON post_comments(parent_comment_id) WHERE parent_comment_id IS NOT NULL;

-- Post interactions (likes, seals given)
CREATE TABLE IF NOT EXISTS post_interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    interaction_type VARCHAR(20) NOT NULL CHECK (interaction_type IN ('like', 'seal')),
    seal_amount BIGINT,  -- NULL for likes, amount for seals
    
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    UNIQUE(post_id, user_id, interaction_type)
);

CREATE INDEX idx_post_interactions_post ON post_interactions(post_id, interaction_type);
CREATE INDEX idx_post_interactions_user ON post_interactions(user_id, created_at DESC);

-- Comments
COMMENT ON TABLE posts IS 'User posts with optional media attachments';
COMMENT ON TABLE post_media IS 'Media items (images/videos) attached to posts, max 10 per post';
COMMENT ON TABLE post_comments IS 'Comments on posts, supports threading via parent_comment_id';
COMMENT ON TABLE post_interactions IS 'User interactions with posts (likes, seals)';
COMMENT ON COLUMN post_media.media_order IS 'Display order, 0-9, enforces 10 item limit';
COMMENT ON COLUMN posts.seals_count IS 'Number of times seals were given to this post';
COMMENT ON COLUMN posts.seals_amount IS 'Total amount of seals given to this post';
