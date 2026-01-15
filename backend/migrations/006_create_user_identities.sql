-- создаем миграцию юзеров для идентицикации юзеров
-- для коннекта OAuth и ID юзеров

CREATE TABLE IF NOT EXISTS user_identities (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(20) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (provider, subject),
    UNIQUE (user_id, provider)
);

CREATE INDEX idx_user_idetntities_user_id ON user_identities(user_id);
COMMENT ON TABLE user_identities IS 'OAuth identities for users (provider + subject)';
