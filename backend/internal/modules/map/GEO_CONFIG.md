# Geo-Logic System Configuration

## Overview

The BrightBund geo-logic system uses H3 hexagonal indexing with administrative boundary integration to map posts, tasks, and user locations to cities, regions, and countries.

## Core Parameters

### H3 Resolution Mapping

| Resolution | Coverage | Use Case |
|-----------|----------|----------|
| res5 | ~253 km² (19km diameter) | Arena leaderboards, local activity hubs |
| res4 | ~1.7k km² (59km diameter) | City/regional boundaries, city leaderboards |
| res2 | ~86k km² (607km diameter) | Country-level boundaries, global rankings |

### Feed Blending Logic

```
Local feed blend: 80% (allies + nearby kRing posts)
World feed blend: 20% (global/country-level posts)

Ring-based distance model:
- kRing 1: ~5 km radius
- kRing 2: ~10 km radius
- kRing 3: ~18 km radius
```

### Admin Boundary Rule (50%+ Coverage)

**Current Implementation**: Center-point lookup
- Calculate H3 cell center point
- Use `ST_Covers` + `ST_Within` spatial queries
- Fallback to intersecting boundaries on edge cases

**Rule Definition**: 
A hex is assigned to a city/region/country if >50% of the hex's area overlaps with that administrative boundary.

**Database Query**:
```sql
SELECT city_name, region_name, country_name
FROM administrative_boundaries
WHERE ST_Covers(boundary, H3_CENTER)
   OR ST_Within(H3_CENTER, boundary)
ORDER BY level DESC (country=0, region=1, city=2)
```

### Geo-Metadata Caching

- **Table**: `h3_geo_metadata`
- **Key**: H3 index (varchar(20), primary key)
- **Values**: city_name, region_name, country_name, country_code, resolved_at
- **TTL**: Permanent (materialized cache); TTL can be enforced at application layer if needed

### Leaderboard Key Structure

```
leaderboard:arena:{h3_res5}:{timestamp}       # Arena (district level)
leaderboard:city:{h3_res4}:week:{year}:{week} # City/Regional
leaderboard:global:week:{year}:{week}         # Global
```

### Administrative Boundary Levels

| Level | Entity | Example |
|-------|--------|---------|
| 0 | Country | Kazakhstan |
| 1 | Region/Province | Almaty Region |
| 2 | City/District | Almaty city |

### API Endpoints

#### User Region Assignment
```
POST /api/v1/map/region
{
  "latitude": 43.2380,
  "longitude": 76.9453
}

Response:
{
  "user_id": "user-123",
  "h3_res5": "8a2a100704d7fff",
  "h3_res4": "8a2a10070ffffff",
  "h3_res2": "822a100ffffffffff",
  "city": "Almaty",
  "region": "Almaty Region",
  "country": "Kazakhstan"
}
```

#### H3 to Admin Lookup
```
GET /api/v1/map/h3/{h3_index}/admin

Response:
{
  "h3_index": "8a2a100704d7fff",
  "city_name": "Almaty",
  "region_name": "Almaty Region",
  "country_name": "Kazakhstan",
  "country_code": "KZ",
  "resolved_at": "2026-03-21T12:00:00Z"
}
```

## Integration Points

### Feed System
- Uses H3 res5/res4 to determine local/global content blend
- Distance-ring model for nearby posts
- Future: admin-boundary-based feed scoping

### Task System
- Task creation stores h3_res5, h3_res4, h3_res2
- Tasks searchable by H3 proximity (kRing)
- Leaderboard updates keyed by H3 resolution

### Champion System
- Champions ranked per H3 cell by resolution
- Weekly snapshots stored in `region_champions` table
- Endpoint aggregates champions for visible H3 cells on map

## Database Migrations

- **Migration 024**: Add H3 fields to users and tasks tables
- **Migration 025**: Create region_champions table (weekly snapshots)
- **Migration 044**: Create administrative_boundaries and h3_geo_metadata tables

**Note**: Administrative boundary data must be populated via OSM import or seed migration for queries to return results.

## Implementation Roadmap

### Completed ✓
- H3 cell assignment (res5/res4/res2)
- Metadata cache infrastructure
- Boundary spatial query (ST_Covers fallback)
- H3→admin lookup endpoint
- Leaderboard Redis structure
- Champion snapshot worker

### Partial
- Boundary data population (no loader visible; requires OSM import)
- Boundary ownership now uses executable 50%+ H3 polygon overlap (with deterministic center-point fallback when no 50% winner exists)

### Future Enhancements
- Admin-boundary-based feed scoping (instead of distance rings)
- Batch H3→admin resolution API
- Boundary data auto-refresh from OSM
- H3 resolution dynamic adjustment based on post density

## Testing Strategy

See `backend/internal/modules/map/service_test.go`:
- H3 cell computation validation
- Coordinate range validation
- Metadata response structure
- Task H3 assignment verification
- Leaderboard key format validation

## Troubleshooting

**H3 lookups return NULL**:
- Check if `administrative_boundaries` table is populated
- Verify H3 polygon intersects expected boundary polygons (>50% overlap for ownership)
- If no >50% winner exists, verify center-point fallback falls within expected polygon
- Check PostGIS extension is enabled: `SELECT PostGIS_Version();`

**Feed not blending correctly**:
- Verify Redis leaderboard keys are being set on task completion
- Check ring-distance calculation in `smart_feed.go`
- Ensure feed state (break, cooldown) is not blocking local content

**Champion pins not showing**:
- Verify `region_champions` snapshot worker is running
- Check Redis leaderboard population for the week/year
- Ensure h3_geo_metadata cache is being populated on user region set
