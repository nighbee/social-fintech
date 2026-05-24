-- 1. Composite index for cursor pagination on active posts
CREATE INDEX IF NOT EXISTS idx_posts_active_created_id 
    ON posts(created_at DESC, id DESC) 
    WHERE is_archived = false AND is_deleted = false;

-- 2. Partial index on shadow-banned users for high-speed filtration
CREATE INDEX IF NOT EXISTS idx_users_shadow_banned 
    ON users(id) 
    WHERE is_shadow_banned = true;

-- 3. Composite index for checking relationship types
CREATE INDEX IF NOT EXISTS idx_user_relationships_lookup 
    ON user_relationships(user_id, target_user_id, relationship_type);

-- 4. Multi-column index on author strikes for the conditional lookups
CREATE INDEX IF NOT EXISTS idx_author_policy_strikes_reputation 
    ON author_policy_strikes(author_id, strike_type, created_at DESC);
