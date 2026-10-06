# Feed Module — Response Time Optimization Report

> **Scope:** `backend/internal/modules/feed/` — 23 files, ~6,700 LoC  
> **Complaint:** Feed posts + media loading takes 1–2 seconds per request (upload + retrieval)  
> **Analysis date:** 2026-06-12  
> **Method:** Full code audit of every SQL query, Go processing path, caching layer, and upload pipeline

---

## Summary

The feed module is well-architected (clean layered design, write-behind caching for likes/seals, cursor pagination everywhere), but the **main feed query** and **upload flow** have compound bottlenecks that together explain the 1–2 second latency. No single fix will cut it — this is about several medium-impact changes stacking up.

### Where the time goes (estimated split for a typical feed request)

| Phase | Estimated % | Bottleneck |
|-------|-------------|------------|
| PostgreSQL query execution | 40–60% | `random()` in WHERE, LATERAL subqueries ×200, missing indexes |
| PostgreSQL query planning | 5–15% | `random()` prevents plan caching, string-formatted SQL prevents plan reuse |
| Row scanning + JSON unmarshaling | 10–15% | `json.Unmarshal` per row, `buildURL` per media item |
| Go-layer blending + geo | 5–10% | Haversine calculation on 200 candidates, ring counting, shuffle |
| Upload (separate endpoint) | 1–2s | Synchronous Vision API + synchronous storage upload |

---

## P0 — Critical (highest gain, must-fix)

### 1. `random()` in WHERE clause destroys query performance

**Location:** `smart_feed.go:getSmartFeed`, `base_posts` CTE  
**Also present in:** `GetThreadedComments` (all 4 variants)

```sql
AND (
    COALESCE(p.report_control_level, 0) = 0
    OR random() <= (
        COALESCE(p.distribution_multiplier, 1.0) *
        CASE WHEN (...) >= 5 THEN 0.4 ... END
    )
)
```

**What happens:** `random()` is non-deterministic. PostgreSQL **cannot cache the query plan** and must re-evaluate every candidate row with a per-row function call. For 200 candidates this means 200 `random()` calls + 200 LATERAL strike scans just to decide which 200 rows to keep, then another round of 200 LATERAL media scans in the outer SELECT.

**Fix strategy — Go-side sampling:**
1. Remove the `random()` filter and both `author_policy_strikes` LATERAL subqueries from the SQL entirely.
2. Pull the `distribution_multiplier` column (already in `posts`) and add a pre-computed `current_strike_count` column on `posts` (updated by trigger when strikes are created/expired).
3. In Go, compute `probability = distribution_multiplier * penaltyForStrikes(count)` with a single `rand.Float64()` per post.
4. PostgreSQL now gets a stable, cacheable query plan with zero per-row function volatility.

**Expected gain:** 200–400ms on the main feed query. Also unlocks plan caching for all subsequent requests.

---

### 2. LATERAL `post_media` `json_agg` — 200 subqueries per feed request

**Location:** `smart_feed.go` outer SELECT, `GetUserPostsGrid`, `GetUserPostsList`, `GetPost`, `SearchPosts`

```sql
LEFT JOIN LATERAL (
    SELECT json_agg(json_build_object(...) ORDER BY pm.media_order) AS media_json
    FROM post_media pm WHERE pm.post_id = p.id
) media ON true
```

**What happens:** For 200 feed candidates, PostgreSQL runs 200 separate index scans on `post_media`. Then `json_agg` + `json_build_object` reconstructs JSON per row. Then Go does `json.Unmarshal` per row. That's 200 round-trips through Postgres index → heap → JSON serialization → network → Go deserialization.

**Fix strategy — batch media fetch in Go:**
1. Remove the LATERAL `json_agg` from the SQL.
2. After returning posts, collect all `postID`s into a slice.
3. Run one query: `SELECT * FROM post_media WHERE post_id = ANY($1::uuid[]) ORDER BY media_order`.
4. Map media back to posts in Go with `map[uuid.UUID][]MediaAttachment`.
5. Apply `buildURL` once per media item (avoids redundant work).

**Expected gain:** 100–200ms on feed, proportionally more for posts with many media attachments. Also eliminates `json.Unmarshal` per row + redundant `buildURL` calls.

---

### 3. Missing partial index on `posts` for feed cursor scan

**Location:** Every feed/profile query that does `ORDER BY p.created_at DESC, p.id DESC`

Every feed request sorts through all non-archived, non-deleted, non-hidden posts to find the top 200 candidates. Without a partial index, this is a sequential scan or an index scan on the full table.

