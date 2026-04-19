-- Add lat/lon coordinates to region_champions table to solve "marker jumping" on mobile clients
ALTER TABLE region_champions
	ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION NOT NULL DEFAULT 0,
	ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION NOT NULL DEFAULT 0;

COMMENT ON COLUMN region_champions.latitude  IS 'Geographic center latitude of the H3 cell';
COMMENT ON COLUMN region_champions.longitude IS 'Geographic center longitude of the H3 cell';
