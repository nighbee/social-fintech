-- Migration: 053_add_ledger_post_id_index.sql
-- Description: Adds a functional index on the post_id field inside the ledger_entries metadata JSONB.
-- This significantly speeds up the denormalization worker (flushSeals) which queries 
-- the entire ledger history to maintain absolute consistency for posts.seals_count.

CREATE INDEX IF NOT EXISTS idx_ledger_entries_post_id ON ledger_entries ((metadata->>'post_id')) 
WHERE category = 'POST_SEAL';
