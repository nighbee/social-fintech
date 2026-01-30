-- паттерны чекает для анти абьюза
CREATE TABLE IF NOT EXISTS user_interactions (
    sender_id UUID NOT NULL,
    receiver_id UUID NOT NULL,
    total_transfers BIGINT NOT NULL DEFAULT 0,
    total_amount BIGINT NOT NULL DEFAULT 0,
    last_amount BIGINT NOT NULL DEFAULT 0,
    last_transfer_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (sender_id, receiver_id)
);

CREATE INDEX IF NOT EXISTS idx_user_interactions_sender ON user_interactions(sender_id);
CREATE INDEX IF NOT EXISTS idx_user_interactions_receiver ON user_interactions(receiver_id);
CREATE INDEX IF NOT EXISTS idx_user_interactions_last_transfer ON user_interactions(last_transfer_at DESC);
