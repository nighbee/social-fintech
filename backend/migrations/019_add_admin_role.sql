-- Add admin role to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_users_is_admin ON users(is_admin) WHERE is_admin = true;

COMMENT ON COLUMN users.is_admin IS 'Admin flag for users with elevated privileges (economy adjustments, violations access)';
