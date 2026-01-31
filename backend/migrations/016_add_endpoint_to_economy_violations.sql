ALTER TABLE economy_violations
ADD COLUMN IF NOT EXISTS endpoint VARCHAR(255);

CREATE INDEX IF NOT EXISTS idx_economy_violations_endpoint ON economy_violations(endpoint);
