-- Add task completion fields
ALTER TABLE tasks
	ADD COLUMN IF NOT EXISTS completed_by UUID,
	ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_tasks_completed_by ON tasks(completed_by);
