# BrightBund — Geo Module Technical Design

**Status:** Draft

---

## 1. Problem Statement

The founder's vision requires dividing the world map into competitive regions where users can become "Champions". The naive approach — storing city polygon boundaries per country and checking membership via PostGIS `ST_Intersects` — has a critical scaling flaw:

- **Manual compliance:** Every new city/country requires importing and validating OSM boundary data.
- **Performance:** A PostGIS polygon intersection query runs on every user action that needs region context.
- **Global expansion:** The app targets worldwide users. Manual curation is not viable.

---

## 2. Solution: H3 Hexagonal Spatial Index

**H3** is Uber's open-source hierarchical spatial indexing system. It divides the entire Earth into a multi-resolution grid of hexagonal cells. Every point on the planet belongs to a deterministic cell at every resolution level — no data import, no manual boundaries, no compliance checks.

**Prior art using this approach:**
- **Ingress / Pokémon GO (Niantic):** S2 Geometry (same concept, square cells).
- **Uber:** H3 natively for surge pricing zones and driver dispatch.
- **DoorDash / Grab:** H3 for delivery zone segmentation.

**Go library:** `github.com/uber/h3-go/v4`

---

## 3. Resolution Mapping

H3 has 16 resolution levels (0–15). The relevant ones for BrightBund:

| H3 Resolution | Avg Cell Area | BrightBund Use |
|---|---|---|
| 2 | ~86,700 km² | Country-scale zone |
| 4 | ~1,770 km² | Large city |
| 5 | ~253 km² | City district / Champion arena |
| 6 | ~36 km² | Neighborhood (task density) |
| 7 | ~5 km² | Hyper-local feed radius |

**Primary resolution for Champion regions: 5**
This gives cells roughly the size of a city district — close to the founder's "city divided into 4 quadrants" concept. Each H3 cell at resolution 5 has a globally unique string ID (e.g., `852830803fffffff`), requiring zero backend configuration per country.

**H3 hierarchy is built-in:** Every resolution-5 cell has a parent at resolution-4, resolution-3, etc. This gives country → city → district hierarchy for free via `cell.Parent(resolution)`.

---

## 4. Architecture

### 4.1 Region Assignment (O(1), No DB)

Region membership is computed purely in Go with no database query:

```go
import "github.com/uber/h3-go/v4"

// Assign user/task to a Champion arena cell (res 5)
cell := h3.LatLngToCell(h3.LatLng{Lat: lat, Lng: lng}, 5)
arenaID := cell.String() // globally unique, e.g. "852830803fffffff"

// Get parent city-level cell (res 3)
cityCell := cell.Parent(3)
cityID := cityCell.String()
```

This replaces the entire `regions` table, `ST_Intersects` queries, and the `FindRegionByPoint` PostGIS function from the old plan.

### 4.2 Database Schema

No `regions` table is needed. H3 cell IDs are stored as `VARCHAR` directly on entities.

```sql
-- migrations/023_create_region_champions_table.sql

CREATE TABLE region_champions (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    h3_index     VARCHAR(20) NOT NULL,        -- H3 cell ID, resolution 5
    h3_res       SMALLINT NOT NULL DEFAULT 5, -- resolution level stored for flexibility
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    week_number  INT NOT NULL,                -- ISO week number
    year         INT NOT NULL,
    gold_score   BIGINT NOT NULL DEFAULT 0,
    crowned_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (h3_index, h3_res, week_number, year)
);

CREATE INDEX idx_champions_h3_week ON region_champions(h3_index, week_number, year);
CREATE INDEX idx_champions_user    ON region_champions(user_id);
```

Tasks table retains `location GEOMETRY(Point, 4326)` for radius search (PostGIS `ST_DWithin` still used here), but gains an `h3_index` column for fast champion-zone lookups:

