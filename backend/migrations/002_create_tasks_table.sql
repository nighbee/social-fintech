-- Migration: Create Map Tasks Table with PostGIS
-- Description: Creates tasks table with geospatial location support

CREATE TABLE IF NOT EXISTS tasks (
    id UUID PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    reward BIGINT NOT NULL CHECK (reward > 0),
    creator_id UUID NOT NULL,
    location GEOMETRY(Point, 4326) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tasks_location ON tasks USING GIST (location);

CREATE INDEX idx_tasks_creator_id ON tasks(creator_id);

CREATE INDEX idx_tasks_is_active ON tasks(is_active) WHERE is_active = true;

CREATE INDEX idx_tasks_active_location ON tasks USING GIST (location) WHERE is_active = true;

CREATE INDEX idx_tasks_created_at ON tasks(created_at DESC);

COMMENT ON TABLE tasks IS 'Geospatial tasks on the map with PostGIS location support';
COMMENT ON COLUMN tasks.location IS 'Point geometry in WGS84 (SRID 4326) - stores (longitude, latitude)';
COMMENT ON COLUMN tasks.reward IS 'Reward amount in Silver Seals for completing the task';
COMMENT ON COLUMN tasks.is_active IS 'Whether the task is currently active and visible';
