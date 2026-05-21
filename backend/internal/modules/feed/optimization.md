# Feed Module — SQL Repository View Bottleneck Analysis & Optimization Ideas

> **Status:** Analysis complete. No code changes applied yet.  
> **Scope:** `backend/internal/modules/feed/` — all SQL queries, repository methods, and the main feed request flow.  
> **Goal:** Reduce `GET /api/v1/feed` latency by addressing the most expensive query and supporting bottlenecks.

---

## 1. The Main Feed Query (`GetSmartFeed`) — Critical Path

**File:** `smart_feed.go` — this single query dominates feed response time. It hits 7+ tables, uses 2 CTEs, 5 JOINs (2 LATERAL), 4 subqueries, a geospatial function, and a `random()` call in the WHERE clause.

```
Request flow:
  Handler.GetFeed() → Service.GetFeed() → repo.GetSmartFeed() → heavy SQL → Go blending
```

### 🔴 Bottleneck 1: `random()` in WHERE Clause (Distribution-Based Shadow Filtering)

The `base_posts` CTE has:

```sql
AND (report_control_level = 0
     OR random() <= (
         COALESCE(p.distribution_multiplier, 1.0) *
         CASE WHEN aps.count >= 2 THEN 0.4
              WHEN aps.count = 1  THEN 0.7
              ELSE 1.0
         END
     ))
```

**Why it's slow:**
- `random()` is called per-row and is non-deterministic — PostgreSQL cannot cache the query plan and must fully evaluate every candidate row.
- For authors with strikes, the computed penalty reduces visibility via random sampling instead of deterministic filtering.

**Optimization ideas:**
- **Pre-compute a "distribution score" column** on `posts` (updated by a trigger or the report-review flow). Replace the `random()` comparison with a deterministic filter: `distribution_score >= threshold`. The score can be a float computed from `distribution_multiplier * strike_penalty`, and the threshold can be seeded per-request via a single `random()` call in Go.
- **Alternative:** Move the random sampling to the Go layer. Remove `random()` from SQL, pull more candidates, and apply the sampling in Go with a single `math/rand` seed per request. This lets Postgres plan and cache the query properly.

### 🔴 Bottleneck 2: `ST_DWithin` Computed in Outer SELECT, Not Inner CTE

```sql
-- In the outer SELECT (after base_posts already returned up to 200 rows):
CASE WHEN $4 THEN (
    ST_DWithin(
        ST_SetSRID(ST_MakePoint(p.location_lon, p.location_lat), 4326)::geography,
        ST_SetSRID(ST_MakePoint($3, $2), 4326)::geography,
        50000
    )
) ELSE false END AS is_local
```

**Why it's slow:**
- The GiST index `idx_posts_location` exists on the posts table but is **never used** because the geo-filter runs in the outer SELECT, not inside `base_posts`' WHERE clause.
- Postgres cannot push this predicate down into the CTE.

**Optimization ideas:**
- **Push the `ST_DWithin` filter into `base_posts`** with an `OR` condition: if geo is enabled, include posts within 50km OR all posts (when expanding to world). This lets the GiST index actually get used.
- For the world-feed path (`$4 = false`), skip geo entirely — already handled by the CASE.
- For the local-feed path, add a separate branch or CTE that filters geographically first, then merges with world posts.

### 🟡 Bottleneck 3: LATERAL JOIN to `author_policy_strikes` — Per-Row Index Scan

```sql
LEFT JOIN LATERAL (
    SELECT COUNT(1) FROM author_policy_strikes aps
    WHERE aps.author_id = p.user_id
      AND aps.strike_type IN (...)
      AND aps.created_at >= NOW() - INTERVAL '30 days'
) aps ON true
```

**Why it's slow:**
- For 200 candidate posts, this runs 200 lateral subqueries, each doing an index scan on `author_policy_strikes`.
- The LATERAL value (`aps.count`) feeds into the `random()` filter, so it can't be moved after the fact.

**Optimization ideas:**
- **Pre-compute strikes on the `posts` table**: add a `current_strike_count INT DEFAULT 0` column updated by trigger/report flow. Then drop the LATERAL join entirely and filter directly on the pre-computed value.
- **Alternative:** Aggregate strikes in a derived table / CTE that joins on `p.user_id` once, instead of per-row LATERAL. For example, a CTE that groups `author_policy_strikes` by `author_id` and LEFT JOINs into `base_posts`.

### 🟡 Bottleneck 4: LATERAL JOIN to `post_media` — `json_agg` per Post

```sql
LEFT JOIN LATERAL (
    SELECT json_agg(
        json_build_object(...)
        ORDER BY pm.media_order
    ) AS attachments_json
    FROM post_media pm WHERE pm.post_id = p.id
) media ON true
```

**Why it's slow:**
- 200 posts = 200 LATERAL executions. Each aggregates media into JSON.
- `json_build_object` + `json_agg` has overhead per row.

