CREATE TABLE IF NOT EXISTS post_idempotency_keys (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    idempotency_key VARCHAR(128) NOT NULL,
    request_fingerprint VARCHAR(128),
    post_id UUID NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_post_idempotency_post_id
    ON post_idempotency_keys(post_id)
    WHERE post_id IS NOT NULL;

