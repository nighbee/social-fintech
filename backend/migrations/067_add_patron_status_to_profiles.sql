-- Migration: Add Patron Status to Profiles
-- Description: Adds is_patron flag to profiles table

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_patron BOOLEAN NOT NULL DEFAULT false;

-- Index for filtering/finding patrons
CREATE INDEX IF NOT EXISTS idx_profiles_is_patron ON profiles(is_patron) WHERE is_patron = true;

COMMENT ON COLUMN profiles.is_patron IS 'Flag indicating if the user has a Patron Badge (Premium status)';
