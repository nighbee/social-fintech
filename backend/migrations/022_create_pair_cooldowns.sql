CREATE TABLE IF NOT EXISTS pair_cooldowns (
    sender_user_id VARCHAR(36) NOT NULL,
    receiver_user_id VARCHAR(36) NOT NULL,
    repeat_level INT NOT NULL DEFAULT 1 CHECK (repeat_level BETWEEN 1 AND 5),
    last_grant_at TIMESTAMP WITH TIME ZONE NOT NULL,
    next_allowed_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (sender_user_id, receiver_user_id)
);

CREATE INDEX IF NOT EXISTS idx_pair_cooldowns_sender ON pair_cooldowns(sender_user_id);
CREATE INDEX IF NOT EXISTS idx_pair_cooldowns_receiver ON pair_cooldowns(receiver_user_id);
