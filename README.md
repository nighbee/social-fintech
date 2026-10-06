# BrightBund

<div align="center">

[![Go Version](https://img.shields.io/badge/Go-1.25+-00ADD8?style=for-the-badge&logo=go&logoColor=white)](https://golang.org)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![React](https://img.shields.io/badge/React-18-61DAFB?style=for-the-badge&logo=react&logoColor=black)](https://react.dev)
[![Vite](https://img.shields.io/badge/Vite-6.0-646CFF?style=for-the-badge&logo=vite&logoColor=white)](https://vitejs.dev)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16%20%2B%20PostGIS-336791?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Redis](https://img.shields.io/badge/Redis-7%20Alpine-DC382D?style=for-the-badge&logo=redis&logoColor=white)](https://redis.io)
[![Kafka](https://img.shields.io/badge/Kafka-KRaft-231F20?style=for-the-badge&logo=apachekafka&logoColor=white)](https://kafka.apache.org)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com)

**High-integrity social platform engineered with economic security, anti-abuse mechanics, geospatial discovery, and gamified progression.**

[Key Features](#key-features) • [Architecture](#system-architecture) • [Project Layout](#project-layout) • [Getting Started](#getting-started) • [Core Modules](#core-domain-modules) • [Security & Anti-Abuse](#anti-abuse--economic-integrity) • [Testing](#testing--verification)

</div>

---

## Overview

**BrightBund** is a next-generation social ecosystem designed to eliminate social graph farming, engagement manipulation, and endless doomscrolling. Built upon a **dual-currency economy** (*Silver Seals* and *Gold Seals*) and an asynchronous **Rank Progression System**, BrightBund aligns incentives so that authentic community interaction, localized challenges, and high-value contributions are rewarded.

### The Idea

Traditional social networks reward volume: more scrolls, more likes, more follows. That creates bot farming, engagement pods, rage-bait, and doomscroll addiction. BrightBund inverts the incentive:

- **Value has a cost.** Giving a Seal spends real ledger balance. You cannot farm what you cannot mint.
- **Server is the only source of truth.** No client-side balances, ranks, timers, or geo claims are trusted.
- **Local first.** The feed mixer prioritizes Allies + Local geo-ring content over global viral content, with World fill capped at ~10–30%.
- **Time is bounded.** Anti-Doomscroll fatigue state degrades the feed after 20/30/40 minutes and enforces a 5-minute cooldown, synchronized across all devices via a wall-clock `break_start_at` anchor.
- **Status is earned slowly.** Ranks (Pearl → Supernova) derive from Gold Seal history and seasonal activity, computed asynchronously so they cannot be gamed in real time.
- **Territory is real.** H3 hexagonal cells (res 5 = district arena, res 3 = city, res 2 = country-scale) create weekly Champion competitions backed by Redis ZSET leaderboards and PostgreSQL snapshots.

### Core Tenets

- **Server as Source of Truth**: All economic calculations, balances, transactions, and status evaluations are strictly enforced server-side.
- **Double-Entry Ledger**: Complete immutability and financial integrity for all virtual currency operations. Amounts stored as integer **centinels** (1 Seal = 100 centinels), zero float drift.
- **Anti-Doomscroll Feed**: Geospatially-aware content distribution prioritizing local and quality community engagement over algorithmic addiction loops.
- **Geospatial Discovery (PostGIS + H3)**: Real-time region detection, champion tracking, and location-based community tasks.
- **Modular Monolith**: Strict Clean Architecture domain boundaries (`backend/internal/modules/*`) with single-binary operations and ACID transactions across domains. No cross-module business logic leaks.

---

## Key Features

- **Double-Entry Currency Engine**: Silver Seals (earned/soft currency) and Gold Seals (premium currency) backed by transactional ledger entries with optimistic locking, idempotency keys, and violation logging.
- **Geospatial Tasks & Maps**: PostGIS `ST_DWithin` radius search + H3 cell assignment (pure Go math, O(1), no DB), regional champion rankings, localized quest systems, and geo-filtered feeds.
- **Dynamic Leaderboards**: Real-time rankings powered by Redis Sorted Sets (ZSET) — per-arena, per-city, and global weekly keys with 8-day TTL and PostgreSQL snapshot history.
- **Asynchronous Progression**: Background worker daemon (Asynq + Kafka consumers) for rank recalculation, season rollover, badge decay, fatigue-state flush, likes/seals flush, and push dispatch (FCM/APNs/Huawei).
- **Real-Time Communication**: WebSocket-driven 1:1 messaging with accept/decline request lifecycle, presence tracking, delivery receipts, pin/mute/delete, and Redis Pub/Sub fan-out.
- **Smart Feed + Moderation**: Cursor-paginated smart blending (allies/local/world), adaptive geo rings (5/10/18 km → 30/50/70% local share), typed author strikes with publishing-restriction ladder (3→24h, 6→72h, 9→7d), shadow-mode distribution multipliers, and reporter reputation.
- **Multi-Client Support**: Cross-platform mobile client (Flutter, BLoC + go_router + Dio) and administrative operations dashboard (React 18 + Vite 6, plain CSS modules, fetch-only).
- **Hardened Edge**: Nginx gateway (SSL termination, 500 MB uploads, scanner drops), Fail2ban jails (444/botsearch/404), Fiber rate limiters on auth/register/chat/settings, and structured Zap logging with request IDs.

---

## System Architecture

The platform follows a **Modular Monolith** architecture with strict **Clean Architecture** boundaries, isolating domain logic while benefiting from single-binary operations and zero distributed transaction overhead during early growth.

```
                              ┌───────────────────────┐
                              │  Flutter Mobile App   │ (iOS / Android)
                              └───────────┬───────────┘
                                          │  HTTPS / WSS
                                          ▼
                              ┌───────────────────────┐
                              │     Nginx Gateway     │ (SSL / Fail2ban / /admin / /minio / /swagger)
                              └───────────┬───────────┘
                                          │
            ┌─────────────────────────────┼─────────────────────────────┐
            │                             │                             │
            ▼                             ▼                             ▼
┌───────────────────────┐     ┌───────────────────────┐     ┌───────────────────────┐
│     React Admin SPA   │     │    Go API Gateway     │     │   Go Worker Daemon    │
│   (Vite Dashboard)    │     │   (Fiber v2 Server)   │     │ (Asynq/Kafka/Seasons) │
└───────────────────────┘     └───────────┬───────────┘     └───────────┬───────────┘
                                          │                             │
            ┌─────────────────────────────┴─────────────────────────────┴┐
            │                                                            │
            ▼                                                            ▼
┌───────────────────────┐     ┌───────────────────────┐     ┌───────────────────────┐
│  PostgreSQL + PostGIS │     │        Redis 7        │     │      MinIO / S3       │
│ (77 migrations, Geo)  │     │ (Cache, ZSET, Queue)  │     │    (Media Storage)    │
└───────────────────────┘     └───────────────────────┘     └───────────────────────┘
                                          │
                                          ▼
                              ┌───────────────────────┐
                              │   Kafka (KRaft)       │ (system.events, push.dispatch,
                              │  + Push Dispatcher    │  push.ios/android/huawei, dlq)
                              └───────────────────────┘
```

**Request path:** Flutter / SPA → Nginx (`/api/v1/` → `brightbund-api:8080`, `/minio/` → MinIO, `/admin` → SPA dist, `/swagger/` → API docs) → Fiber middlewares (requestid → Zap logger → CORS → `RequireAuth` + `TouchSession` → `RequireAdmin` where needed → per-route limiters).

---

## Project Layout

```
.
├── app/                  # Mobile application (Flutter 3.x, BLoC, GoRouter, Dio)
│   ├── lib/src/features/ # auth, home(feed/store/notifications), profile, map, chats, rating
│   ├── lib/src/core/     # router, api client/endpoints, widgets, DI (get_it+injectable)
│   └── pubspec.yaml      # mapbox, h3_flutter, purchases_flutter, geolocator, firebase
├── backend/              # Core API & Worker services (Go 1.25, Fiber v2, sqlx)
│   ├── cmd/
│   │   ├── api/          # Main HTTP/WebSocket API entrypoint
│   │   ├── worker/       # Asynchronous background job worker daemon
│   │   └── migrate/      # migrate / backfill-gold-weekly / reconcile-gold-weekly /
│   │                     # backfill-gold-seasonal / reconcile-gold-seasonal
│   ├── internal/
│   │   ├── modules/      # Strict domain modules (auth, feed, economy, map, etc.)
│   │   ├── server/       # Fiber app, routing (server.go), middleware
│   │   ├── config/       # YAML + env overlay with sane defaults
│   │   └── platform/     # cache, eventbus(kafka), email, vision, translation, observability
│   ├── migrations/       # 77 SQL schema migrations (000_enable_postgis → 077_feed_opt_phase2)
│   └── docs/             # Swagger / OpenAPI contracts (swagger.yaml/json, docs.go)
├── spa/                  # Admin Control Center (React 18, Vite 6, CSS modules)
│   └── src/              # api/, context/AuthContext, components/Layout, pages/*, hooks/useApi
├── docs/                 # Product specifications (RPD, Economy, Geo, Feed, command.md)
├── infras/               # Dev Docker Compose (db:5433, redis:6380, api:8081 + Air hot-reload)
├── docker-compose.yml    # Prod compose: db, redis, api, worker, minio, kafka, kafka-setup, nginx, fail2ban
├── nginx/                # Reverse proxy configs & SSL orchestration
├── fail2ban/             # jail.local + filter.d (nginx-444, nginx-404, nginx-botsearch)
├── google/               # Firebase service-account JSON (gitignored in practice)
├── tests/                # 19 shell integration suites (curl-based, see Testing)
├── .github/workflows/    # ci.yml (lint + go test) + deploy.yml (build api/worker/migrate + SSH deploy)
├── index.html / privacy.html / terms.html / account-deletion-info.html / 404.html
└── .env.example          # Production env template (DB, Redis, JWT, ports)
```

---

## Tech Stack (used)

### Backend (Go 1.25, module `github.com/brightbund-backend`)

| Concern | Technology |
|---|---|
| HTTP | `gofiber/fiber/v2`, `gofiber/websocket/v2`, fasthttp, `cors`, `limiter`, `requestid` |
| DB | PostgreSQL 16 + PostGIS (`postgis/postgis:16-3.4-alpine`), `jmoiron/sqlx`, `lib/pq`, 77 file migrations |
| Geo math | `uber/h3-go/v4` (CGO, needs gcc/musl-dev in Dockerfile) |
| Cache / realtime | `redis/go-redis/v9` — fatigue state, likes/seals buffers, ally lists, ZSET leaderboards, Pub/Sub |
| Jobs / events | `hibiken/asynq`, `robfig/cron/v3`, `segmentio/kafka-go` (KRaft, no ZooKeeper) |
| Auth | `golang-jwt/jwt/v5`, `coreos/go-oidc/v3`, `MicahParks/keyfunc`, `firebase.google.com/go/v4`, `golang.org/x/crypto` (bcrypt) |
| Storage / media | `minio/minio-go/v7`, ffmpeg path in config, Vision moderation (`cloud.google.com/go/vision`, `cloud.google.com/go/translate`) |
| Config | `gopkg.in/yaml.v3`, `joho/godotenv`, env overlay (`DB_*`, `REDIS_*`, `ECONOMY_*`) |
| Observability | `go.uber.org/zap`, internal `platform/observability` (JSON + Prometheus text at `/admin/ops/metrics`) |
| API docs | `swaggo/fiber-swagger`, `swaggo/swag`, `backend/docs/swagger.yaml` |
| Tests | `stretchr/testify`, `alicebob/miniredis/v2`, `go test ./...` + `tests/*.sh` curl suites |

### Mobile (Flutter `>=3.1.5 <4.0.0`, version `1.0.0+6`)

- **State:** `flutter_bloc` + `rxdart`; **errors:** `fpdart` Either
- **Nav:** `go_router` (auth/home/create-post/notifications/search/store/map/rating/chats/chat/:id/profile/settings/allies/public-profile/:id/developer_features)
- **Network:** `dio` + `talker_dio_logger`; **DI:** `get_it` + `injectable` (+ generators: `build_runner`, `freezed`, `json_serializable`, `flutter_gen_runner`)
- **Storage:** `flutter_secure_storage` (tokens), `shared_preferences`, `package_info_plus`, `device_info_plus`, `uuid`
- **Auth:** `firebase_core`, `firebase_auth`, `google_sign_in`, `sign_in_with_apple`, `app_links` (magic links)
- **Media:** `image_picker`, `video_player`, `video_compress`, `path_provider`, `saver_gallery`, `share_plus`, `url_launcher`, `permission_handler`
- **Geo:** `geolocator`, `mapbox_maps_flutter`, `h3_flutter` (client-side H3), `latlong2`/`flutter_map` path per Geo spec (OSM default, Mapbox upgrade = one tile URL swap)
- **Monetization:** `purchases_flutter` (RevenueCat) → backend `/payment/webhook` validation → ledger mint
- **UI:** `flutter_svg`, `gap`, `timeago`, `syncfusion_flutter_sliders/core`, Lora + CanelaDeckTrial fonts
- **Run:** `flutter run --dart-define-from-file=app/.env` (see `app/README.md`); flavors via `lib/app/flavor_builds.dart`, `main_dev.dart`

### Admin SPA (`brightbund-admin-spa@0.1.0`)

- React 18.3.1 + react-dom + react-router-dom v6, Vite 6 (`@vitejs/plugin-react`), base `/admin/`, dev port 3001 with `/api → localhost:8080` proxy
- No Redux/Tailwind/UI lib/axios — `fetch` wrapper (`src/api/client.js`), `AuthContext` (localStorage JWT), `useApi` hook, CSS modules
- Pages: Login, Dashboard (ops metrics), Users + UserDetail (ban/adjust-balance/violations), Posts + PostDetail (delete/comments), Reports (pending/reviewed filters), Seasons, Leaderboard admin, 404

### Infrastructure / Edge

- **Prod compose** (`docker-compose.yml`): `db` (PostGIS, 256 MB, tuned `shared_buffers/max_connections`), `redis` (7-alpine, 80 MB LRU, no AOF), `api` + `worker` (from `backend/Dockerfile`, CGO builds), `minio` (:9001 console), `kafka` (KRaft single-node, 384 MB, 24h retention) + `kafka-setup` (creates `system.events`, `push.dispatch`, `push.ios`, `push.android`, `push.huawei`, `push.dlq`), `nginx` (alpine, serves legal pages + `/admin` dist), `fail2ban` (host network, watches `nginx/logs`)
- **Dev compose** (`infras/docker-compose.yml`): `db:5433`, `redis:6380`, `api:8081` with `Dockerfile.dev` + Air (`.air.toml`, `.air.worker.toml`)
- **Nginx:** `/health`, `/api/v1/`, `/swagger/`, `/minio/`, `/admin`, `/account-deletion`, `/privacy`, `/terms`, custom 404; drops non-GET/POST/PUT/DELETE/OPTIONS/PATCH (444) and `php|aspx|env|bak|git` probes
- **Fail2ban:** `bantime=3600`, `findtime=600`; `nginx-444 maxretry=2`, `nginx-botsearch maxretry=2`, `nginx-404 maxretry=10`
- **CI/CD:** `ci.yml` (PostGIS service + golangci-lint + `go test ./...` on main/develop); `deploy.yml` (build api/worker/migrate + test, SSH to `35.209.210.231` → `git pull` + `docker compose up -d --build` on main/develop/feed, ignores `app/**`)

---

## Core Domain Modules

The backend is partitioned into isolated domain packages inside [`backend/internal/modules/`](backend/internal/modules/):

| Module | Responsibilities |
|---|---|
| **`auth`** | Email/password + phone OTP + Firebase phone/email + Apple/Google OIDC; JWT access+refresh rotation, session tracking (`TouchSession`), device binding, 2FA, admin login/ban/lookup, activation hardening |
| **`profiles`** | User metadata, avatar management, privacy preferences, allies graph, block/restrict/report, relationship status, stats cache, public rank catalog |
| **`economy`** | Idempotent double-entry ledger for Silver and Gold seals, cooldown enforcement, store transactions, referrals, accruals, admin adjust + violation logs |
| **`feed`** | Geo-aware post creation, reactions, comments, media attachments, anti-doomscroll pacing, moderation queue, admin post/comment tools |
| **`map`** | PostGIS spatial queries, H3 assignment, region bounding, territory champions, location-bound tasks with apply→accept→verify-code→confirm lifecycle |
| **`ranks`** | Catalog + async rank calculation, status level shifts (C/B/A/S), seasonal progression |
| **`leaderboard`** | High-performance Redis ZSET leaderboards (arena/city/global weekly) + admin scope/add/remove/adjust/reset |
| **`seasons`** | Season lifecycle, current/archive views, admin force-close, snapshot worker |
| **`chat`** | Real-time WebSocket 1:1 messaging, request accept/decline, presence tracking, delivery receipts, pin/mute/delete |
| **`notifications`** | Kafka-driven dispatcher → FCM/APNs/Huawei workers, device registry, read/unread, preferences, retry + DLQ |
| **`payment`** | RevenueCat webhook + App Store / Play Store IAP receipt validation and ledger balance fulfillment |
| **`settings`** | Security (password/2FA/sessions/delete-account), feed (time-limit), interactions (messages/comments/mentions/blocked/keywords), notifications prefs, support/bug/contact |

---

## Economy & Data Specs

Full design: [`docs/Economy_Transaction_System.md`](docs/Economy_Transaction_System.md).

### Dual-table architecture

```sql
CREATE TABLE wallets (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    currency VARCHAR(20) CHECK (currency IN ('SILVER_SEAL', 'GOLD_SEAL')),
    balance BIGINT NOT NULL DEFAULT 0,          -- centinels
    free_balance BIGINT NOT NULL DEFAULT 0,     -- free silver from accruals
    total_sent_amount BIGINT NOT NULL DEFAULT 0,
    total_received_amount BIGINT NOT NULL DEFAULT 0,
    last_daily_accrual_at TIMESTAMP,
    last_transfer_at TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 1,          -- optimistic locking
    created_at TIMESTAMP, updated_at TIMESTAMP,
    UNIQUE(user_id, currency)
);

CREATE TABLE ledger_entries (
    id UUID PRIMARY KEY,
    amount BIGINT NOT NULL CHECK (amount > 0),  -- always positive, centinels
    currency VARCHAR(20) CHECK (currency IN ('SILVER_SEAL', 'GOLD_SEAL')),
    sender_wallet_id UUID REFERENCES wallets(id),    -- NULL = system mint
    receiver_wallet_id UUID REFERENCES wallets(id),  -- NULL = system burn
    category VARCHAR(50) NOT NULL,
    reference_id VARCHAR(128) NOT NULL UNIQUE,  -- idempotency key
    metadata JSONB,
    created_at TIMESTAMP NOT NULL
);
```

- **Centinels:** `1.00 Seal = 100 centinels` (`SealsToCentinels` uses `math.Round`). No floats in storage.
- **Flow:** `BeginTx → GetWallet FOR UPDATE → validate → mutate → UpdateWalletWithVersion (WHERE version=?) → CreateLedgerEntry → Commit`. Version mismatch → `ErrOptimisticLock` → rollback → client retries.
- **History query:** join `ledger_entries` to sender/receiver wallets, filter by currency/category, `ORDER BY created_at DESC LIMIT/OFFSET`; service marks each row SENT/RECEIVED.

### Currencies

| Currency | Code | Purpose | Earn | Caps / notes |
|---|---|---|---|---|
| Silver Seal | `SILVER_SEAL` | Free/earned | Daily accrual (1.00 / 48h), referrals (1.00), task rewards, signup bonus | `free_balance` capped (default 500 centinels = 5.00); spend deducts free first |
| Gold Seal | `GOLD_SEAL` | Premium | IAP deposit (Apple/Google/RevenueCat) | No cap; drives ranks; direct admin mint disabled |

### Transaction categories

`DAILY_ACCRUAL`, `REFERRAL_BONUS`, `SIGNUP_BONUS`, `P2P_TRANSFER` (+ legacy `transfer` alias), `TASK_CREATION` (burn), `TASK_REFUND`, `TASK_REWARD`, `IAP_DEPOSIT` (mint), `POST_SEAL`, `SYSTEM_CORRECTION`.

Reference-ID patterns: `accrual_<user>_<date>`, `transfer_<sender>_<receiver>_<ts>`, IAP receipt ID, `referral_<referrer>_<referee>`, `task_creation_<taskID>`. Duplicates return the existing result instead of double-minting.

### Anti-abuse knobs (defaults from `internal/config/package.go`, overridable via YAML/env)

- Monthly/daily transfer cap: **50** (`MaxDailyTransfers`, `transfer_limits` per `YYYY-MM`)
- P2P cooldown: **60s** (`last_transfer_at` + `TransferCooldownSeconds`)
- Free silver cap: **500 centinels** (`MaxFreeSilverBalance`)
- Accrual: **100 centinels every 48h** (`DailyAccrualCents`, `AccrualIntervalHours=48`)
- Referral: **100 centinels**, one referee → one referrer, deferred until referee is `active` with no `restrictions_until`
- No self-transfer; balance checked before every mutation; free balance spent first
- Seal-to-post/user cooldown ladder: L1 30d → L2 45d → L3 60d → L4 90d → L5 120d with decay thresholds
- Violations table (`economy_violations`): `COOLDOWN_BREACH`, `RATE_LIMIT_EXCEEDED`, `FREE_SILVER_CAP`, `MONTHLY_LIMIT_EXCEEDED`, `INSUFFICIENT_FUNDS_ATTEMPT`, `REPEAT_TRANSFER_PATTERN` (+ IP + endpoint for forensics)

### Ranks (Gold-driven, from `modules/ranks/catalog.go`)

| Rank | Quality | Seals | Levels |
|---|---|---|---|
| Pearl | Awareness | 0–10 | C/B/A/S quartiles |
| Moonstone | Intention | 10–25 | C/B/A/S |
| Jade | Discipline | 25–60 | C/B/A/S |
| Lapis Lazuli | Influence | 60–140 | C/B/A/S |
| Ammolite | Fortitude | 140–260 | C/B/A/S |
| Onyx | Transcendence | 260–700 | C/B/A/S |
| Supernova | Sovereign | 700+ | — (top tier) |

`CalculateRankAndLevel` splits each rank range into C/B/A/S quartiles; `FormatRankTitle` renders `Name | Quality | Level`.

---

## Feed, Anti-Doomscroll & Moderation

Full designs: [`docs/Feed_Module_Changes.md`](docs/Feed_Module_Changes.md), [`issues/opt-feed.md`](issues/opt-feed.md).

### Smart feed

- Mixer: **Allies + Local geo-ring + World (~10%)**; Go-side blending (80/20 allies-local vs world), shuffle, per-author repeat cap (2 on first pass, backfill without cap when pool is thin), deterministic tie-break `ORDER BY created_at DESC, id DESC`.
- Query: `GET /api/v1/feed?lat=&lon=&cursor=&limit=` (default 10, cursor = RFC3339Nano). Profile grids/lists: `GET /profiles/me/posts`, `GET /profiles/:id/posts` (grid default 18/max 30), `.../posts/list` (cards default 10/max 30, `anchor_post_id` inclusive via `created_at+1µs`).
- Adaptive geo (config `feed.*`): rings **5 / 10 / 18 km** (`kRing 1→2→3`), 24h activity window; high (≥30 posts + ≥15 authors) → **70%** local, medium (≥15 + ≥8) → **50%**, low → **30%**; smallest passing ring wins, else kRing 3.
- Perf work (phases in `opt-feed.md`): batch media fetch (kill LATERAL `json_agg ×200`), partial index `idx_posts_feed_cursor`, covering `idx_wallets_rank`, expression index on `ledger_entries(metadata->>'post_id') WHERE POST_SEAL`, ally-list Redis cache, async Vision, Go-side `random()` sampling, short-TTL feed cache. Target: 1–2s → 200–400ms → <50ms cached.

### Anti-Doomscroll (cross-device safe)

```
[ACTIVE] ── limit reached ──► [COOLDOWN]
   ▲                              │
   │      away ≥ BreakDuration     │ (via break_start_at anchor)
   └────────── reset ◄─────────────┘
[ACTIVE] ── away ≥ 5 min ──► reset counter → [ACTIVE @ 0]
```

- Constants: user limit `feed_time_limit_mins ∈ {0,20,30,40}` (default 20 min = 1200s), break **300s**, away-reset **300s**, anti-cheat buffer **5s**.
- `GET /feed/state` (on open/return, applies off-feed → break transitions) + `POST /feed/state/sync {delta_seconds}` (periodic accumulator, clamped to wall-clock + 5s). Response: `accumulated_active_seconds`, `is_in_cooldown`, `break_seconds_remaining`, `accumulated_break_seconds`, `max_allowed_seconds`, `server_timestamp`, `action_required ∈ {trigger_friction, enforce_cooldown}`.
- Flutter rule: friction % = `accumulated/max` from server only, never local; countdown from `break_seconds_remaining`; one row per user in `feed_fatigue_states` (`break_start_at` immutable anchor).
- Write-behind: Redis buffers → worker flushes every **30s** (`flushFatigueStates`, `flushLikes`, `flushSeals` with requeue on PG failure).

### Posts / comments / likes / seals

- `POST /posts {caption, visibility: ANYONE|ALLIES_ONLY, comment_permission: ANYONE|ALLIES_ONLY|NO_ONE, media_attachments[]}` with post-idempotency keys; media via `POST /feed/media/upload` (Vision check, MinIO/S3, multi-res video fields).
- Threaded comments (`parent_id`), 4-variant cursor queries; like = toggle (`POST /posts/:id/likes`, `viewer_has_liked`); seals = monetized reaction (`POST /posts/:id/seals {amount 1–10, comment}` → economy debit → Redis counters → worker → `seals_count/seals_amount`); `GET /posts/:id/seals` lists givers.
- Moderation: `accepted` normalized to `actioned`; typed author strikes (`post_removed`, `comment_removed`, legacy `content_violation` read-compat); ladder **3→24h / 6→72h / 9→7d** publishing restriction on 30-day strikes; distribution multiplier + strike penalty in ranking; reporter reputation deltas (bulk `UNNEST`); configurable thresholds/ratios in `config.yaml` (`moderation.*`).

---

## Geo, Tasks & Champions

Full design: [`docs/Geo_Module.md`](docs/Geo_Module.md).

| H3 res | Avg area | BrightBund use |
|---|---|---|
| 2 | ~86,700 km² | Country-scale zone |
| 4 | ~1,770 km² | Large city |
| 5 | ~253 km² | **City district / Champion arena (primary)** |
| 6 | ~36 km² | Neighborhood task density |
| 7 | ~5 km² | Hyper-local feed radius |

- **No `regions` table.** `h3.LatLngToCell(lat,lng,5)` in Go is the region identity (O(1), zero imports, global day-1); parent `cell.Parent(3)` = city. Tasks store `location GEOMETRY(Point,4326)` for `ST_DWithin` + `h3_index`/`region_id` varchars for zone lookups.
- **Leaderboards:** `leaderboard:arena:{h3}:week:{yyyy}:{ww}`, `leaderboard:city:{parent}:week:...`, `leaderboard:global:week:...` (pipeline-updated on Gold earn; champion = `ZREVRANGE 0 0`; 8-day TTL).
- **Weekly cycle** (Monday 00:00 UTC worker): top scorer per cell → `region_champions(h3_index,h3_res,user_id,week,year,gold_score)` snapshot (+ lat/lon + geo names via migrations 054/055) → push → ZSET reset.
- **Viewport pins:** `GET /map/champions?swLat=&swLng=&neLat=&neLng=` → `PolygonToCells(res5)` → single batched champion query; server returns `CellToBoundary` polygons so Flutter draws `PolygonLayer` without an H3 lib (though `h3_flutter` is also vendored).
- **Tasks:** `POST /tasks` = ACID `Debit wallet → Insert task` (burn → `INSUFFICIENT_FUNDS` → Quiet Shop heartbeat, no popup); lifecycle `apply → accept/reject → verify-code → confirm` with verification codes, worker Needed counts, expiry cleanup, refunds (`TASK_REFUND`); `GET /tasks/nearby|my|applied`, `POST /map/region` (H3 res2/4/5 + admin hierarchy via `GET /map/h3/:h3/admin`), `GET /map/ranking/timer`.
- **Tiles:** `flutter_map` + OSM for MVP (free, no key); Mapbox = one `urlTemplate` swap.

---

## Auth, Profiles, Chat, Notifications, Seasons, Settings

- **Auth (`/auth/*`):** `register-email/login-email/check-email`, legacy `phone/request|verify`, `register-phone`, `email/request|verify`, Firebase `firebase-phone-login|register` + `firebase-email-login|register`, Apple/Google OIDC, `login`, `refresh`, `logout`. Guards: `RequireAuth` (JWT + revocation + shadow-ban/block) + `TouchSession` (`last_used_at`). Limiters: auth 10/min, register 3/10min (IP-keyed). Captcha/phone/username/email modules + device metadata + activation gate (`activation_status`, `restrictions_until`, distinct login days + meaningful actions + per-device daily caps).
- **Profiles (`/profiles/*`, `/users/search`):** `me` CRUD + avatar upload + stats + allies + delete; `/:id` public view/stats/posts/relationship; allies add/remove/list; block/unblock, restrict/unrestrict, report user; search by name/username + admin email search.
- **Chat (`/chats/*`, WS `GET /chats/ws`):** `media/upload`, `conversations` list, `conversations/direct` open, `:id/messages` list/send (25/min per-user limiter), `:id/read`, `accept/decline` requests, pin/unpin message, pinned list, delete message, mute/pin/delete conversation. Redis Pub/Sub scales WS across instances.
- **Notifications (`/notifications/*`):** list, `unread-count`, `read-all`, `:id/read`, `devices` register, `devices/:token` delete; Kafka topics `push.dispatch → push.ios/android/huawei → push.dlq`, per-platform workers + retry, preferences + honor-score + UI-extension migrations.
- **Seasons (`/seasons/*`, `/admin/seasons`):** `current`, `me/archive`, `users/:id/archive`; admin list + `:id/force-close`; archive tables + snapshot worker + weekly/seasonal gold backfill/reconcile via `cmd/migrate`.
- **Settings (`/settings/*`):** `security` (get/change-password/2fa enable|disable/sessions list|delete|delete-all/delete-account reason|verify|finalize, 5/hr sensitive limiter), `feed` (get/patch time-limit), `interactions` (messages/comments/mentions/blocked/keywords CRUD), `notifications` prefs, `support` (bugs/contact).
- **Leaderboard (`/leaderboard`, `/admin/leaderboard/*`):** scoped get + my-rank; admin scopes/add-user/remove-user/adjust-score/reset.
- **Admin (`/admin/*`):** public `POST /admin/login` (email+password → JWT iff `is_admin`); users get/search, `ban` (temporary/permanent + session revoke), posts get/search/delete (incl. shadow-banned), comments delete, reports queue (`status/target_type/reason/limit/offset`), economy `adjust` (silvers; Gold mint disabled) + `violations`, ops `metrics` (JSON + Prometheus), seasons + leaderboard admin above. SPA mapping in [`spa/routes.md`](spa/routes.md), build plan in [`spa/implementation-plan.md`](spa/implementation-plan.md).

---

## API Reference

Base: `/api/v1` (prod `https://brightbund.app/api/v1`). Full route wiring in [`backend/internal/server/server.go`](backend/internal/server/server.go); contracts in [`backend/docs/swagger.yaml`](backend/docs/swagger.yaml) + Swagger UI at `/swagger/`; mobile endpoint map in [`app/lib/src/core/api/client/endpoints.dart`](app/lib/src/core/api/client/endpoints.dart).

| Area | Endpoints |
|---|---|
| Health | `GET /health`, `GET /api/v1/health` |
| Auth | `POST /auth/login|register-email|login-email|check-email|phone/request|phone/verify|register-phone|email/request|email/verify|firebase-phone-login|firebase-phone-register|firebase-email-login|firebase-email-register|refresh|logout`, `POST /admin/login` |
| Economy | `GET /economy/balance|transactions|limits|referral/stats`, `POST /economy/transfer|accrual/claim|posts/:postID/seals|users/:userID/gift`, `POST /economy/admin/adjust`, `GET /economy/admin/violations` |
| Profiles | `GET /users/search`, `GET /profiles/ranks|search|me|me/stats|me/allies|me/posts|me/posts/list|:user_id|:user_id/stats|:user_id/allies|:user_id/relationship|:user_id/posts|:user_id/posts/list`, `PATCH /profiles/me`, `POST /profiles/me/avatar|:user_id/allies|:user_id/block|:user_id/restrict|:user_id/report`, `DELETE /profiles/me|:user_id/allies|:user_id/block|:user_id/restrict` |
| Ranks | `GET /ranks`, `GET /ranks/me` (legacy `GET /profiles/me/rank`) |
| Leaderboard | `GET /leaderboard|leaderboard/me`, admin `GET /admin/leaderboard/scopes`, `POST /admin/leaderboard/add-user|remove-user|adjust-score|reset` |
| Feed | `GET /feed|feed/state|feed/search/profiles`, `POST /feed/state/sync|feed/media/upload|feed/comments/:id/likes` |
| Posts | `POST /posts`, `PATCH|DELETE /posts/:id`, `GET|POST /posts/:id/comments`, `DELETE /posts/:id/comments/:comment_id`, `POST /posts/:id/comments/:comment_id/report|translate`, `POST /posts/:id/report|likes`, `GET /posts/:id/likes|seals`, `POST /posts/:id/seals` |
| Tasks/Map | `POST /tasks`, `GET /tasks/my|applied|nearby|:task_id|:task_id/applications|:task_id/applications/:app_id`, `DELETE /tasks/:id`, `POST /tasks/:id/apply|.../applications/:app_id/accept|reject`, `DELETE .../applications/:app_id`, `POST .../verify-code|confirm`, `POST /map/region`, `GET /map/champions|map/ranking/timer|map/h3/:h3/admin` |
| Chat | `GET /chats/ws` (WS), `POST /chats/media/upload|conversations/direct|conversations/:id/messages|conversations/:id/read|conversations/:id/accept|decline|pin-message`, `GET /chats/conversations|conversations/:id/messages|conversations/:id/pinned-messages`, `DELETE /chats/conversations/:id/messages/:msg_id|conversations/:id/pin-message|conversations/:id`, `PUT /chats/conversations/:id/mute|pin` |
| Notifications | `GET /notifications|notifications/unread-count`, `POST /notifications/read-all|:id/read|devices`, `DELETE /notifications/devices/:token` |
| Seasons | `GET /seasons/current|seasons/me/archive|seasons/users/:id/archive`, admin `GET /admin/seasons`, `POST /admin/seasons/:id/force-close` |
| Settings | `GET|PATCH /settings/feed|notifications|interactions*|security*`, `POST /settings/support/bugs|contact`, `DELETE /settings/security/sessions*|security/delete-account|interactions/blocked/:id|interactions/messages/keywords/:id` |
| Payment | `POST /payment/webhook` (RevenueCat; no JWT, token-verified) |
| Admin | `GET /admin/reports|posts/search|posts/:id|users/search|users/:id|ops/metrics|ops/metrics/prometheus`, `POST /admin/ban`, `DELETE /admin/posts/:id|comments/:comment_id` |

---

## Getting Started

### Prerequisites

Ensure you have the following installed on your host machine:

- **Go**: 1.24+ (recommended 1.25, CGO required for H3 — `gcc/musl-dev`)
- **Docker** and **Docker Compose**
- **Flutter SDK**: `>=3.1.5 <4.0.0`
- **Node.js**: 20+ (for Admin SPA)
- **Air** *(optional, for Go hot reload)*: `go install github.com/air-verse/air@latest`

---

### 1. Start Infrastructure Services

Dev (hot-reload, host ports):

```powershell
docker-compose -f infras/docker-compose.yml up -d
```

- **PostgreSQL**: `localhost:5433` (DB: `brightbund`, User: `user`, Pass: `password`)
- **Redis**: `localhost:6380`
- **API**: `localhost:8081`

Prod-like (full edge: Kafka, MinIO, Nginx, Fail2ban):

```powershell
docker compose up -d --build
```

Copy `.env.example → .env` and set `DB_PASSWORD`, `REDIS_PASSWORD`, `JWT_SECRET` (≥32 chars) first. Kafka topics are auto-created by `kafka-setup`.

---

### 2. Run Backend Services

#### API Server

```powershell
cd backend
go run ./cmd/api
# Or with hot-reload:
air
```

#### Background Worker

```powershell
cd backend
go run ./cmd/worker
# Or with hot-reload:
air -c .air.worker.toml
```

#### Migrations / backfills

```powershell
cd backend
go run ./cmd/migrate -mode migrate
go run ./cmd/migrate -mode backfill-gold-weekly -weeks 12
go run ./cmd/migrate -mode reconcile-gold-weekly -weeks 12
go run ./cmd/migrate -mode backfill-gold-seasonal -weeks 12
go run ./cmd/migrate -mode reconcile-gold-seasonal -weeks 12
```

Config: `backend/config.yaml` (prod defaults) + `backend/config.local.yaml` (localhost:5433/6380/9001). Key sections: `server`, `database` (25 open/5 idle), `redis` (pool 10), `feed` rings/shares, `moderation` (shadow_mode, 4 thresholds+ratios, 10 reports/day), `activation` (72/120h, 3 login days, 5 meaningful actions, 3 regs/device/day), `eventbus` (kafka:9092), `admin` (seed emails + bcrypt password), `storage` (MinIO buckets), `firebase`, `jwt` (15m access / 24h refresh + local 24h/168h), `cors` (`Idempotency-Key` allowed).

---

### 3. Run Mobile App (Flutter)

```powershell
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define-from-file=app/.env
# flavor dev:
flutter run --debug --flavor dev -t lib/main_dev.dart
```

Useful: `docker exec -it brightbund-db psql -U user -d brightbund` for live DB inspection.

---

### 4. Run Admin SPA (React + Vite)

```powershell
cd spa
npm install
npm run dev     # :3001, proxies /api → :8080
npm run build   # → spa/dist, served by nginx at /admin/
```

Open [http://localhost:3001/admin/login](http://localhost:3001/admin/login) in your browser. Seed: register the `admin.emails` user via normal auth flow, restart API (`EnsureAdmins` promotes), then login. Rebuild + `docker compose up -d nginx` to refresh prod `/admin`.

---

## Anti-Abuse & Economic Integrity

1. **Idempotent Operations**: Every ledger transfer, quest completion, and seal transaction enforces strict idempotency keys (`reference_id` UNIQUE) to prevent double-spend attacks.
2. **Aggressive Rate Limiting**: Token-bucket and sliding-window rate limiters guard high-value endpoints (auth 10/min, register 3/10min, chat-send 25/min, seal transfers, post creation, reactions) + Fail2ban at the edge.
3. **Quiet Shop Paradigm**: Client UI reacts gracefully to `INSUFFICIENT_FUNDS` with non-intrusive micro-animations (Heartbeat on shop icon) rather than disruptive friction modals.
4. **Zero Client Trust**: All rank tiers, seals, and task completions are validated strictly against verified backend telemetry. No client-computed balances, timers, or geo claims.
5. **Graph protection**: `user_interactions` + pair cooldowns detect circular farming (A↔B repeats); monthly caps + per-pair escalating cooldowns + violation logging close the loop.
6. **Moderation depth**: typed strikes, publishing ladder, shadow distribution, reporter reputation, activation gating (`active` + no `restrictions_until` before referral payout), deferred-referral activation.

---

## Testing & Verification

BrightBund maintains Go unit tests plus comprehensive end-to-end curl suites in [`tests/`](tests/) (19 scripts). The canonical full-system suite spins up admin + 3 users and exercises health → auth-guard → economy → profiles/relationships → feed → map/task-lifecycle → ranks/settings/admin-reports.

Run test suites using bash (or Git Bash on Windows):

```bash
# Run all integration tests
bash tests/test_all.sh

# Run domain-specific suites
bash tests/test_eco.sh          # Economy & ledger verification
bash tests/test_eco_new.sh      # New economy flows
bash tests/test_feed.sh         # Feed & anti-doomscroll verification
bash tests/test_feed_smart.sh   # Smart-feed blending
bash tests/test_map.sh          # PostGIS geospatial tasks & regions
bash tests/test_geolocation.sh
bash tests/test_geo_admin.sh    # H3 admin hierarchy
bash tests/test_ranks.sh        # Gamification & rank logic
bash tests/test_allies.sh
bash tests/test_relationship_status.sh
bash tests/test_profiles.sh
bash tests/test_profile_get.sh
bash tests/test_profile_partial_update.sh
bash tests/test_referrals.sh
bash tests/test_seal_cooldowns.sh
bash tests/test_free_seal_lifecycle.sh
bash tests/test_issues.sh
bash tests/test_economy_cooldown.sh
```

Unit tests for backend modules:

```powershell
cd backend
go test -v ./...
go test -v ./internal/modules/...
```

CI runs `golangci-lint` + `go test ./...` against PostGIS 16 service on every push/PR to main/develop.

---

## Documentation & References

- [Product Requirements & Architecture (RPD)](docs/BrightBund_RPD.md) — modular monolith, 10 epics, 3-month staged plan (foundation → core loop/geo → gamification/launch)
- [Economy & Transaction System](docs/Economy_Transaction_System.md) — wallets/ledger schema, centinels, categories, atomic flows, history queries
- [Feed Module Design](docs/Feed_Module_Changes.md) — anti-doomscroll state machine, profile posts endpoints, worker flush reliability, sanction ladder + adaptive geo params
- [Geospatial Architecture & Maps](docs/Geo_Module.md) — H3 res mapping, region assignment, champion cycle, radius search, OSM→Mapbox path
- [Ops commands](docs/command.md) — flutter flavors, psql exec, cooldown test, migrate/backfill modes
- [Feed perf audit](issues/opt-feed.md) — P0–P3 optimization roadmap (batch media, indexes, async Vision, feed cache)
- [Admin SPA routes](spa/routes.md) — JWT+admin guards, per-page API mapping
- [Admin SPA plan](spa/implementation-plan.md) — Vite scaffold → auth/layout → users → posts → reports/dashboard
- Backend contracts: [`backend/docs/swagger.yaml`](backend/docs/swagger.yaml) + `/swagger/` UI
- Legal/static: `index.html`, `privacy.html`, `terms.html`, `account-deletion-info.html` (Play requirement), `404.html`

---

## License

This project is proprietary and confidential. All rights reserved.