```sql
-- migrations/024_update_tasks_geo.sql (updated)

ALTER TABLE tasks ADD COLUMN h3_index VARCHAR(20);  -- populated on insert, res 5
ALTER TABLE tasks ADD COLUMN region_id VARCHAR(20); -- parent city cell, res 3
CREATE INDEX idx_tasks_h3 ON tasks(h3_index);
```

### 4.3 Leaderboard Keys (Redis ZSET)

The H3 cell ID becomes the leaderboard key directly — no region lookup needed:

```
# Per-arena weekly leaderboard
ZSET key: leaderboard:arena:{h3_index}:week:{year}:{week_number}

# City-level leaderboard (parent cell)
ZSET key: leaderboard:city:{h3_parent_res3}:week:{year}:{week_number}

# Global leaderboard
ZSET key: leaderboard:global:week:{year}:{week_number}
```

When a user earns Gold Seals, all three ZSETs are updated atomically via a Redis pipeline. Champion = `ZREVRANGE key 0 0` — the member with the highest score.

### 4.4 Task Creation Flow (Updated)

```go
// internal/modules/tasks/service.go

func (s *TaskService) CreateTask(ctx context.Context, input CreateTaskInput) (*Task, error) {
    // Step 1: Start transaction
    tx := s.db.BeginTx(ctx)

    // Step 2: Debit wallet (Economy domain)
    if err := s.economyService.Debit(tx, input.UserID, input.Cost); err != nil {
        tx.Rollback()
        return nil, err // returns INSUFFICIENT_FUNDS if needed
    }

    // Step 3: Assign H3 cells — pure math, no DB call
    cell := h3.LatLngToCell(h3.LatLng{Lat: input.Lat, Lng: input.Lng}, 5)
    parentCell := cell.Parent(3)

    // Step 4: Insert task
    task := &Task{
        UserID:   input.UserID,
        Location: input.Location, // PostGIS Point for ST_DWithin radius search
        H3Index:  cell.String(),
        RegionID: parentCell.String(),
        // ...
    }
    if err := s.repo.Insert(tx, task); err != nil {
        tx.Rollback()
        return nil, err
    }

    // Step 5: Commit
    return task, tx.Commit()
}
```

### 4.5 Viewport-Based Champion Pins (Map API)

The mobile app sends its current map viewport bounds. The server computes all H3 cells visible within the viewport and returns champions for those cells:

```go
// GET /api/v1/map/champions?swLat=...&swLng=...&neLat=...&neLng=...

func (s *MapService) GetChampionsInViewport(sw, ne LatLng) ([]ChampionPin, error) {
    // Convert viewport rectangle to a list of H3 cells at res 5
    polygon := h3.NewGeoPolygon(viewportRing(sw, ne), nil)
    cells := h3.PolygonToCells(polygon, 5)

    h3Indexes := make([]string, len(cells))
    for i, c := range cells {
        h3Indexes[i] = c.String()
    }

    // Single batch DB query for all visible champions
    return s.repo.GetCurrentChampionsByH3Indexes(h3Indexes, currentWeek(), currentYear())
}
```

This is a single batched query regardless of how many cells are on screen.

---

## 5. Weekly Champion Cycle

A background worker (already in the roadmap — Stage 3 Week 9) runs every Monday at 00:00 UTC:

1. Reads all active ZSET leaderboards that had activity in the past week.
2. Takes the top scorer per H3 cell (`ZREVRANGE key 0 0 WITHSCORES`).
3. Writes a row to `region_champions` (PostgreSQL snapshot for history).
4. Publishes a push notification to the new champion.
5. Resets or expires the Redis ZSET for the new week.

Redis key expiry: TTL of 8 days on weekly ZSETs ensures automatic cleanup.

---

## 6. Radius Search (Tasks Nearby)

PostGIS is still used for the radius search — H3 does not replace this. Tasks store both `location` (geometry) and `h3_index` (for zone queries). The two queries serve different purposes:

