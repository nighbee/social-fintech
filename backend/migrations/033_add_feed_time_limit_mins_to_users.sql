-- +goose Up
ALTER TABLE users
ADD COLUMN IF NOT EXISTS feed_time_limit_mins INTEGER NOT NULL DEFAULT 20;

COMMENT ON COLUMN users.feed_time_limit_mins IS
'Feed active-time limit in minutes. Allowed values are controlled by application logic.';

