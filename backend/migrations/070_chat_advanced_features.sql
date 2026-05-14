-- Migration: 061_chat_advanced_features
-- Description: Adds fields and tables for advanced chat features (reply, forward, pin, delete, mute).

-- 1. Message Enhancements: Reply, Forward, and "Delete for both" (soft delete)
ALTER TABLE chat_messages
ADD COLUMN IF NOT EXISTS reply_to_message_id UUID NULL REFERENCES chat_messages(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS forwarded_from_user_id UUID NULL REFERENCES users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ NULL,
ADD COLUMN IF NOT EXISTS deleted_by_user_id UUID NULL REFERENCES users(id) ON DELETE SET NULL;

-- 2. Message "Delete for me" functionality
CREATE TABLE IF NOT EXISTS chat_message_deletions (
    message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    deleted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (message_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_message_deletions_user
    ON chat_message_deletions(user_id);

-- 3. Multi-pin support: multiple pinned messages per conversation, ordered by pin time.
--    The frontend shows the latest pin at the top of the chat window; tapping it scrolls
--    to that message and cycles to the next pin in reverse-chronological order.
CREATE TABLE IF NOT EXISTS chat_pinned_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE,
    message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
    pinned_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pinned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (conversation_id, message_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_pinned_messages_conversation
    ON chat_pinned_messages(conversation_id, pinned_at DESC);

-- 4. Conversation Member Enhancements: Mute, Pin Chat, Clear Chat
ALTER TABLE chat_conversation_members
ADD COLUMN IF NOT EXISTS is_muted BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS pinned_at TIMESTAMPTZ NULL,
ADD COLUMN IF NOT EXISTS cleared_at TIMESTAMPTZ NULL;
