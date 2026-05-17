-- Новые колонки для UI
ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS ui_tab VARCHAR(20) NOT NULL DEFAULT 'SYSTEM',
  ADD COLUMN IF NOT EXISTS is_important BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS badge_status VARCHAR(30),
  ADD COLUMN IF NOT EXISTS deep_link TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS group_key VARCHAR(255),
  ADD COLUMN IF NOT EXISTS actor_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS group_count INT NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Индекс для upsert группировки
CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_group_upsert
  ON notifications(user_id, group_key)
  WHERE read_at IS NULL AND group_key IS NOT NULL;

-- Индекс для All tab сортировки
CREATE INDEX IF NOT EXISTS idx_notifications_all_tab
  ON notifications(user_id, is_important DESC, updated_at DESC);
