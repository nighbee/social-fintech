-- Migration: Enable PostGIS Extension


CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';
