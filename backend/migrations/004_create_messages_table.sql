-- Migration: Create Chat Tables
-- Description: Creates messages table for chat functionality
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY,
    from_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    to_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    read_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_messages_from_id ON messages(from_id);
CREATE INDEX IF NOT EXISTS idx_messages_to_id ON messages(to_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(from_id, to_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_unread ON messages(to_id, read_at) WHERE read_at IS NULL;


COMMENT ON TABLE messages IS 'Chat messages between users';
COMMENT ON COLUMN messages.read_at IS 'Timestamp when message was read by recipient';
