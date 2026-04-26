CREATE TABLE media_abuse_logs (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    violation_type TEXT NOT NULL,
    media_metadata JSONB,
    detection_details TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_media_abuse_logs_user_id ON media_abuse_logs(user_id);
