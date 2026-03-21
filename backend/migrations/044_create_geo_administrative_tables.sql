-- Migration: Create Geo-Administrative Layer Tables
-- Description: Stores administrative boundaries and H3-to-Location mapping

CREATE TABLE IF NOT EXISTS administrative_boundaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    level INTEGER NOT NULL, -- 0: Country, 1: Region, 2: City
    parent_id UUID REFERENCES administrative_boundaries(id),
    boundary GEOMETRY(Polygon, 4326) NOT NULL,
    country_code VARCHAR(10),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_boundaries_geom ON administrative_boundaries USING GIST (boundary);
CREATE INDEX IF NOT EXISTS idx_boundaries_level ON administrative_boundaries(level);

CREATE TABLE IF NOT EXISTS h3_geo_metadata (
    h3_index VARCHAR(20) PRIMARY KEY,
    city_name VARCHAR(255),
    region_name VARCHAR(255),
    country_name VARCHAR(255),
    country_code VARCHAR(10),
    resolved_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Comments for clarity
COMMENT ON TABLE administrative_boundaries IS 'Polygons for countries, regions, and cities for spatial lookups';
COMMENT ON TABLE h3_geo_metadata IS 'Cache table for mapping H3 indices to human-readable administrative names';
