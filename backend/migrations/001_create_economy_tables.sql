    -- =============================================
    -- BrightBund Economy Schema (Production MVP)
    -- Author: Almaz Team Architect
    -- Description: Core Economy, Wallets, Ledger, and Referrals
    -- =============================================

    -- 1. Setup Extensions
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

    -- 2. Define Enums (Strict Typing)
    -- Prevents "magic strings" and ensures data consistency.
    DROP TYPE IF EXISTS currency_code CASCADE;
    CREATE TYPE currency_code AS ENUM (
        'SILVER_SEAL',  -- Earned / Free Currency
        'GOLD_SEAL'     -- Paid / Premium Currency
    );

    DROP TYPE IF EXISTS transaction_category CASCADE;
    CREATE TYPE transaction_category AS ENUM (
        'DAILY_ACCRUAL',   -- The free 0.50 Silver (subject to max 5 limit)
        'REFERRAL_BONUS',  -- The +1.00 Silver for inviting
        'P2P_TRANSFER',    -- Sending money to another user
        'TASK_CREATION',   -- Spending Silver to create a map task
        'IAP_DEPOSIT',     -- Bought via Apple/Google
        'SYSTEM_CORRECTION', -- Admin manual adjustment
        'TASK_REWARD'      -- Earning for completing a task
    );

    -- =============================================
    -- 3. Wallets (The Current State)
    -- =============================================
    CREATE TABLE IF NOT EXISTS wallets (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        user_id UUID NOT NULL, 
        currency currency_code NOT NULL,
        
        -- BALANCE: Stored in Centinels (Integers). 
        -- 1.00 Seal = 100 Centinels.
        -- 0.50 Seal = 50 Centinels.
        balance BIGINT NOT NULL DEFAULT 0,

        -- CRITICAL: Separate tracking for "free" silver (from daily accruals)
        -- This enforces the "max 5 free silver" cap while allowing unlimited purchased silver
        -- Only applies to SILVER_SEAL currency (ignored for GOLD_SEAL)
        free_balance BIGINT NOT NULL DEFAULT 0 CHECK (free_balance >= 0 AND free_balance <= 500),

        -- Daily accrual tracking (CRITICAL for background worker)
        -- NULL = never received accrual. Worker checks: "Is last_daily_accrual_at < today?"
        last_daily_accrual_at TIMESTAMP WITH TIME ZONE,

        -- OPTIMISTIC LOCKING:
        -- Incremented on every update. Prevents race conditions.
        -- App logic: "UPDATE wallets SET balance = x, version = version + 1 WHERE id = y AND version = current_version"
        version BIGINT NOT NULL DEFAULT 0,

        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

        -- Constraints:
        -- 1. A user has exactly one wallet per currency type.
        CONSTRAINT unique_user_currency UNIQUE(user_id, currency),
        -- 2. Balance can never be negative (Database-level safety).
        CONSTRAINT positive_balance CHECK (balance >= 0)
    );

    -- Function to auto-update 'updated_at' timestamp
    CREATE OR REPLACE FUNCTION update_timestamp()
    RETURNS TRIGGER AS $$
    BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
    END;
    $$ language 'plpgsql';

    CREATE TRIGGER update_wallets_timestamp
    BEFORE UPDATE ON wallets
    FOR EACH ROW EXECUTE PROCEDURE update_timestamp();

    -- Indexes for Wallets
    CREATE INDEX idx_wallets_lookup ON wallets(user_id, currency);
    CREATE INDEX idx_wallets_accrual ON wallets(last_daily_accrual_at) WHERE currency = 'SILVER_SEAL';

    -- =============================================
    -- 4. Ledger Entries (The Immutable History)
    -- =============================================
    CREATE TABLE IF NOT EXISTS ledger_entries (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        
        -- Money Flow
        amount BIGINT NOT NULL CHECK (amount > 0), -- Always positive (in centinels)
        currency currency_code NOT NULL,
        
        -- Sender (NULL if minted by System/Air)
        sender_wallet_id UUID REFERENCES wallets(id),
        
        -- Receiver (NULL if burnt/destroyed by System)
        receiver_wallet_id UUID REFERENCES wallets(id),
        
        -- Categorization
        category transaction_category NOT NULL,
        
        -- IDEMPOTENCY KEY (CRITICAL):
        -- The application MUST generate a unique string for every action.
        -- Example: "daily_accrual_user123_2026-01-22" or "apple_receipt_xyz"
        -- This prevents the same payment from being processed twice.
        reference_id VARCHAR(255) NOT NULL,
        
        -- Metadata:
        -- Store context like {"task_id": "...", "referee_id": "...", "post_id": "..."}
        metadata JSONB DEFAULT '{}'::JSONB,
        
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

        -- Constraints:
        -- 1. Ensure a reference ID is used only once (Double-Spend Protection)
        CONSTRAINT unique_reference_id UNIQUE(reference_id),
        -- 2. Sender and Receiver cannot be the same wallet
        CONSTRAINT different_wallets CHECK (sender_wallet_id != receiver_wallet_id OR sender_wallet_id IS NULL OR receiver_wallet_id IS NULL)
    );

    -- Indexes for Ledger
    CREATE INDEX idx_ledger_sender ON ledger_entries(sender_wallet_id);
    CREATE INDEX idx_ledger_receiver ON ledger_entries(receiver_wallet_id);
    CREATE INDEX idx_ledger_category ON ledger_entries(category);
    CREATE INDEX idx_ledger_created_at ON ledger_entries(created_at DESC);

    -- =============================================
    -- 5. Referrals (The Growth Graph)
    -- =============================================
    CREATE TABLE IF NOT EXISTS referrals (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        
        -- User A (Existing user who gets the +1 Silver)
        referrer_user_id UUID NOT NULL, 
        
        -- User B (New user who just registered)
        referee_user_id UUID NOT NULL,
        
        -- Bonus tracking (links to ledger_entries)
        bonus_ledger_entry_id UUID REFERENCES ledger_entries(id),
        
        -- Status (Useful if you need to ban bots later)
        is_active BOOLEAN DEFAULT TRUE,
        
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

        -- Constraints:
        -- 1. A new user (referee) can only be referred ONCE in their life.
        CONSTRAINT unique_referee_referral UNIQUE(referee_user_id)
    );

    -- Index for analytics (How many people did User A invite?)
    CREATE INDEX idx_referrals_referrer ON referrals(referrer_user_id);

    -- =============================================
    -- 6. Anti-Abuse: Monthly Transfer Limits
    -- =============================================
    CREATE TABLE IF NOT EXISTS transfer_limits (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        user_id UUID NOT NULL,
        
        -- Month tracking (e.g., '2026-01')
        month_year VARCHAR(7) NOT NULL,
        
        -- Count and volume of P2P transfers this month
        transfers_count INT NOT NULL DEFAULT 0,
        total_sent_centinels BIGINT NOT NULL DEFAULT 0,
        
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        
        -- Constraints:
        CONSTRAINT unique_user_month UNIQUE(user_id, month_year)
    );

    CREATE INDEX idx_transfer_limits_lookup ON transfer_limits(user_id, month_year);

    -- =============================================
    -- 7. Documentation Comments
    -- =============================================
    COMMENT ON TABLE wallets IS 'Stores current state of user funds. Normalized (1 row per currency). Protected by Versioning.';
    COMMENT ON COLUMN wallets.balance IS 'Total balance stored in centinels. 100 = 1.00 Seal. Includes free + purchased.';
    COMMENT ON COLUMN wallets.free_balance IS 'Portion of balance from daily accruals (max 500 = 5.00 Seals). Only for SILVER_SEAL.';
    COMMENT ON COLUMN wallets.last_daily_accrual_at IS 'Timestamp of last daily accrual. Worker checks if < today to grant 0.5 silver.';
    COMMENT ON TABLE ledger_entries IS 'Immutable log of all financial movements. Source of Truth.';
    COMMENT ON COLUMN ledger_entries.reference_id IS 'Unique key provided by app/client to prevent double-spending.';
    COMMENT ON TABLE referrals IS 'Tracks who invited whom. Used to award the Referral Bonus.';
    COMMENT ON TABLE transfer_limits IS 'Anti-abuse: Tracks P2P transfer volume per user per month.';
