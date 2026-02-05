-- Backfill profiles for existing users
INSERT INTO profiles (user_id, is_profile_public, created_at, updated_at)
SELECT id, true, created_at, created_at
FROM users
WHERE NOT EXISTS (SELECT 1 FROM profiles WHERE profiles.user_id = users.id)
ON CONFLICT (user_id) DO NOTHING;

-- Create trigger to auto-create profile when user is created
CREATE OR REPLACE FUNCTION create_profile_for_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (user_id, is_profile_public, created_at, updated_at)
    VALUES (NEW.id, true, NOW(), NOW())
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_create_profile_on_user_insert ON users;

CREATE TRIGGER trigger_create_profile_on_user_insert
AFTER INSERT ON users
FOR EACH ROW
EXECUTE FUNCTION create_profile_for_new_user();
