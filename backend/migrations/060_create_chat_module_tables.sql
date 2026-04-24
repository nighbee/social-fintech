-- Chat module tables (direct + task conversations, messages, idempotency)

CREATE TABLE IF NOT EXISTS chat_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kind VARCHAR(20) NOT NULL CHECK (kind IN ('direct', 'task')),
    direct_key VARCHAR(80) NOT NULL,
    task_id UUID NULL REFERENCES tasks(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    last_message_id UUID NULL,
    last_message_at TIMESTAMPTZ NULL,
    last_message_preview TEXT NULL,
    last_message_type VARCHAR(20) NULL,
    last_message_sender_id UUID NULL REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uidx_chat_conversations_direct
    ON chat_conversations(kind, direct_key)
    WHERE task_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uidx_chat_conversations_task
    ON chat_conversations(kind, task_id, direct_key)
    WHERE task_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_chat_conversations_last_message
    ON chat_conversations(last_message_at DESC NULLS LAST, created_at DESC);

CREATE TABLE IF NOT EXISTS chat_conversation_members (
    conversation_id UUID NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    unread_count INTEGER NOT NULL DEFAULT 0 CHECK (unread_count >= 0),
    last_read_message_id UUID NULL,
    last_read_at TIMESTAMPTZ NULL,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_members_user
    ON chat_conversation_members(user_id, joined_at DESC);

CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE,
    sender_id UUID NULL REFERENCES users(id) ON DELETE SET NULL,
    message_type VARCHAR(20) NOT NULL CHECK (message_type IN ('user', 'system')),
    body TEXT NOT NULL DEFAULT '',
    media JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation
    ON chat_messages(conversation_id, created_at DESC, id DESC);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_chat_conversations_last_message'
    ) THEN
        ALTER TABLE chat_conversations
            ADD CONSTRAINT fk_chat_conversations_last_message
            FOREIGN KEY (last_message_id) REFERENCES chat_messages(id) ON DELETE SET NULL;
    END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS chat_message_idempotency_keys (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    idempotency_key VARCHAR(128) NOT NULL,
    request_fingerprint VARCHAR(64) NOT NULL,
    message_id UUID NULL REFERENCES chat_messages(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_chat_idempotency_created_at
    ON chat_message_idempotency_keys(created_at DESC);
