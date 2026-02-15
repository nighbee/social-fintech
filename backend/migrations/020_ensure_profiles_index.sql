-- Profiles table (Epic 2)
-- Note: This table was already created in 013_create_profile_tables.sql
-- This migration is kept for compatibility but won't recreate the table

-- Ensure the index exists with the correct column name
CREATE INDEX IF NOT EXISTS idx_profiles_public ON profiles(is_profile_public);
