CREATE TABLE report_cooldowns (
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cooldown_until TIMESTAMP WITH TIME ZONE NOT NULL,
    current_cooldown_hours INTEGER NOT NULL DEFAULT 24,
    last_report_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (reporter_id, target_user_id)
);

CREATE INDEX idx_report_cooldowns_cooldown_until ON report_cooldowns(cooldown_until);