| Query type | Method | When used |
|---|---|---|
| "Tasks near me" | `ST_DWithin(location::geography, ...)` | Feed / map task pins |
| "Tasks in this arena" | `WHERE h3_index = $1` | Champion score calculation, zone leaderboard |
| "User's arena" | `h3.LatLngToCell(...)` in Go | Every user action — O(1), no DB |

```sql
-- Find tasks within 5km of a point
SELECT * FROM tasks
WHERE ST_DWithin(
    location::geography,
    ST_SetSRID(ST_MakePoint($lon, $lat), 4326)::geography,
    5000
)
AND status = 'open'
ORDER BY location <-> ST_SetSRID(ST_MakePoint($lon, $lat), 4326)
LIMIT 50;
```

---

## 7. Map Tile Provider

H3 is a server-side math library. It is completely decoupled from the map tile renderer — the hexagonal cell polygons are simply drawn as an overlay on top of whatever tile source is configured in `flutter_map`.

| Provider | Cost | API Key | Visual Quality | Notes |
|---|---|---|---|---|
| **OpenStreetMap (OSM)** | Free, unlimited | None | Good | Default for MVP |
| **Mapbox** | Free ≤50k loads/mo, then paid | Required + account | Excellent, vector | Drop-in upgrade path |
| Google Maps | Paid from first request | Required + billing | Excellent | Requires `google_maps_flutter`, harder to swap |

**Decision: `flutter_map` with OSM tiles for MVP.**

`flutter_map` accepts any tile URL template. Switching from OSM to Mapbox post-MVP is a single config change:

```dart
// OSM (MVP default — no API key)
TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
)

// Mapbox (post-MVP upgrade — swap this one line)
TileLayer(
  urlTemplate:
    'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token={accessToken}',
  additionalOptions: {'accessToken': Env.mapboxToken},
)
```

The H3 `PolygonLayer` champion zone overlays, `MarkerLayer` task pins, and all other map UI are identical on both providers.

---

## 8. Mobile (Flutter)

**Dependencies:**
- `flutter_map` — OSM tile rendering, `PolygonLayer` for H3 cell outlines
- `latlong2` — coordinate types
- `geolocator` — user location

**Map rendering strategy:**
- The API response for `GET /map/champions` includes the H3 cell boundary polygon for each champion (computed server-side via `h3.CellToBoundary(cell)`).
- The Flutter app renders these as `PolygonLayer` polygons with the champion's avatar and score overlaid.
- No H3 library needed in Flutter — all cell geometry comes from the API.

---

## 9. What This Replaces vs. Original Plan

| Original Plan | H3 Approach | Reason |
|---|---|---|
| `regions` table with polygon geometry | Removed | H3 cell ID is the region identity |
| `ST_Intersects` for region lookup | Removed | `h3.LatLngToCell()` — pure math |
| OSM boundary import scripts | Removed | Zero data needed |
| `FindRegionByPoint()` repository function | Removed | Replaced by in-process H3 call |
| Manual city compliance per country | Removed | Works globally on day 1 |
| `region_id UUID FK` on tasks | Changed to `h3_index VARCHAR(20)` | Direct cell reference |

PostGIS is **retained** for `ST_DWithin` radius search on tasks. It is not replaced — only the region membership lookup is eliminated.

---

## 10. Definition of Done

- [ ] `github.com/uber/h3-go/v4` added to `go.mod`.
- [ ] `migrations/023_create_region_champions_table.sql` runs without error.
- [ ] `migrations/024_update_tasks_geo.sql` adds `h3_index` and `region_id` columns to tasks.
- [ ] `POST /tasks` stores `h3_index` on the created task with no PostGIS region query.
- [ ] `GET /map/champions` returns champion pins for the given viewport.
- [ ] Weekly champion worker correctly reads ZSET top scorer and writes to `region_champions`.
- [ ] Redis ZSET keys follow the `leaderboard:arena:{h3_index}:week:{year}:{week_number}` pattern.
- [ ] Flutter map renders H3 cell polygons from API-provided boundary coordinates.
