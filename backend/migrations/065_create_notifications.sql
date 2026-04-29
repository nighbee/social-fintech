-- Migration: User notifications
-- Description: Backs the in-app notifications inbox and the push pipeline.
-- Each row represents a discrete event the user should be informed about
-- (ranking change, you moved someone up, season summary, etc).
--
-- Push delivery is fire-and-forget at the message broker layer; this
-- table is the durable read-model the user sees in the bell icon.

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind VARCHAR(48) NOT NULL,            -- 'ranking_up' | 'moved_user' | 'season_end' | ...
    title TEXT NOT NULL,                  -- human-readable summary, may be localised at render time
    body TEXT,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,  -- structured fields for client-side rendering
    read_at TIMESTAMP,                    -- set when the user marks it read (or auto on view)
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
    ON notifications(user_id, read_at NULLS FIRST, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_recent
    ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_kind
    ON notifications(kind);

COMMENT ON TABLE notifications IS 'Per-user notification feed for the in-app bell icon and push pipeline.';
COMMENT ON COLUMN notifications.kind IS 'Discriminator for client rendering: ranking_up, moved_user, season_end, etc.';
COMMENT ON COLUMN notifications.payload IS 'Structured payload (positions, region names, target user, etc) consumed by the client renderer.';
COMMENT ON COLUMN notifications.read_at IS 'Set when the user has acknowledged the notification.';