**Fix:**
```sql
CREATE INDEX idx_posts_feed_cursor
    ON posts (created_at DESC, id DESC)
    WHERE is_archived = false
      AND is_deleted = false
      AND is_hidden_by_reports = false;
```

**Expected gain:** 50–150ms by avoiding heap fetches for filtered-out rows during the index scan. Zero code change required.

---

## P1 — High Impact

### 4. Upload media blocks on synchronous Vision API call

**Location:** `handler.go:UploadMedia`

```go
// Image: run Vision API synchronously, blocking the HTTP response
if mediaType == "image" {
    inappropriate, _ := h.vision.DetectInappropriateContent(...)
    if inappropriate { return error }
}
// Then: synchronous upload to object storage
url, err := h.storage.Upload(...)
```

**What happens:** The upload handler makes a synchronous HTTP call to Google Vision API (~200–500ms) then a synchronous upload to object storage (~100–500ms depending on file size). The client waits for both before getting a response.

**Fix strategy — async vision + early URL return:**
1. For images: upload to storage first, return the URL immediately, then run Vision API asynchronously in a goroutine. If Vision flags the image, mark it as `processing_status = 'blocked'` and hide the post.
2. For videos: already async via asynq — good.
3. Return `202 Accepted` with the media URL immediately; the post creation endpoint can check `processing_status` before publishing.

**Expected gain:** 300–800ms off upload response time. Users get near-instant feedback.

---

### 5. CTE `allies` materialization on every feed request

**Location:** `smart_feed.go` CTE `allies`

```sql
WITH allies AS (
    SELECT target_user_id AS ally_id
    FROM user_relationships
    WHERE user_id = $1 AND relationship_type = 'ally'
)
```

**What happens:** PostgreSQL materializes the CTE (optimization fence). For users with thousands of allies, this is a full scan of `user_relationships` per request.

**Fix strategy — Redis cache + `uuid[]` parameter:**
1. Cache the user's ally ID list in Redis: `ally_list:{userID}` with 60s TTL.
2. Invalidate on relationship change (ally/unally events).
3. Pass as a PostgreSQL array parameter: `AND (p.visibility = 'ANYONE' OR p.user_id = ANY($6::uuid[]))`.
4. Skip the CTE entirely. PostgreSQL can use a hash join or index scan directly.

**Expected gain:** 20–80ms (proportional to ally count). Also eliminates the CTE materialization step.

---

### 6. ST_DWithin in outer SELECT — GiST index never used

**Location:** `smart_feed.go` outer SELECT

```sql
CASE WHEN $4 THEN (
    ST_DWithin(ST_SetSRID(ST_MakePoint(p.location_lon, p.location_lat), 4326)::geography,
               ST_SetSRID(ST_MakePoint($3, $2), 4326)::geography, 50000)
) ELSE false END AS is_local
```

**What happens:** The GiST index `idx_posts_location` exists but is **never touched** because the geo-filter runs after candidate selection, not during it. PostgreSQL can't push ST_DWithin into a CTE.

**Fix strategy — push geo into base_posts with UNION:**
```sql
base_posts AS (
    -- Local ring: 50km, GiST-indexed
    SELECT ... FROM posts p
    WHERE ... AND ST_DWithin(...)  -- uses idx_posts_location
    UNION
    -- World fill: remaining posts (no geo filter)
    SELECT ... FROM posts p
    WHERE ... AND p.id NOT IN (SELECT id FROM local_ring)
    ...
)
```

**Expected gain:** 50–100ms for users with geo enabled. The GiST index eliminates full-table scanning for the local component.

---

### 7. No feed content caching

**Current state:** Every feed request, even from the same user 500ms later, hits PostgreSQL for the full query. Only fatigue state is cached in Redis.

**Fix strategy — short-TTL feed cache:**
1. Cache the serialized feed response in Redis: `feed:{userID}:{cursorHash}` with 5–10s TTL.
2. Invalidate on: new post creation by allies, new post in user's geo ring, user interaction (like/seal changes position).
3. For heavy readers (detected by request frequency), this cache hit rate can be 80%+.

**Implementation consideration:** This is the highest-risk change because cache invalidation is complex (ally posts, geo posts, report hiding). Start with a 3s TTL for MVP then add targeted invalidation.

**Expected gain:** 90–95% reduction in DB load for returning users scrolling rapidly. Actual latency: from 400–800ms to 5–15ms (Redis read).

---

## P2 — Medium Impact

### 8. BatchFlushSeals — double ledger scan with unindexed JSONB