**Optimization ideas:**
- **Batch media fetch in Go** after the main query. Collect all post IDs from the result set, run `SELECT * FROM post_media WHERE post_id = ANY($1::uuid[]) ORDER BY media_order`, and assemble the JSON in Go. This replaces 200 round-trips (or 200 lateral subqueries) with 1 query.
- **Alternative:** Keep the LATERAL but use `json_agg(to_jsonb(pm))` instead of `json_build_object` — slightly faster because it avoids reconstructing column-by-column.

### 🟡 Bottleneck 5: `IN (SELECT ally_id FROM allies)` — CTE Optimization Fence

```sql
AND (p.visibility = 'ANYONE' OR p.user_id IN (SELECT ally_id FROM allies))
```

**Why it's okay but could be better:**
- CTEs in PostgreSQL are optimization fences (materialized once), so the `IN` subquery scans a materialized result, not re-executing the CTE each time. That's good.
- However, for users with many allies and posts with `visibility = 'ALLIES_ONLY'`, this becomes a hash-join or nested-loop.

**Optimization ideas:**
- **Use `= ANY($allies)` with a Go-provided array** instead of a CTE. Pre-fetch the ally list in Go and pass it as a PostgreSQL array (`uuid[]`) parameter. This avoids the CTE materialization step entirely and lets Postgres pick an optimal plan (hash join / index scan).
- For truly large ally counts (e.g., 10k+), a temporary table or CTE with a hash index might still be better — benchmark both.

---

## 2. Supporting Query Optimizations

### 🟡 `GetUserPostsGrid` — Triple Correlated Subquery to `post_media`

```go
// Three separate subqueries inside the SELECT, each hitting post_media:
COALESCE((SELECT pm.thumbnail_url FROM post_media pm WHERE pm.post_id = p.id AND pm.media_order = 0 LIMIT 1), '') AS thumbnail_url,
COALESCE((SELECT pm.media_type FROM post_media pm WHERE pm.post_id = p.id AND pm.media_order = 0 LIMIT 1), '') AS media_type,
(SELECT COUNT(*) FROM post_media pm WHERE pm.post_id = p.id) > 1 AS has_multiple_media,
```

**Optimization ideas:**
- **Replace all three with one LATERAL join** that returns `thumbnail_url, media_type, media_count` from a single scan of `post_media` grouped by `post_id`. This cuts 3 subqueries into 1 per row.

### 🟡 `GetThreadedComments` — 4× Duplicate SQL Variants

The same ~40-line query appears 4 times (top-level with/without cursor, reply with/without cursor). Each has:
- `jsonb_array_elements(c.media_attachments)` per comment
- Correlated subquery for `reply_count`
- `random()` filter for shadow-supressed comments

**Optimization ideas:**
- **Template the SQL** with conditional clauses using Go string builders or a query builder. Reduces maintenance burden and makes it easier to apply the same index/optimization to all paths.
- **Move `renderCommentMediaAttachments` to Go**: instead of `jsonb_array_elements` in SQL, expand the `media_attachments` JSONB column in Go after fetching. JSONB expansion in Postgres is expensive per row.

### 🟡 `BatchFlushSeals` — Double Ledger Scan

```sql
seals_count = (SELECT COUNT(1) FROM ledger_entries WHERE ... metadata->>'post_id' = $1 ...),
seals_amount = (SELECT COALESCE(SUM(amount), 0) FROM ledger_entries WHERE ... metadata->>'post_id' = $1 ...)
```

**Why it's slow:**
- Two separate subqueries hitting `ledger_entries` with `metadata->>'post_id'` (unindexed JSONB extraction).
- Each UPDATE triggers two ledger scans per post.

**Optimization ideas:**
- **Combine into one subquery**: `FROM (SELECT COUNT(1), COALESCE(SUM(amount), 0) FROM ledger_entries ...) AS seals`. Cuts scans in half.
- **Add a GIN index on `ledger_entries(metadata)`** for `metadata->>'post_id'` and `category` lookups.
- **Alternative:** Add `seals_count` and `seals_amount` columns to `posts` and maintain them incrementally (increment in `AddSeal`, recompute from ledger only during reconciliation). This eliminates the ledger scan entirely from the hot path.

### 🟡 `GetSeals` — JSONB Field Extraction Unindexed

```sql
WHERE le.category = $1
  AND le.currency IN ($2, $3)
  AND le.metadata->>'post_id' = $4
```

**Optimization ideas:**
- **Add expression index**: `CREATE INDEX idx_ledger_entries_post_id ON ledger_entries ((metadata->>'post_id')) WHERE category = 'POST_SEAL'`.
- **Alternative:** Denormalize `post_id` as a real column on `ledger_entries` if it's a common query pattern.

---

## 3. Missing Indexes — Quick Wins

