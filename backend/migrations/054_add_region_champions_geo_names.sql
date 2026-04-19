-- Migration 054: Store geo names directly on region_champions
-- 
-- Previously, UpsertRegionChampion did not persist the geo name columns
-- (city_name, region_name, country_name), meaning GetRegionChampions had
-- to rely solely on a LEFT JOIN h3_geo_metadata which may not have been
-- populated yet.  The worker now inserts these names directly during
-- snapshotChampions(), making champion pins render correctly even when the
-- h3_geo_metadata cache is cold.

ALTER TABLE region_champions
    ADD COLUMN IF NOT EXISTS city_name    TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS region_name  TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS country_name TEXT NOT NULL DEFAULT '';