**Location:** `smart_feed.go:BatchFlushSeals`

```sql
UPDATE posts
SET seals_count = (SELECT COUNT(1) FROM ledger_entries WHERE ... metadata->>'post_id' = $1 ...),
    seals_amount = (SELECT COALESCE(SUM(amount), 0) FROM ledger_entries WHERE ... metadata->>'post_id' = $1 ...)
WHERE id = $2
```

**Fixes (two options, pick one):**

**Option A — Combine subqueries (quick, no schema change):**
```sql
SET (seals_count, seals_amount) = (
    SELECT COUNT(1), COALESCE(SUM(amount), 0)
    FROM ledger_entries
    WHERE category = 'POST_SEAL'
      AND metadata->>'post_id' = $1
      AND receiver_wallet_id IS NOT NULL
)
```

**Option B — Incremental counters (better, needs schema change):**
Add `seals_count` and `seals_amount` columns to `posts`. Increment in `AddSeal` handler. The flush worker only verifies/reconciles periodically. This eliminates the ledger scan from the hot flush path entirely.

**Also add expression index:**
```sql
CREATE INDEX idx_ledger_entries_post_seal
    ON ledger_entries ((metadata->>'post_id'))
    WHERE category = 'POST_SEAL' AND receiver_wallet_id IS NOT NULL;
```

**Expected gain:** 20–50ms per flush cycle. The worker runs every 30s, so this is a background improvement.

---

### 9. Missing covering index on wallets for author rank

**Location:** Every feed, comment, and seal query joins `wallets` for `total_received_amount`.

```sql
LEFT JOIN wallets w ON w.user_id = u.id AND w.currency = 'GOLD_SEAL'
```

**Fix:**
```sql
CREATE INDEX idx_wallets_rank
    ON wallets (user_id, currency)
    INCLUDE (total_received_amount);
```

**Expected gain:** 10–30ms per query by avoiding heap fetches for rank data.

---

### 10. GetThreadedComments — 4× duplicate SQL + random() + correlated subqueries

**Location:** `repository_impl.go:GetThreadedComments`

The same ~50-line query appears 4 times (top-level with/without cursor, replies with/without cursor). Each variant has:
- `random()` filter for shadow-suppression (same P0 issue as feed)
- Per-comment `reply_count` correlated subquery (N+1)
- `jsonb_array_elements` for comment media (expensive per row)

