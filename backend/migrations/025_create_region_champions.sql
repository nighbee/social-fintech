-- Region champions snapshots (weekly)
CREATE TABLE IF NOT EXISTS region_champions (
	id UUID PRIMARY KEY,
	h3_index VARCHAR(20) NOT NULL,
	resolution SMALLINT NOT NULL,
	user_id UUID NOT NULL,
	score BIGINT NOT NULL DEFAULT 0,
	week INT NOT NULL,
	year INT NOT NULL,
	updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_region_champions_unique
	ON region_champions(h3_index, resolution, week, year);

CREATE INDEX IF NOT EXISTS idx_region_champions_user
	ON region_champions(user_id, updated_at DESC);
