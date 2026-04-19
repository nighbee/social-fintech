-- Migration: Extend tasks table for multi-actor verification flow
-- Adds: description, workers_needed, workers_filled, verification_code,
--       auto_shutdown_at, status, last_task_created index for cooldown enforcement

-- Task status lifecycle: open → in_progress → completed | cancelled
ALTER TABLE tasks
    ADD COLUMN IF NOT EXISTS description      TEXT,
    ADD COLUMN IF NOT EXISTS workers_needed   SMALLINT     NOT NULL DEFAULT 1
                                              CHECK (workers_needed BETWEEN 1 AND 20),
    ADD COLUMN IF NOT EXISTS workers_filled   SMALLINT     NOT NULL DEFAULT 0
                                              CHECK (workers_filled >= 0),
    ADD COLUMN IF NOT EXISTS verification_code CHAR(4)     NOT NULL DEFAULT '0000',
    ADD COLUMN IF NOT EXISTS auto_shutdown_at  TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS status            VARCHAR(20)  NOT NULL DEFAULT 'open'
                                              CHECK (status IN ('open', 'in_progress', 'completed', 'cancelled'));

-- Constraint: workers_filled never exceeds workers_needed
ALTER TABLE tasks
    ADD CONSTRAINT chk_tasks_workers_filled_lte_needed
    CHECK (workers_filled <= workers_needed);

-- Index: status lookups (open tasks on map, worker sweep)
CREATE INDEX IF NOT EXISTS idx_tasks_status
    ON tasks(status);

-- Partial index: only open tasks — used by map queries and auto-shutdown worker
CREATE INDEX IF NOT EXISTS idx_tasks_open_status
    ON tasks(status) WHERE status = 'open';

-- Index: auto-shutdown worker scans tasks where auto_shutdown_at < NOW()
CREATE INDEX IF NOT EXISTS idx_tasks_auto_shutdown
    ON tasks(auto_shutdown_at) WHERE auto_shutdown_at IS NOT NULL AND status = 'open';

-- Index: 7-day cooldown enforcement — find latest task created per user
CREATE INDEX IF NOT EXISTS idx_tasks_creator_created
    ON tasks(creator_id, created_at DESC);

COMMENT ON COLUMN tasks.description       IS 'Detailed description of the task provided by the creator';
COMMENT ON COLUMN tasks.workers_needed    IS 'Number of helpers required before the task is considered complete (1–20)';
COMMENT ON COLUMN tasks.workers_filled    IS 'Number of helpers who have been confirmed by the creator';
COMMENT ON COLUMN tasks.verification_code IS 'Random 4-digit code shown only to task creator; worker must submit to verify presence';
COMMENT ON COLUMN tasks.auto_shutdown_at  IS 'If set, task is automatically cancelled at this timestamp (24h after creation)';
COMMENT ON COLUMN tasks.status            IS 'Lifecycle state: open | in_progress | completed | cancelled';
