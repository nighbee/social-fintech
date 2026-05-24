-- Migration: Add notification preference columns to user_settings
-- Description: Powers the Notifications Settings screen toggles and Quiet Hours.
-- Spec: issues/notifications_req.txt §1

ALTER TABLE user_settings
  ADD COLUMN IF NOT EXISTS notify_gold_honor BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_medal_unlocked BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_rank_increased BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_task_updates BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_comments_replies BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_likes_reactions BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS quiet_hours_start TIME NULL,
  ADD COLUMN IF NOT EXISTS quiet_hours_end TIME NULL;

COMMENT ON COLUMN user_settings.notify_gold_honor IS 'Toggle: Gold Honor received push notification';
COMMENT ON COLUMN user_settings.notify_medal_unlocked IS 'Toggle: Medal unlocked push notification';
COMMENT ON COLUMN user_settings.notify_rank_increased IS 'Toggle: Rank increased push notification';
COMMENT ON COLUMN user_settings.notify_task_updates IS 'Toggle: Task updates push notification';
COMMENT ON COLUMN user_settings.notify_comments_replies IS 'Toggle: Comments & Replies push notification';
COMMENT ON COLUMN user_settings.notify_likes_reactions IS 'Toggle: Likes & Reactions push notification';
COMMENT ON COLUMN user_settings.quiet_hours_start IS 'Do not disturb start time (HH:MM, local timezone)';
COMMENT ON COLUMN user_settings.quiet_hours_end IS 'Do not disturb end time (HH:MM, local timezone)';