| Missing Index | Query(s) Affected | Expected Impact |
|---------------|-------------------|-----------------|
| `posts(created_at DESC, id DESC) WHERE is_archived=false AND is_deleted=false AND is_hidden_by_reports=false` | `GetSmartFeed` main sort/cursor | **High** — partial index avoids filtering dead rows during ORDER BY scan |
| `posts(user_id) WHERE is_archived=false AND is_deleted=false` | `GetSmartFeed` visibility gate (`p.user_id IN (allies)`) | **Medium** |
| `wallets(user_id, currency) INCLUDE (total_received_amount)` | Every feed/comment query (LEFT JOIN for centinels) | **Medium** — covering index avoids heap fetch |
| `author_policy_strikes(author_id, strike_type, created_at DESC)` | `GetSmartFeed` LATERAL + enforcement | **Medium** — composite for the exact query pattern |
| `ledger_entries(category, (metadata->>'post_id')) WHERE receiver_wallet_id IS NOT NULL` | `BatchFlushSeals`, `GetSeals` | **Medium** — expression index for JSONB field |

---

## 4. Redis Caching Opportunities

Currently, the feed path only caches **fatigue state** in Redis. Feed content always hits Postgres.

### Potential Caching Strategies

- **Pre-computed feed segments (5–10s TTL):** For heavy readers (high request rate), cache the top-50 feed with a short TTL. Invalidate on new post creation or user interaction.
- **Ally list cache:** The `user_relationships` CTE fetches allies per request. Cache the ally ID list per user in Redis (TTL 60s, invalidated on relationship change). Pass to `GetSmartFeed` as a `uuid[]` parameter instead of running a CTE.
- **Author reputation scores:** Wallet `total_received_amount` changes infrequently. Cache per author in Redis (TTL 300s) and only hit Postgres on miss.

---

## 5. Go-Layer Optimizations

### `ApplyReporterReputationDelta` — Sequential UPSERTs

```go
for _, reporterID := range reporterIDs {
    // One DB call per reporter
}
```

**Optimization ideas:**
- **Use `INSERT ... ON CONFLICT ... DO UPDATE` with `UNNEST`** for bulk upsert, same pattern as `BatchFlushLikes`.

### Post-Query Media Fetch (Go-side batching)

Instead of LATERAL `json_agg` per post in SQL, collect all post IDs, do a single `SELECT * FROM post_media WHERE post_id = ANY($1) ORDER BY media_order`, and assemble in Go. This turns 200 LATERAL executions into 1 batched query.

---

## 6. Priority Matrix

| Priority | Bottleneck | Expected Gain | Effort |
|----------|-----------|---------------|--------|
| **P0** | `random()` in WHERE clause — deterministic distribution | **Significant** — enables plan caching, eliminates per-row random | Medium (needs schema change: `distribution_score` column) |
| **P0** | Missing partial index for `(created_at DESC, id DESC) WHERE ...` | **High** — speeds up the cursor scan in every feed request | Low (one `CREATE INDEX`) |
| **P1** | `ST_DWithin` in outer SELECT instead of inner CTE | **Medium-High** — enables GiST index usage for local feed | Low-Medium (query restructure) |
| **P1** | LATERAL `author_policy_strikes` → pre-computed `current_strike_count` | **Medium** — eliminates 200-per-request subqueries | Medium (schema + trigger) |
| **P1** | LATERAL `post_media` → Go-side batch fetch | **Medium** — eliminates 200 lateral executions | Low (query + Go change) |
| **P1** | CTE `allies` → `uuid[]` parameter + Redis cache | **Medium** — skips CTE materialization on every request | Low-Medium |
| **P2** | `BatchFlushSeals` double ledger scan → single subquery | **Low-Medium** — speeds up the flush worker | Low |
| **P2** | Missing covering index on `wallets(user_id, currency) INCLUDE (total_received_amount)` | **Low-Medium** — avoids heap fetch on every feed query | Low |
| **P3** | `GetUserPostsGrid` triple subquery → single LATERAL | **Low** | Low |
| **P3** | `GetThreadedComments` 4× SQL duplication → templated | **Low** (maintenance, not performance) | Medium |
| **P3** | `ApplyReporterReputationDelta` sequential UPSERTs → `UNNEST` bulk | **Low** | Low |

---

## 7. Recommended First Steps (Without Code Changes)

1. **Run `EXPLAIN ANALYZE`** on the `GetSmartFeed` query with real production parameters (varying ally counts, geo-enabled/disabled, different report control levels) to get actual row counts and timing per node.

2. **Check `pg_stat_statements`** for the feed query to see:
   - `mean_exec_time` / `max_exec_time`
   - `shared_blks_read` vs `shared_blks_hit` (cache hit ratio)
   - `rows` returned vs actual usage

3. **Profile the Go layer** to determine the split between:
   - SQL query execution time
   - Row scanning (`rows.Scan()`)
   - Post-processing (`blendSmartFeedCandidatesWithShare`, `shuffle`, etc.)

4. **Create the partial index** `posts(created_at DESC, id DESC) WHERE ...` — this is a zero-risk, easy measurement baseline.

5. **Benchmark replacing `random()` with deterministic filtering** — this is the single biggest suspected bottleneck.
