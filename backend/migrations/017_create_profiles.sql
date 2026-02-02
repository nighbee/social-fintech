-- Profiles table (Epic 2)
CREATE TABLE IF NOT EXISTS profiles (
    user_id UUID PRIMARY KEY,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    bio VARCHAR(500),
    avatar_url VARCHAR(500),
    country VARCHAR(100),
    region VARCHAR(100),
    city VARCHAR(100),
    is_public BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_profiles_public ON profiles(is_public);
