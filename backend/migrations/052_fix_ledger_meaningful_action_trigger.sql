-- Migration: 052_fix_ledger_meaningful_action_trigger.sql
-- Fixes a bug where the trigger attempted to cast non-existent string literals 
-- ('gift', 'task_completion') into the transaction_category ENUM type, 
-- causing 500 errors on all ledger inserts (like creating a task).

BEGIN;

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

            -- FIX: Use actual valid transaction_category ENUM values
            -- 'P2P_TRANSFER' and 'transfer' (legacy) for giving seals.
            -- 'POST_SEAL' for gifting a seal to a post.
            IF NEW.category NOT IN ('P2P_TRANSFER', 'transfer', 'POST_SEAL') THEN
                RETURN NEW;
            END IF;

            SELECT w.user_id INTO sender_user_id
            FROM wallets w
            WHERE w.id = NEW.sender_wallet_id;

            PERFORM record_meaningful_action(sender_user_id, 'seal_sent', NEW.id::text);
            RETURN NEW;
        END;
        $fn$ LANGUAGE plpgsql;
    END IF;
END
$$;

COMMIT;
