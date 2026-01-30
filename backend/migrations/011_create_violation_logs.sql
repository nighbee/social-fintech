-- примерные логи для анти абьюза
CREATE TABLE IF NOT EXISTS violation_logs (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    violation_type VARCHAR(64) NOT NULL, -- месячный кап, кулдаун, нехватка денег
    endpoint VARCHAR(255) NOT NULL,       -- экономика и трансфер
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_violation_logs_user_id ON violation_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_violation_logs_created_at ON violation_logs(created_at DESC);
