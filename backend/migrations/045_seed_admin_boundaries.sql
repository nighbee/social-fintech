-- Migration 045: Insert seed administrative boundary data
-- This migration populates the administrative_boundaries table with sample data.
-- In production, this should be replaced with a full OSM import or external GIS data loader.
-- Reference: https://osmdata.openstreetmap.de/

-- Note: Polygons are simplified examples. Real data requires proper GIS import.

-- Insert countries (level 0)
INSERT INTO administrative_boundaries (name, level, country_code, boundary, parent_id, created_at, updated_at)
VALUES (
  'Kazakhstan',
  0,
  'KZ',
  ST_GeomFromText('POLYGON((46 40, 87 40, 87 50, 46 50, 46 40))', 4326),
  NULL,
  NOW(),
  NOW()
) ON CONFLICT DO NOTHING;

INSERT INTO administrative_boundaries (name, level, country_code, boundary, parent_id, created_at, updated_at)
VALUES (
  'United States',
  0,
  'US',
  ST_GeomFromText('POLYGON((-125 25, -66 25, -66 50, -125 50, -125 25))', 4326),
  NULL,
  NOW(),
  NOW()
) ON CONFLICT DO NOTHING;

-- Insert regions (level 1)
INSERT INTO administrative_boundaries (name, level, country_code, boundary, parent_id, created_at, updated_at)
VALUES (
  'Almaty Region',
  1,
  'KZ',
  ST_GeomFromText('POLYGON((68 42, 80 42, 80 48, 68 48, 68 42))', 4326),
  (SELECT id FROM administrative_boundaries WHERE name = 'Kazakhstan' LIMIT 1),
  NOW(),
  NOW()
) ON CONFLICT DO NOTHING;

INSERT INTO administrative_boundaries (name, level, country_code, boundary, parent_id, created_at, updated_at)
VALUES (
  'Akmola Region',
  1,
  'KZ',
  ST_GeomFromText('POLYGON((50 50, 65 50, 65 60, 50 60, 50 50))', 4326),
  (SELECT id FROM administrative_boundaries WHERE name = 'Kazakhstan' LIMIT 1),
  NOW(),
  NOW()
) ON CONFLICT DO NOTHING;

INSERT INTO administrative_boundaries (name, level, country_code, boundary, parent_id, created_at, updated_at)
VALUES (
  'California',
  1,
  'US',
  ST_GeomFromText('POLYGON((-124 32, -114 32, -114 42, -124 42, -124 32))', 4326),
  (SELECT id FROM administrative_boundaries WHERE name = 'United States' LIMIT 1),
  NOW(),
  NOW()
) ON CONFLICT DO NOTHING;

INSERT INTO administrative_boundaries (name, level, country_code, boundary, parent_id, created_at, updated_at)
VALUES (
  'New York',
  1,
  'US',
  ST_GeomFromText('POLYGON((-79 40, -71 40, -71 45, -79 45, -79 40))', 4326),
  (SELECT id FROM administrative_boundaries WHERE name = 'United States' LIMIT 1),
  NOW(),
  NOW()
) ON CONFLICT DO NOTHING;

-- Insert cities (level 2)
INSERT INTO administrative_boundaries (name, level, country_code, boundary, parent_id, created_at, updated_at)
VALUES (
  'Almaty',
  2,
  'KZ',
  ST_GeomFromText('POLYGON((76.85 43.2, 77.05 43.2, 77.05 43.3, 76.85 43.3, 76.85 43.2))', 4326),
  (SELECT id FROM administrative_boundaries WHERE name = 'Almaty Region' LIMIT 1),
  NOW(),
  NOW()
) ON CONFLICT DO NOTHING;

INSERT INTO administrative_boundaries (name, level, country_code, boundary, parent_id, created_at, updated_at)
VALUES (
  'Nur-Sultan (Astana)',
  2,
  'KZ',
  ST_GeomFromText('POLYGON((71.4 51, 71.6 51, 71.6 51.2, 71.4 51.2, 71.4 51))', 4326),
  (SELECT id FROM administrative_boundaries WHERE name = 'Akmola Region' LIMIT 1),
  NOW(),
  NOW()
) ON CONFLICT DO NOTHING;

INSERT INTO administrative_boundaries (name, level, country_code, boundary, parent_id, created_at, updated_at)
VALUES (
  'San Francisco',
  2,
  'US',
  ST_GeomFromText('POLYGON((-122.51 37.7, -122.38 37.7, -122.38 37.82, -122.51 37.82, -122.51 37.7))', 4326),
  (SELECT id FROM administrative_boundaries WHERE name = 'California' LIMIT 1),
  NOW(),
  NOW()
) ON CONFLICT DO NOTHING;

INSERT INTO administrative_boundaries (name, level, country_code, boundary, parent_id, created_at, updated_at)
VALUES (
  'Los Angeles',
  2,
  'US',
  ST_GeomFromText('POLYGON((-118.3 34, -118.1 34, -118.1 34.2, -118.3 34.2, -118.3 34))', 4326),
  (SELECT id FROM administrative_boundaries WHERE name = 'California' LIMIT 1),
  NOW(),
  NOW()
) ON CONFLICT DO NOTHING;

INSERT INTO administrative_boundaries (name, level, country_code, boundary, parent_id, created_at, updated_at)
VALUES (
  'New York City',
  2,
  'US',
  ST_GeomFromText('POLYGON((-74.03 40.63, -73.92 40.63, -73.92 40.82, -74.03 40.82, -74.03 40.63))', 4326),
  (SELECT id FROM administrative_boundaries WHERE name = 'New York' LIMIT 1),
  NOW(),
  NOW()
) ON CONFLICT DO NOTHING;

-- Create indexes for faster spatial queries
CREATE INDEX IF NOT EXISTS idx_admin_boundaries_boundary
  ON administrative_boundaries USING GIST(boundary);

CREATE INDEX IF NOT EXISTS idx_admin_boundaries_level
  ON administrative_boundaries(level);

CREATE INDEX IF NOT EXISTS idx_admin_boundaries_country_code
  ON administrative_boundaries(country_code);
