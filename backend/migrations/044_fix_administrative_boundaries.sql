-- Migration 044_fix: Ensure administrative_boundaries has required columns
-- This handles cases where the table might have been created without these columns in earlier development versions.

ALTER TABLE administrative_boundaries
  ADD COLUMN IF NOT EXISTS country_code VARCHAR(10),
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NOT NULL DEFAULT NOW();
