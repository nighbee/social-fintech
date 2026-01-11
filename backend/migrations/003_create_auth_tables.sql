-- Migration: Create Auth Tables
-- Description: Creates users and sessions tables

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    username VARCHAR(50) NOT NULL UNIQUE,
    avatar_url VARCHAR(500),
    is_shadow_banned BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    last_active_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_last_active ON users(last_active_at DESC);

CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id VARCHAR(255) NOT NULL,
    ip VARCHAR(45) NOT NULL,
    last_active_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_device_id ON sessions(device_id);
CREATE INDEX idx_sessions_last_active ON sessions(last_active_at DESC);

COMMENT ON TABLE users IS 'User accounts with OAuth authentication';
COMMENT ON TABLE sessions IS 'User sessions for tracking devices and activity';
COMMENT ON COLUMN users.is_shadow_banned IS 'Shadow ban flag - user can login but content is hidden';
COMMENT ON COLUMN users.last_active_at IS 'Last activity timestamp for anti-doomscroll tracking';
