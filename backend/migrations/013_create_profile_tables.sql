-- 1. Enable PostGIS (REQUIRED for spatial index to work)
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Profiles Table
CREATE TABLE IF NOT EXISTS profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    
    -- Visual Identity (MISSING IN YOUR SCRIPT)
    display_name VARCHAR(100), -- Cached name for fast feed loading
    avatar_url VARCHAR(255),   -- URL to S3/MinIO
    bio TEXT,
    
    -- Location
    location_city VARCHAR(100),
    location_country VARCHAR(100),
    location_lat DECIMAL(10, 8),
    location_lon DECIMAL(11, 8),
    is_location_public BOOLEAN NOT NULL DEFAULT true,
    is_profile_public BOOLEAN NOT NULL DEFAULT true,
    
    -- Cached Stats (Read-heavy optimization)
    total_posts INT NOT NULL DEFAULT 0,
    total_gold_seals_received BIGINT NOT NULL DEFAULT 0, -- RENAMED: Specifically Gold (Status)
    total_silver_seals_given BIGINT NOT NULL DEFAULT 0,  -- RENAMED: Specifically Silver (Generosity)
    tasks_completed INT NOT NULL DEFAULT 0,
    
    -- Gamification / Ranks (MISSING IN YOUR SCRIPT)
    reputation_score INT NOT NULL DEFAULT 0,            -- Numeric score for leaderboards
    current_rank_tier VARCHAR(50) DEFAULT 'Quartz',     -- 'Quartz', 'Clarity', ... 'Sovereign'
    
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Indexes for Profiles
CREATE INDEX IF NOT EXISTS idx_profiles_updated_at ON profiles(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_reputation ON profiles(reputation_score DESC); -- For Leaderboards

-- Spatial index for "People near me" or Feed logic
CREATE INDEX IF NOT EXISTS idx_profiles_location ON profiles 
    USING GIST(ST_SetSRID(ST_MakePoint(location_lon, location_lat), 4326))
    WHERE location_lat IS NOT NULL AND location_lon IS NOT NULL;

-- 3. User Relationships (Allies, Blocks)
CREATE TABLE IF NOT EXISTS user_relationships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,        -- The "Follower"
    target_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, -- The "Target"
    
    -- Added 'ally' (subscription) based on PRD
    relationship_type VARCHAR(20) NOT NULL CHECK (relationship_type IN ('ally', 'favorite', 'block', 'restrict')),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    UNIQUE(user_id, target_user_id, relationship_type),
    CHECK (user_id != target_user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_relationships_user ON user_relationships(user_id, relationship_type);
CREATE INDEX IF NOT EXISTS idx_user_relationships_target ON user_relationships(target_user_id, relationship_type);
CREATE INDEX IF NOT EXISTS idx_user_relationships_created ON user_relationships(created_at DESC);

-- 4. User Reports (Moderation)
CREATE TABLE IF NOT EXISTS user_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reported_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason VARCHAR(50) NOT NULL CHECK (reason IN ('spam', 'harassment', 'inappropriate', 'fake_account', 'other')),
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'dismissed', 'actioned')),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    reviewed_at TIMESTAMP,
    reviewed_by UUID REFERENCES users(id),
    
    CHECK (reporter_id != reported_user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_reports_status ON user_reports(status, created_at DESC);

-- Comments for DB Docs
COMMENT ON TABLE profiles IS 'Extended user profile information including rank, visuals, and cached stats';
COMMENT ON COLUMN profiles.total_gold_seals_received IS 'Accumulated status currency (Gold Seals)';
COMMENT ON COLUMN profiles.current_rank_tier IS 'Current gamification rank (Quartz -> Sovereign)';
