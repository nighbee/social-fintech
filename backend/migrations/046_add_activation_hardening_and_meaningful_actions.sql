-- Migration 046: Activation hardening + meaningful action tracking
-- Ensures runtime activation/referral checks have required schema.

BEGIN;

-- 1) Users activation fields used by auth/economy runtime
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS activation_status VARCHAR(20) NOT NULL DEFAULT 'restricted',
    ADD COLUMN IF NOT EXISTS activation_unlocked_at TIMESTAMP NULL,
    ADD COLUMN IF NOT EXISTS restrictions_until TIMESTAMP NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_users_activation_status'
    ) THEN
        ALTER TABLE users
            ADD CONSTRAINT chk_users_activation_status
            CHECK (activation_status IN ('restricted', 'active'));
    END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_users_activation_status ON users(activation_status);
CREATE INDEX IF NOT EXISTS idx_users_restrictions_until ON users(restrictions_until);

-- 2) Registration anti-farm daily signals
CREATE TABLE IF NOT EXISTS device_registration_stats (
    device_id VARCHAR(255) NOT NULL,
    stat_date DATE NOT NULL,
    registrations_count INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (device_id, stat_date)
);

CREATE TABLE IF NOT EXISTS ip_registration_stats (
    ip_address VARCHAR(64) NOT NULL,
    stat_date DATE NOT NULL,
    registrations_count INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (ip_address, stat_date)
);

-- 3) Activation progress tracking
CREATE TABLE IF NOT EXISTS user_activation_activity (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    distinct_login_days INTEGER NOT NULL DEFAULT 0,
    login_events_count INTEGER NOT NULL DEFAULT 0,
    meaningful_actions_count INTEGER NOT NULL DEFAULT 0,
    last_login_date DATE NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_activation_activity_updated_at
    ON user_activation_activity(updated_at DESC);

-- Backfill rows for existing users to prevent NULL runtime lookups.
INSERT INTO user_activation_activity (user_id)
SELECT u.id
FROM users u
LEFT JOIN user_activation_activity a ON a.user_id = u.id
WHERE a.user_id IS NULL;

-- 4) Auto-create activation activity row on new user
CREATE OR REPLACE FUNCTION init_user_activation_activity_row()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_activation_activity (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_init_user_activation_activity ON users;
CREATE TRIGGER trg_init_user_activation_activity
AFTER INSERT ON users
FOR EACH ROW
EXECUTE FUNCTION init_user_activation_activity_row();

-- 5) Meaningful-actions counter increment helper
CREATE OR REPLACE FUNCTION increment_meaningful_actions(actor_user_id UUID)
RETURNS VOID AS $$
BEGIN
    IF actor_user_id IS NULL THEN
        RETURN;
    END IF;

    INSERT INTO user_activation_activity (user_id, meaningful_actions_count, updated_at)
    VALUES (actor_user_id, 1, NOW())
    ON CONFLICT (user_id) DO UPDATE
    SET meaningful_actions_count = user_activation_activity.meaningful_actions_count + 1,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- 6) Trigger meaningful actions from core product behavior
CREATE OR REPLACE FUNCTION trg_posts_meaningful_action()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM increment_meaningful_actions(NEW.user_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_posts_meaningful_action ON posts;
CREATE TRIGGER trg_posts_meaningful_action
AFTER INSERT ON posts
FOR EACH ROW
EXECUTE FUNCTION trg_posts_meaningful_action();

CREATE OR REPLACE FUNCTION trg_comments_meaningful_action()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM increment_meaningful_actions(NEW.user_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_comments_meaningful_action ON post_comments;
CREATE TRIGGER trg_comments_meaningful_action
AFTER INSERT ON post_comments
FOR EACH ROW
EXECUTE FUNCTION trg_comments_meaningful_action();

CREATE OR REPLACE FUNCTION trg_tasks_meaningful_action()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM increment_meaningful_actions(NEW.creator_id::uuid);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_tasks_meaningful_action ON tasks;
CREATE TRIGGER trg_tasks_meaningful_action
AFTER INSERT ON tasks
FOR EACH ROW
EXECUTE FUNCTION trg_tasks_meaningful_action();

COMMIT;
