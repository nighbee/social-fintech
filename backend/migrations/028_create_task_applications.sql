-- Migration: Create task_applications table
-- Represents user2 applying to help with a task.
-- Status lifecycle: pending → code_verified → confirmed
--                         └→ rejected
--
-- A task can have multiple applications (up to workers_needed confirmations).

CREATE TABLE IF NOT EXISTS task_applications (
    id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id           UUID         NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    applicant_id      UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Lifecycle state of this individual application
    status            VARCHAR(20)  NOT NULL DEFAULT 'pending'
                                   CHECK (status IN ('pending', 'code_verified', 'confirmed', 'rejected')),

    -- Set when applicant submits the correct 4-digit verification code
    code_submitted_at TIMESTAMPTZ,

    -- Set when task creator confirms the applicant helped
    confirmed_at      TIMESTAMPTZ,

    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Unique: one active application per (task, applicant) — prevents duplicate apply
CREATE UNIQUE INDEX IF NOT EXISTS uidx_task_applications_task_applicant
    ON task_applications(task_id, applicant_id)
    WHERE status NOT IN ('rejected');

-- Index: creator looks up all applicants for their task
CREATE INDEX IF NOT EXISTS idx_task_applications_task_id
    ON task_applications(task_id);

-- Index: applicant looks up their own applications
CREATE INDEX IF NOT EXISTS idx_task_applications_applicant_id
    ON task_applications(applicant_id);

-- Index: worker sweep — find confirmed applications for leaderboard / economy processing
CREATE INDEX IF NOT EXISTS idx_task_applications_status
    ON task_applications(status);

COMMENT ON TABLE  task_applications                    IS 'Records of users applying to help complete a map task';
COMMENT ON COLUMN task_applications.status             IS 'Application lifecycle: pending | code_verified | confirmed | rejected';
COMMENT ON COLUMN task_applications.code_submitted_at  IS 'Timestamp when applicant submitted the correct 4-digit verification code';
COMMENT ON COLUMN task_applications.confirmed_at       IS 'Timestamp when task creator confirmed the applicant helped — triggers silver transfer';
