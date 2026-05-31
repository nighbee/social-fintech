-- Migration: 075_chat_request_status
-- Adds request_status lifecycle to direct conversations.
-- pending   → sender is waiting for recipient to accept/decline
-- accepted  → default; both sides can message freely
-- declined  → recipient declined; sender cannot send more messages

ALTER TABLE chat_conversations
ADD COLUMN IF NOT EXISTS request_status VARCHAR(20) NOT NULL DEFAULT 'accepted'
    CHECK (request_status IN ('pending', 'accepted', 'declined'));

CREATE INDEX IF NOT EXISTS idx_chat_conversations_pending_requests
    ON chat_conversations(request_status)
    WHERE request_status = 'pending';
