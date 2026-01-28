-- добавляю метадату в сессии
ALTER TABLE sessions
	ADD COLUMN IF NOT EXISTS user_agent TEXT,
	ADD COLUMN IF NOT EXISTS app_version TEXT;
