-- Migration: Six-month seasons + per-user season archive
-- Description: Two tables that back the founder-mandated season system:
--   * seasons              — describes each 6-month period with explicit
--                            open/close timestamps. Two seasons per year:
--                            half = 1 (Jan 1 – Jun 30) and half = 2 (Jul 1 – Dec 31).
--   * user_season_archive  — frozen snapshot of a user's final standing at
--                            season close. Powers the "Архив" tab in
--                            the profile screen.

CREATE TABLE IF NOT EXISTS seasons (
    id UUID PRIMARY KEY,
    season_year INTEGER NOT NULL,
    season_half INTEGER NOT NULL CHECK (season_half IN (1, 2)),
    starts_at TIMESTAMP NOT NULL,
    ends_at TIMESTAMP NOT NULL,
    closed_at TIMESTAMP,                 -- set when archive snapshots have been written
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_seasons_year_half_unique
    ON seasons(season_year, season_half);
CREATE INDEX IF NOT EXISTS idx_seasons_window
    ON seasons(starts_at, ends_at);

CREATE TABLE IF NOT EXISTS user_season_archive (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    season_id UUID NOT NULL REFERENCES seasons(id) ON DELETE CASCADE,
    season_year INTEGER NOT NULL,
    season_half INTEGER NOT NULL,
    final_position INTEGER,              -- 1 = #1, NULL means user did not rank
    seal_count BIGINT NOT NULL DEFAULT 0,
    region VARCHAR(255),                 -- city / country label at close-out
    scope VARCHAR(32),                   -- 'city' | 'region' | 'country' | 'global'
    snapshot_payload JSONB NOT NULL DEFAULT '{}'::jsonb,  -- room for future fields without migrating
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, season_id)
);

CREATE INDEX IF NOT EXISTS idx_user_season_archive_user
    ON user_season_archive(user_id, season_year DESC, season_half DESC);
CREATE INDEX IF NOT EXISTS idx_user_season_archive_season
    ON user_season_archive(season_id, final_position NULLS LAST);

COMMENT ON TABLE seasons IS 'Six-month ranking seasons. Two seasons per year: half=1 (Jan-Jun) and half=2 (Jul-Dec).';
COMMENT ON TABLE user_season_archive IS 'Frozen per-user standings at season close. Drives the profile "Архив" tab.';
COMMENT ON COLUMN user_season_archive.final_position IS 'Final rank within the user''s scope at season close. NULL when the user did not rank.';
