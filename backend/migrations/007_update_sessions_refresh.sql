-- добавил решрешинг для трэкинга сессий

ALTER TABLE sessions
    ADD COLUMN IF NOT EXISTS refresh_token_hash TEXT,
    ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMP;
