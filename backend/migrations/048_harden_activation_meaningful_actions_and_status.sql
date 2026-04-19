-- Migration 048:
-- 1) Add explicit "suspicious" activation state.
-- 2) Harden meaningful_actions_count against farming by counting only high-signal actions
--    with source-level deduplication.

BEGIN;

-- 1) Activation status: allow suspicious.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_users_activation_status'
    ) THEN
        ALTER TABLE users DROP CONSTRAINT chk_users_activation_status;
    END IF;

    ALTER TABLE users
        ADD CONSTRAINT chk_users_activation_status
        CHECK (activation_status IN ('restricted', 'suspicious', 'active'));
END
$$;

-- 2) High-signal action dedup store.
CREATE TABLE IF NOT EXISTS user_activation_meaningful_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action_type VARCHAR(64) NOT NULL,
    source_id VARCHAR(128) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, action_type, source_id)
);

CREATE INDEX IF NOT EXISTS idx_user_activation_meaningful_actions_user_created
    ON user_activation_meaningful_actions(user_id, created_at DESC);

-- 3) Single recording function with dedup semantics.
CREATE OR REPLACE FUNCTION record_meaningful_action(actor_user_id UUID, in_action_type TEXT, in_source_id TEXT)
RETURNS VOID AS $$
DECLARE
    inserted_rows INTEGER := 0;
BEGIN
    IF actor_user_id IS NULL OR in_action_type IS NULL OR in_source_id IS NULL THEN
        RETURN;
    END IF;

    INSERT INTO user_activation_meaningful_actions (user_id, action_type, source_id, created_at)
    VALUES (actor_user_id, in_action_type, in_source_id, NOW())
    ON CONFLICT (user_id, action_type, source_id) DO NOTHING;

    GET DIAGNOSTICS inserted_rows = ROW_COUNT;
    IF inserted_rows = 0 THEN
        RETURN;
    END IF;

    INSERT INTO user_activation_activity (user_id, meaningful_actions_count, updated_at)
    VALUES (actor_user_id, 1, NOW())
    ON CONFLICT (user_id) DO UPDATE
    SET meaningful_actions_count = user_activation_activity.meaningful_actions_count + 1,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- 4) Replace broad triggers from migration 046 (easy to farm).
DROP TRIGGER IF EXISTS trg_posts_meaningful_action ON posts;
DROP TRIGGER IF EXISTS trg_comments_meaningful_action ON post_comments;
DROP TRIGGER IF EXISTS trg_tasks_meaningful_action ON tasks;

-- 5) Meaningful source: post with media (dedup by post_id).
CREATE OR REPLACE FUNCTION trg_post_media_meaningful_action()
RETURNS TRIGGER AS $$
DECLARE
    actor UUID;
BEGIN
    SELECT p.user_id INTO actor
    FROM posts p
    WHERE p.id = NEW.post_id;

    PERFORM record_meaningful_action(actor, 'post_with_media', NEW.post_id::text);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_post_media_meaningful_action ON post_media;
CREATE TRIGGER trg_post_media_meaningful_action
AFTER INSERT ON post_media
FOR EACH ROW
EXECUTE FUNCTION trg_post_media_meaningful_action();

-- 6) Meaningful source: task completion confirmed (dedup by application_id).
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'task_applications'
    ) THEN
        CREATE OR REPLACE FUNCTION trg_task_application_confirmed_meaningful_action()
        RETURNS TRIGGER AS $fn$
        BEGIN
            IF NEW.status = 'confirmed' AND (OLD.status IS DISTINCT FROM NEW.status) THEN
                PERFORM record_meaningful_action(NEW.applicant_id::uuid, 'task_confirmed', NEW.id::text);
            END IF;
            RETURN NEW;
        END;
        $fn$ LANGUAGE plpgsql;

        DROP TRIGGER IF EXISTS trg_task_application_confirmed_meaningful_action ON task_applications;
        CREATE TRIGGER trg_task_application_confirmed_meaningful_action
        AFTER UPDATE ON task_applications
        FOR EACH ROW
        EXECUTE FUNCTION trg_task_application_confirmed_meaningful_action();
    END IF;
END
$$;

-- 7) Meaningful source: real outbound seal transfer (dedup by ledger entry id).
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'ledger_entries'
    ) THEN
        CREATE OR REPLACE FUNCTION trg_ledger_transfer_meaningful_action()
        RETURNS TRIGGER AS $fn$
        DECLARE
            sender_user_id UUID;
        BEGIN
            -- sender_wallet_id identifies the action performer for transfer-like actions.
            IF NEW.sender_wallet_id IS NULL THEN
                RETURN NEW;
            END IF;

            IF NEW.category NOT IN ('transfer', 'gift', 'task_completion') THEN
                RETURN NEW;
            END IF;

            SELECT w.user_id INTO sender_user_id
            FROM wallets w
            WHERE w.id = NEW.sender_wallet_id;

            PERFORM record_meaningful_action(sender_user_id, 'seal_sent', NEW.id::text);
            RETURN NEW;
        END;
        $fn$ LANGUAGE plpgsql;

        DROP TRIGGER IF EXISTS trg_ledger_transfer_meaningful_action ON ledger_entries;
        CREATE TRIGGER trg_ledger_transfer_meaningful_action
        AFTER INSERT ON ledger_entries
        FOR EACH ROW
        EXECUTE FUNCTION trg_ledger_transfer_meaningful_action();
    END IF;
END
$$;

COMMIT;

