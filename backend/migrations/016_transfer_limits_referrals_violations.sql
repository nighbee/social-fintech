-- Transfer limits + referrals + violations (per code)

CREATE TABLE IF NOT EXISTS transfer_limits (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    month_year VARCHAR(7) NOT NULL,
    transfers_count INT NOT NULL DEFAULT 0,
    total_sent_centinels BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_transfer_limits_user_month ON transfer_limits(user_id, month_year);

CREATE TABLE IF NOT EXISTS referrals (
    id UUID PRIMARY KEY,
    referrer_user_id UUID NOT NULL,
    referee_user_id UUID NOT NULL UNIQUE,
    bonus_ledger_entry_id UUID NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- economy_violations table is created in 012_create_economy_violations_table.sql
