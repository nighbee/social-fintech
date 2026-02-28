-- Adds TASK_REFUND to transaction_category enum
ALTER TYPE transaction_category ADD VALUE IF NOT EXISTS 'TASK_REFUND';
