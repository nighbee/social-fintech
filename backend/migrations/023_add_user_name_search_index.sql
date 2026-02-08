-- Index for name search (case-insensitive)
CREATE INDEX IF NOT EXISTS idx_users_name_search
ON users (LOWER(first_name), LOWER(last_name));
