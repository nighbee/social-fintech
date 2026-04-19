-- Normalize feed timer options to: 0 (no limit), 20, 40, 60.

-- 1) Data migration for legacy 30-minute values.
UPDATE users
SET feed_time_limit_mins = 40
WHERE feed_time_limit_mins = 30;

UPDATE user_settings
SET feed_time_limit_current_mins = 40
WHERE feed_time_limit_current_mins = 30;

UPDATE user_settings
SET feed_time_limit_pending_mins = 40
WHERE feed_time_limit_pending_mins = 30;

-- 2) Tighten constraints to the new canonical set.
ALTER TABLE user_settings
    DROP CONSTRAINT IF EXISTS user_settings_feed_time_limit_current_mins_check;

ALTER TABLE user_settings
    ADD CONSTRAINT user_settings_feed_time_limit_current_mins_check
    CHECK (feed_time_limit_current_mins IN (0, 20, 40, 60));

ALTER TABLE user_settings
    DROP CONSTRAINT IF EXISTS user_settings_feed_time_limit_pending_mins_check;

ALTER TABLE user_settings
    ADD CONSTRAINT user_settings_feed_time_limit_pending_mins_check
    CHECK (feed_time_limit_pending_mins IS NULL OR feed_time_limit_pending_mins IN (0, 20, 40, 60));

ALTER TABLE users
    DROP CONSTRAINT IF EXISTS users_feed_time_limit_mins_check;

ALTER TABLE users
    ADD CONSTRAINT users_feed_time_limit_mins_check
    CHECK (feed_time_limit_mins IN (0, 20, 40, 60));