**Fix strategy:**
1. Template the SQL — extract the common SELECT into a constant, append WHERE/ORDER/LIMIT as needed.
2. Remove `random()` filter (same Go-side approach as P0 #1).
3. Batch `reply_count`: fetch all comment IDs, run `SELECT parent_comment_id, COUNT(*) FROM post_comments WHERE parent_comment_id = ANY($1) AND is_deleted = false GROUP BY parent_comment_id`, map back in Go.
4. Move comment media expansion to Go (`json.Unmarshal` the `media_attachments` JSONB column instead of `jsonb_array_elements` in SQL).

**Expected gain:** 50–100ms on comment-heavy posts. Also reduces maintenance burden.

---

### 11. GetUserPostsGrid — two LATERAL joins to post_media

**Location:** `profile_posts_repository.go:GetUserPostsGrid`

```sql
-- Two separate LATERAL subqueries hitting post_media:
LEFT JOIN LATERAL (
    SELECT pm.thumbnail_url, pm.video_1080p_url, pm.media_type
    FROM post_media pm WHERE pm.post_id = p.id ORDER BY pm.media_order LIMIT 1
) first_media ON true
LEFT JOIN LATERAL (
    SELECT COUNT(*) AS media_count
    FROM post_media pm WHERE pm.post_id = p.id
) media_stats ON true
```

**Fix:** Combine into one LATERAL:
```sql
LEFT JOIN LATERAL (
    SELECT
        MIN(pm.thumbnail_url) FILTER (WHERE pm.media_order = 0) AS thumbnail_url,
        MIN(pm.video_1080p_url) FILTER (WHERE pm.media_order = 0) AS video_1080p_url,
        MIN(pm.media_type) FILTER (WHERE pm.media_order = 0) AS media_type,
        COUNT(*) AS media_count
    FROM post_media pm WHERE pm.post_id = p.id
) media ON true
```

**Expected gain:** 10–30ms on profile grid views by halving `post_media` index scans.

---

### 12. ApplyReporterReputationDelta — sequential per-reporter UPSERTs

**Location:** `repository_impl.go:ApplyReporterReputationDelta`

```go
for _, reporterID := range reporterIDs {
    _, err := r.db.ExecContext(ctx, `INSERT INTO reporter_reputation ... ON CONFLICT ...`, reporterID)
}
```

**Fix:** Use `UNNEST` for bulk upsert (same pattern already used in `BatchFlushLikes`).

**Expected gain:** 10–20ms when processing reports with multiple reporters (usually 3–5).

---

## P3 — Low Impact (nice-to-have)

### 13. buildURL / buildAvatarURL per-item string operations

Every media URL, avatar URL goes through `buildURL` (string prefix check + concatenation). For 20 posts × 3 media × 3 URL fields = 180 `buildURL` calls per feed request.

**Fix:** Pre-compute the `publicURL` base once in the repository struct, use `strings.Builder` or simple concatenation. Cache avatar URLs with version strings in Redis (TTL = 5 min).

**Expected gain:** 5–15ms (micro-optimization, but adds up).

---

### 14. Prepared statement reuse for high-frequency queries

`GetSmartFeed`, `GetThreadedComments`, and `GetUserPostsList` are called at very high frequency but every call creates a new execution with `QueryContext`. PostgreSQL re-plans each time.

**Fix:** Use `sqlx.Preparex` for the top 5 queries and reuse prepared statements. Combined with removing `random()` (P0 #1), this gives stable, cached plans.

**Expected gain:** 5–20ms per query in plan time. More importantly, eliminates plan cache churn.

---

### 15. TimeAgo computation in Go on every row

```go
elapsed := time.Since(createdAt.Time)
switch {
case elapsed < time.Hour:
    resp.TimeAgo = fmt.Sprintf("%dm", int(elapsed.Minutes()))
...
```

**Fix:** Move `TimeAgo` computation to the client (JavaScript can do this with zero server cost). If server-side is required, use a pre-computed lookup table instead of `fmt.Sprintf` per row.

**Expected gain:** 2–5ms (minor, but every bit counts at 1–2s latency).

---

## Implementation Roadmap

### Phase 1 — Quick Wins (no schema changes, 1–2 days)
| # | Item | Files changed | Risk |
|---|------|--------------|------|
| 3 | Partial index `idx_posts_feed_cursor` | Migration only | None |
| 9 | Covering index `idx_wallets_rank` | Migration only | None |
| 8 | Expression index `idx_ledger_entries_post_seal` | Migration only | None |
| 2 | Batch media fetch in Go (remove LATERAL json_agg) | `smart_feed.go`, `repository_impl.go`, `profile_posts_repository.go` | Low |
| 12 | Bulk `ApplyReporterReputationDelta` | `repository_impl.go` | Low |

### Phase 2 — Structural Changes (schema changes, 3–5 days)
| # | Item | Files changed | Risk |
|---|------|--------------|------|
| 4 | Async Vision API for uploads | `handler.go` | Medium |
| 1 | Remove `random()` from SQL, add `current_strike_count` column | `smart_feed.go`, migration | Medium |
| 5 | Ally list Redis cache + `uuid[]` parameter | `smart_feed.go`, new cache code | Medium |
| 11 | Combine GetUserPostsGrid LATERAL joins | `profile_posts_repository.go` | Low |

### Phase 3 — Advanced (cache layer, 5–7 days)
| # | Item | Files changed | Risk |
|---|------|--------------|------|
| 7 | Short-TTL feed content cache | New cache layer, `service.go`, `handler.go` | High |
| 6 | Push ST_DWithin into base_posts CTE | `smart_feed.go` | Medium |
| 10 | Refactor GetThreadedComments (template + batch reply_count) | `repository_impl.go` | Medium |

---

## What NOT to Change

These patterns are correct and should stay:

- **Write-behind caching for likes/seals/fatigue** via Redis → PostgreSQL flush worker. This is well-designed and keeps the hot path fast.
- **Cursor-based pagination** everywhere — no offset pagination except admin reports. Correct choice.
- **Raw SQL with sqlx** — no ORM overhead. Good for feed queries.
- **Exactly-once seal semantics** with `SET NX` + idempotency keys. Correctly prevents double-counting.
- **Go-side blending** (80/20 allies-local vs world). Doing this in SQL would be far worse.
- **Adaptive geo rings** — good for scaling. No change needed.

---

## Estimated Total Improvement

With **Phase 1 + Phase 2** applied, the expected feed response time drops from **1–2 seconds** to approximately **200–400ms** for a typical request. With Phase 3 caching, **<50ms** for returning users.

The upload endpoint goes from **1–2 seconds** to **100–300ms** (async vision + early return).
