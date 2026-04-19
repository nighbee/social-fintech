-- Migration: Update task_applications status check constraint to include 'accepted'

-- 1. Try to drop the auto-generated constraint name
ALTER TABLE task_applications DROP CONSTRAINT IF EXISTS task_applications_status_check;

-- 2. Add the new constraint with 'accepted'
ALTER TABLE task_applications 
  ADD CONSTRAINT task_applications_status_check 
  CHECK (status IN ('pending', 'accepted', 'code_verified', 'confirmed', 'rejected'));
