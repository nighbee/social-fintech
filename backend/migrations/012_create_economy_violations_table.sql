CREATE TABLE IF NOT EXISTS economy_violations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    violation_type VARCHAR(50) NOT NULL,
    amount_attempted BIGINT,
    details JSONB DEFAULT '{}'::JSONB,
    ip_address VARCHAR(45),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_economy_violations_user ON economy_violations(user_id);
CREATE INDEX IF NOT EXISTS idx_economy_violations_type ON economy_violations(violation_type);
CREATE INDEX IF NOT EXISTS idx_economy_violations_created ON economy_violations(created_at DESC);

COMMENT ON TABLE economy_violations IS 'Audit log for economy rule violations and abuse attempts';
COMMENT ON COLUMN economy_violations.violation_type IS 'Type: COOLDOWN_BREACH, RATE_LIMIT_EXCEEDED, FREE_SILVER_CAP, MONTHLY_LIMIT_EXCEEDED, INSUFFICIENT_FUNDS_ATTEMPT';
