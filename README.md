# Social-Fintech

<div align="center">

[![Go Version](https://img.shields.io/badge/Go-1.25+-00ADD8?style=for-the-badge&logo=go&logoColor=white)](https://golang.org)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![React](https://img.shields.io/badge/React-18-61DAFB?style=for-the-badge&logo=react&logoColor=black)](https://react.dev)
[![Vite](https://img.shields.io/badge/Vite-6.0-646CFF?style=for-the-badge&logo=vite&logoColor=white)](https://vitejs.dev)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16%20%2B%20PostGIS-336791?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Redis](https://img.shields.io/badge/Redis-7%20Alpine-DC382D?style=for-the-badge&logo=redis&logoColor=white)](https://redis.io)
[![Kafka](https://img.shields.io/badge/Kafka-KRaft-231F20?style=for-the-badge&logo=apachekafka&logoColor=white)](https://kafka.apache.org)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com)

**A social-fintech platform: real-money-grade ledger discipline applied to a social graph — dual-currency economy, geospatial task marketplace, anti-doomscroll feed, and gamified rank progression.**

[Vision](#1-vision--product-idea) • [Features](#2-key-features) • [Architecture](#3-system-architecture) • [Layout](#4-project-layout) • [Tech Stack](#5-tech-stack) • [Modules](#6-core-domain-modules) • [Economy](#7-economy--data-specs) • [Feed](#8-feed-anti-doomscroll--moderation) • [Geo & Tasks](#9-geo-tasks--champions) • [Auth & Social](#10-auth-profiles-chat-notifications-seasons-settings) • [API](#11-api-reference) • [Setup](#12-getting-started) • [Anti-Abuse](#13-anti-abuse--economic-integrity) • [Testing](#14-testing--verification)

</div>

> **Naming note.** This project was developed under the working title *BrightBund* — you will still see that name in the Go module path (`github.com/brightbund-backend`), Docker container names (`brightbund-api`, `brightbund-db`, …), database name, config keys, and historical docs under [`docs/`](docs/). The public product name going forward is **Social-Fintech**. Only this README and user-facing copy are rebranded; internal identifiers are intentionally untouched so nothing breaks.

---

## 1. Vision & Product Idea

### 1.1 What is Social-Fintech?

**Social-Fintech** is a next-generation social ecosystem that treats **attention and appreciation as financial transactions**. Every act of support — a Seal on a post, a reward for a completed local task, a referral bonus — moves through an auditable, double-entry ledger with the same rigor as a bank transfer: atomic transactions, optimistic locking, idempotency keys, and an immutable append-only history.

The name says it all: **social** mechanics (feed, allies, chat, leaderboards, local champions) fused with **fintech** discipline (wallets, ledgers, violation logging, receipt validation, cooldown ladders).

### 1.2 The problem we solve

Traditional social networks reward volume: more scrolls, more likes, more follows. That incentive produces:

- **Bot farming and engagement pods** — fake accounts inflating each other at zero cost.
- **Social graph manipulation** — circular give-and-take rings (A→B→A) that manufacture influence out of thin air.
- **Rage-bait and doomscroll addiction** — algorithms that optimize for time-on-screen, not value delivered.
- **Meaningless status** — follower counts that cost nothing to inflate and signal nothing real.
- **Dead local communities** — global virality drowning out the neighborhood, the district, the city.

### 1.3 The core insight

> **Value must have a cost.** When appreciation spends a real ledger balance — one you earned slowly through daily accruals, referrals, task completions, or real purchases — it cannot be farmed. Influence becomes a scarce, earned, auditable asset instead of a vanity counter.

Social-Fintech inverts the incentive stack:

1. **Money-grade ledger for social value.** Two currencies (*Silver Seals* — earned/soft, *Gold Seals* — premium), stored as integer centinels (1 Seal = 100 centinels, zero float drift), every movement recorded in an immutable `ledger_entries` table with sender, receiver, category, idempotency key, and JSONB metadata.
2. **Server as the only source of truth.** No client-side balances, ranks, timers, or geo claims are ever trusted. The mobile app is a renderer; the Go backend decides everything.
3. **Local first, world second.** The smart-feed mixer blends Allies + Local geo-ring content with a capped World fill (~10%), and adaptive geo rings (5/10/18 km → 30/50/70% local share) keep communities geographically alive.
4. **Time is bounded.** The Anti-Doomscroll fatigue state degrades the feed after a configurable 20/30/40-minute session and enforces a 5-minute cooldown — synchronized across all of a user's devices through a wall-clock `break_start_at` anchor.
5. **Status is earned slowly.** Seven ranks (Pearl → Moonstone → Jade → Lapis Lazuli → Ammolite → Onyx → Supernova), each with C/B/A/S sub-levels, derive from Gold Seal history and 6-month season archives — computed asynchronously so they cannot be gamed in real time.
6. **Territory is real.** Uber H3 hexagonal cells (res 5 ≈ 253 km² district arena, res 4 ≈ large city, res 2 ≈ country-scale) create weekly Champion competitions backed by Redis ZSET leaderboards and PostgreSQL snapshots with city/region/country names.
7. **Work is a marketplace.** Anyone can post a paid local task with the reward escrowed in centinels at creation; applicants flow through apply → accept → verification-code → confirm, and the reward settles in the ledger.

### 1.4 Who it is for

- **Local communities** that want a tamper-proof reputation and reward layer for real-world help (pick up a package, clean a park, help a neighbor).
- **Creators** who want appreciation that is scarce and meaningful instead of free likes.
- **Operators and admins** who need a full control center: user bans, post/comment moderation, report queues, balance adjustments, violation forensics, ops metrics, season and leaderboard management.

### 1.5 Product principles

- **Server as Source of Truth**: all economic calculations, balances, transactions, and status evaluations are strictly enforced server-side.
- **Double-Entry Ledger**: complete immutability and financial integrity for all virtual currency operations.
- **Anti-Doomscroll Feed**: geospatially-aware distribution prioritizing local, quality engagement over algorithmic addiction loops.
- **Geospatial Discovery (PostGIS + H3)**: real-time region detection, champion tracking, location-based tasks.
- **Modular Monolith**: strict Clean Architecture domain boundaries with single-binary operations and ACID transactions across domains.

### 1.6 Non-goals (MVP scope)

Per the RPD: no ML/AI feed ranking (algorithmic sort only), no clans or complex group mechanics. Focus is core economy stability and the feel of the app (Map + Feed). Anything not in the epic decomposition is explicitly out of scope and needs a new epic.

---

## 2. Key Features

- **Double-Entry Currency Engine** — Silver/Gold wallets, immutable ledger, optimistic locking, per-category reference IDs, violation logging, monthly caps, 60s P2P cooldowns, free-silver caps, escalating pair-cooldown ladders (30→120 days).
- **Geospatial Task Marketplace** — PostGIS `ST_DWithin` radius search + H3 cell assignment in pure Go (O(1), zero DB), verification-code completion flow, escrowed rewards, expiry cleanup, refunds.
- **Weekly Champion Territories** — H3 res-5 arenas, Redis weekly ZSETs (arena/city/global), Monday-UTC snapshot worker, viewport champion pins, ranking countdown timer, H3 admin hierarchy lookup.
- **Smart Anti-Doomscroll Feed** — allies/local/world blending, cursor pagination everywhere, adaptive geo rings, cross-device fatigue sync, write-behind Redis→Postgres flush every 30s.
- **Typed Moderation Ladder** — author strikes (`post_removed`, `comment_removed`), publishing restrictions (3→24h, 6→72h, 9→7d), shadow-mode distribution multipliers, reporter reputation, admin queues.
- **Dynamic Leaderboards** — real-time Redis Sorted Sets with 8-day TTL, admin scope/add/remove/adjust/reset tooling, seasonal gold backfills and reconciles.
- **Real-Time Chat** — WebSocket 1:1 direct + task conversations, accept/decline request lifecycle, replies/forwards, pins, mutes, read receipts, media uploads, 25/min send limiter, Redis Pub/Sub fan-out.
- **Kafka Push Pipeline** — `system.events` → `push.dispatch` → per-platform topics (`push.ios`/`push.android`/`push.huawei`) → DLQ, with FCM/APNs/Huawei workers, retry, device registry, 25+ typed notification kinds in 5 UI tabs.
- **Six-Month Seasons** — Jan–Jun / Jul–Dec halves, per-user archives (final position, seal counts, rank snapshots), admin force-close, live countdown widgets.
- **RevenueCat Monetization** — webhook-driven IAP validation → ledger mint (`IAP_DEPOSIT`), `purchases_flutter` client, payment-confirmed notifications.
- **Multi-Factor Auth** — email/password + OTP codes, phone OTP, Firebase phone/email, Apple/Google OIDC, JWT access+refresh rotation, session tracking, 2FA, activation hardening, soft→hard account deletion.
- **Admin Control Center** — React SPA: login, ops dashboard, user search/detail/ban, post search/detail/delete, threaded comment moderation, report queues, balance adjust, violation forensics, seasons, leaderboards.
- **Hardened Edge** — Nginx gateway (SSL termination, 500 MB uploads, scanner drops, legal pages), Fail2ban jails (444/botsearch/404), Fiber per-route rate limiters, structured Zap logging with request IDs, JSON + Prometheus metrics.

---

## 3. System Architecture

The platform is a **Modular Monolith** with strict **Clean Architecture** boundaries: isolated domain packages (`backend/internal/modules/*`), single-binary deploys, and ACID transactions across domains (e.g. debit-wallet + create-task in one commit) with zero distributed-transaction overhead. No cross-module business logic leaks. The code is structured so domains can be extracted into microservices later if scale demands it.

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

**Request path:** Flutter / SPA → Nginx (`/api/v1/` → API, `/minio/` → MinIO, `/admin` → SPA dist, `/swagger/` → API docs, `/health`, legal pages) → Fiber middlewares (requestid → Zap logger → CORS → `RequireAuth` + `TouchSession` → `RequireAdmin` where needed → per-route limiters: auth 10/min, register 3/10min, chat-send 25/min, settings-sensitive 5/hr).

**Async path:** heavy work leaves the request path — Asynq + cron jobs handle rank recalculation, season rollover, fatigue/likes/seals flushes, task expiry; Kafka carries domain events to the push dispatcher and per-platform workers.

---

## 4. Project Layout

```
.
├── app/                  # Mobile application (Flutter 3.x, BLoC, GoRouter, Dio)
│   ├── lib/src/features/ # auth, home (feed/store/notifications/search),
│   │                     # profile, map, chats, rating, developer_features
│   ├── lib/src/core/     # router, api client/endpoints, widgets, DI (get_it+injectable),
│   │                     # storage, config, utils
│   ├── lib/src/app/      # runner, flavor builds (dev entry: main_dev.dart)
│   └── pubspec.yaml      # mapbox, h3_flutter, purchases_flutter, geolocator, firebase
├── backend/              # Core API & Worker services (Go 1.25, Fiber v2, sqlx)
│   ├── cmd/
│   │   ├── api/          # Main HTTP/WebSocket API entrypoint
│   │   ├── worker/       # Async background job worker daemon
│   │   └── migrate/      # migrate | backfill-gold-weekly | reconcile-gold-weekly |
│   │                     # backfill-gold-seasonal | reconcile-gold-seasonal
│   ├── internal/
│   │   ├── modules/      # auth, profiles, economy, feed, map, ranks, leaderboard,
│   │   │                 # seasons, chat, notifications, payment, settings
│   │   ├── server/       # Fiber app, routing (server.go), middleware
│   │   ├── config/       # YAML + env overlay with sane defaults
│   │   └── platform/     # cache, eventbus (kafka), email, vision, translation,
│   │                     # observability
│   ├── migrations/       # 77 SQL migrations (000_enable_postgis → 077_feed_opt_phase2)
│   └── docs/             # Swagger / OpenAPI contracts (swagger.yaml/json, docs.go)
├── spa/                  # Admin Control Center (React 18, Vite 6, CSS modules)
│   └── src/              # api/, context/AuthContext, components/Layout,
│                         # pages/* (Login/Dashboard/Users/Posts/Reports/Seasons/
│                         # Leaderboard), hooks/useApi
├── docs/                 # Product specs (RPD, Economy, Geo, Feed, command.md)
├── infras/               # Dev compose (db:5433, redis:6380, api:8081 + Air hot-reload)
├── docker-compose.yml    # Prod compose: db, redis, api, worker, minio, kafka,
│                         # kafka-setup, nginx, fail2ban
├── nginx/                # Reverse proxy configs & SSL orchestration
├── fail2ban/             # jail.local + filter.d (nginx-444, nginx-404, nginx-botsearch)
├── google/               # Firebase credentials (LOCAL ONLY — never committed)
├── tests/                # 19 shell integration suites (curl-based)
├── .github/workflows/    # ci.yml (lint + go test) + deploy.yml (build + SSH deploy)
├── index.html / privacy.html / terms.html / account-deletion-info.html / 404.html
└── .env.example          # Safe env template (no secrets)
```

> **Secret hygiene (read before contributing).** `.env`, `app/.env`, `backend/.env`, `backend/firebase-service-account.json`, `google/`, `*/google-services.json`, `*/GoogleService-Info.plist`, `*.pem/.key/.p12/.pfx/.jks`, `*keystore*`, `.firebaserc` are git-ignored and must never be committed. They live only on your machine — copy shapes from `.env.example` and your Firebase console. Branch tips were cleaned; keep it that way.

---

## 5. Tech Stack

### 5.1 Backend — Go 1.25

The Go module is still named `github.com/brightbund-backend` (renaming it would touch every import; not worth the churn — treat it as an internal identifier).

| Concern | Technology |
|---|---|
| HTTP | `gofiber/fiber/v2`, `gofiber/websocket/v2`, fasthttp, `cors`, `limiter`, `requestid` |
| DB | PostgreSQL 16 + PostGIS (`postgis/postgis:16-3.4-alpine`), `jmoiron/sqlx`, `lib/pq`, 77 file migrations |
| Geo math | `uber/h3-go/v4` (CGO — `gcc/musl-dev` in Dockerfile) |
| Cache / realtime | `redis/go-redis/v9` — fatigue state, likes/seals buffers, ally lists, ZSET leaderboards, Pub/Sub |
| Jobs / events | `hibiken/asynq`, `robfig/cron/v3`, `segmentio/kafka-go` (KRaft, no ZooKeeper) |
| Auth | `golang-jwt/jwt/v5`, `coreos/go-oidc/v3`, `MicahParks/keyfunc`, `firebase.google.com/go/v4`, `golang.org/x/crypto` (bcrypt) |
| Storage / media | `minio/minio-go/v7`, ffmpeg path in config, Vision moderation (`cloud.google.com/go/vision`), translation (`cloud.google.com/go/translate`) |
| Config | `gopkg.in/yaml.v3`, `joho/godotenv`, env overlay (`DB_*`, `REDIS_*`, `ECONOMY_*`) |
| Observability | `go.uber.org/zap`, internal `platform/observability` (JSON + Prometheus text at `/admin/ops/metrics`) |
| API docs | `swaggo/fiber-swagger`, `swaggo/swag`, `backend/docs/swagger.yaml` |
| Tests | `stretchr/testify`, `alicebob/miniredis/v2`, `go test ./...` + `tests/*.sh` curl suites |

### 5.2 Mobile — Flutter `>=3.1.5 <4.0.0` (app `1.0.0+6`)

- **State:** `flutter_bloc` + `rxdart`; **errors:** `fpdart` Either; **DI:** `get_it` + `injectable` (generators: `build_runner`, `freezed`, `json_serializable`, `flutter_gen_runner`).
- **Nav:** `go_router` — auth/signup/login/code/info/referal, home/create-post/notifications (+settings)/search/store, map + create-request state screens, rating, chats + `/chat/:chatId` thread, profile/publications/stats/settings/allies/public-profile, developer_features/log/widget_book/rangs/leaderboard_admin/feed-preview.
- **Network:** `dio` + `talker_dio_logger` (+ `talker`, `talker_flutter`, `talker_bloc_logger`); endpoint map in `lib/src/core/api/client/endpoints.dart`; token interceptor + secure storage.
- **Storage:** `flutter_secure_storage` (tokens), `shared_preferences`, `package_info_plus`, `device_info_plus`, `uuid`.
- **Auth:** `firebase_core`, `firebase_auth`, `google_sign_in`, `sign_in_with_apple`, `app_links` (magic links), email/phone OTP screens.
- **Media:** `image_picker`, `video_player`, `video_compress`, `path_provider`, `saver_gallery`, `share_plus`, `url_launcher`, `permission_handler`.
- **Geo:** `geolocator`, `mapbox_maps_flutter`, `h3_flutter`, (`flutter_map` + OSM path per Geo spec; Mapbox = one tile-URL swap).
- **Monetization:** `purchases_flutter` (RevenueCat) → backend `/payment/webhook` → ledger mint.
- **UI:** `flutter_svg`, `gap`, `timeago`, `syncfusion_flutter_sliders/core`, Lora + CanelaDeckTrial fonts.
- **Run:** `flutter run --dart-define-from-file=app/.env`; dev flavor `flutter run --debug --flavor dev -t lib/main_dev.dart`.

### 5.3 Admin SPA — React 18 + Vite 6

- React 18.3.1 + react-dom + react-router-dom v6, Vite 6 (`@vitejs/plugin-react`), base `/admin/`, dev port 3001 with `/api → localhost:8080` proxy.
- Deliberately minimal: no Redux/Tailwind/UI lib/axios — `fetch` wrapper (`src/api/client.js`), `AuthContext` (localStorage JWT), `useApi` hook, CSS modules (dark 240px sidebar `#1a1a2e`, accent `#e94560`).
- Pages: Login, Dashboard (ops metrics), Users + UserDetail (ban/adjust-balance/violations), Posts + PostDetail (delete/threaded comments), Reports (status/target filters), Seasons, Leaderboard admin, 404.

### 5.4 Infrastructure / Edge

- **Prod compose** (`docker-compose.yml`): `db` (PostGIS, 256 MB, tuned shared_buffers/max_connections, healthcheck), `redis` (7-alpine, 80 MB LRU, no AOF), `api` + `worker` (multi-stage CGO builds from `backend/Dockerfile`), `minio` (:9001 console), `kafka` (KRaft single-node, 384 MB, 24h retention) + `kafka-setup` (creates `system.events`, `push.dispatch`, `push.ios`, `push.android`, `push.huawei`, `push.dlq`), `nginx` (alpine, legal pages + `/admin` dist), `fail2ban` (host network, watches `nginx/logs`).
- **Dev compose** (`infras/docker-compose.yml`): `db:5433`, `redis:6380`, `api:8081` with `Dockerfile.dev` + Air (`.air.toml`, `.air.worker.toml`).
- **Nginx:** `/health`, `/api/v1/`, `/swagger/`, `/minio/`, `/admin`, `/account-deletion` (Play requirement), `/privacy`, `/terms`, custom 404; drops non-standard methods (444) and `php|aspx|env|bak|git` probes.
- **Fail2ban:** `bantime=3600`, `findtime=600`; `nginx-444 maxretry=2`, `nginx-botsearch maxretry=2`, `nginx-404 maxretry=10`.
- **CI/CD:** `ci.yml` (PostGIS service + golangci-lint + `go test ./...` on main/develop); `deploy.yml` (build api/worker/migrate + test, SSH to prod → `git pull` + `docker compose up -d --build` on main/develop/feed, ignores `app/**`).

---

## 6. Core Domain Modules

Backend domains in [`backend/internal/modules/`](backend/internal/modules/) — strict boundaries, server-authoritative, no cross-module business logic:

| Module | Responsibilities |
|---|---|
| **`auth`** | Email/password + OTP, phone OTP, Firebase phone/email, Apple/Google OIDC; JWT access+refresh rotation, session tracking (`TouchSession`), device binding, 2FA, admin login/ban/lookup, activation hardening, captcha/username/email/phone sub-flows |
| **`profiles`** | Metadata, avatars, privacy, allies graph, block/restrict/report, relationship status, cached stats, public rank catalog |
| **`economy`** | Idempotent double-entry ledger (Silver/Gold), accruals, referrals, P2P, post/user seals, task charges/refunds, IAP deposits, admin adjust, violation logs, transfer limits, pair cooldowns |
| **`feed`** | Posts, threaded comments, likes, seals, smart blending, fatigue state, media upload + Vision, moderation queue, admin post/comment/report tools, profile grids/lists |
| **`map`** | H3 assignment, region opt-in, PostGIS task CRUD + nearby/my/applied, apply → accept/reject → verify-code → confirm lifecycle, champions viewport, ranking timer, H3 admin hierarchy |
| **`ranks`** | 7-rank catalog + C/B/A/S levels, async calculation from Gold history, my-rank + public catalog |
| **`leaderboard`** | Redis weekly ZSETs (arena/city/global), my-rank, admin scopes/add/remove/adjust/reset |
| **`seasons`** | 6-month halves (Jan–Jun / Jul–Dec), current + per-user archives, admin list + force-close, snapshot worker, gold backfill/reconcile |
| **`chat`** | WebSocket 1:1 direct + task conversations, request accept/decline, replies/forwards/pins/mutes/deletes, read receipts, media, presence |
| **`notifications`** | Kafka dispatcher → FCM/APNs/Huawei workers, device registry, inbox + unread, preferences, retry + DLQ, 25+ kinds / 5 UI tabs |
| **`payment`** | RevenueCat webhook + store receipt validation → ledger mint |
| **`settings`** | Security (password/2FA/sessions/delete-account), feed time-limit, interactions (messages/comments/mentions/blocked/keywords), notification prefs, support/bug/contact |

---

## 7. Economy & Data Specs

Full design: [`docs/Economy_Transaction_System.md`](docs/Economy_Transaction_System.md).

### 7.1 Dual-table architecture

The economy is a **dual-table** system: `wallets` holds current state, `ledger_entries` is the immutable, append-only source of truth.

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
    metadata JSONB,                             -- post_id, task_id, referee_id, reason…
    created_at TIMESTAMP NOT NULL
);
```

- **Centinels:** `1.00 Seal = 100 centinels` (`SealsToCentinels` via `math.Round`). No floats anywhere in storage; the API converts at the boundary.
- **Atomic flow:** `BeginTx → GetWallet FOR UPDATE → validate → mutate → UpdateWalletWithVersion (WHERE version=?) → CreateLedgerEntry → Commit`. A version mismatch means a concurrent writer won → `ErrOptimisticLock` → rollback → client retries. No partial states (sender debited but receiver not credited is impossible).
- **Directional semantics:** system mints have `sender = NULL` (daily accrual, referral, IAP), system burns have `receiver = NULL` (task creation, post seals), P2P has both.
- **History query:** join ledger to sender/receiver wallets, filter by currency/category, `ORDER BY created_at DESC LIMIT/OFFSET`; the service tags each row SENT/RECEIVED from the viewer's perspective and resolves the counterparty's username/avatar.

### 7.2 Currencies

| Currency | Code | Purpose | How to earn | Caps / notes |
|---|---|---|---|---|
| Silver Seal | `SILVER_SEAL` | Free/earned currency | Daily accrual (1.00 / 48h), referrals (1.00), task rewards, signup bonus | `free_balance` capped (default 500 = 5.00); spend deducts free first |
| Gold Seal | `GOLD_SEAL` | Premium currency | IAP deposit (Apple/Google/RevenueCat) | No cap; drives ranks; direct admin mint disabled server-side |

### 7.3 Transaction categories

`DAILY_ACCRUAL`, `REFERRAL_BONUS`, `SIGNUP_BONUS`, `P2P_TRANSFER` (+ legacy `transfer` alias), `TASK_CREATION` (burn), `TASK_REFUND`, `TASK_REWARD`, `IAP_DEPOSIT` (mint), `POST_SEAL`, `SYSTEM_CORRECTION`.

Reference-ID patterns: `accrual_<user>_<date>`, `transfer_<sender>_<receiver>_<ts>`, IAP receipt ID, `referral_<referrer>_<referee>`, `task_creation_<taskID>`. Replays return the existing row — never double-mint, so network retries are safe.

Metadata examples: P2P `{"reason": "…"}`, referral `{"referee_id": "…"}`, task `{"task_id": "…", "task_title": "…"}`, post seal `{"post_id": "…"}`, IAP `{"platform": "apple", "product_id": "…"}`.

### 7.4 Specific flows

- **Daily accrual:** 100 centinels, every 48h (not 24 — name is legacy), gated on `NeedsDailyAccrual` + free-cap; credits both `balance` and `free_balance`; ledger row is a system mint.
- **P2P transfer:** amount/currency/self-transfer validation → monthly-limit check → 60s cooldown check → balance check → debit sender (free first) → credit receiver → limit increment → `UpsertUserInteraction` for abuse detection.
- **Referral:** 100 to the referrer, one referee → one referrer ever; **deferred** — stored pending (`is_active=false`) until the referee is activation-eligible (`active`, no `restrictions_until`), then atomically activated with the mint. Self-referral rejected.
- **IAP deposit:** receipt ID as idempotency key; duplicates return nil; receipt must be verified by the payment module first.
- **Task creation charge:** configurable cost, system burn, free-balance-first deduction; `INSUFFICIENT_FUNDS` → Quiet-Shop UX.
- **Post/user seals:** 1–10 seals per action with pair-cooldown ladder enforcement.

### 7.5 Anti-abuse knobs (defaults in `internal/config/package.go`, YAML/env-overridable)

- Monthly/daily transfer cap: **50** (`transfer_limits` per `YYYY-MM`, with `total_sent_centinels`).
- P2P cooldown: **60s** (`last_transfer_at`).
- Free silver cap: **500 centinels**; accrual **100 / 48h**; referral **100**.
- No self-transfer; balance checked pre-mutation; free balance spent first.
- Seal pair-cooldown ladder L1 30d → L2 45d → L3 60d → L4 90d → L5 120d with decay thresholds.
- `economy_violations`: `COOLDOWN_BREACH`, `RATE_LIMIT_EXCEEDED`, `FREE_SILVER_CAP`, `MONTHLY_LIMIT_EXCEEDED`, `INSUFFICIENT_FUNDS_ATTEMPT`, `REPEAT_TRANSFER_PATTERN` (+ IP + endpoint for forensics).
- Strategic indexes: `wallets(user_id, currency)` unique, ledger sender/receiver/`created_at`/reference unique, transfer-limits user+month, referrals referrer/referee, violations user/type/created.

### 7.6 Ranks (Gold-driven, `modules/ranks/catalog.go`)

| Rank | Quality | Seals | Levels |
|---|---|---|---|
| Pearl | Awareness | 0–10 | C/B/A/S quartiles |
| Moonstone | Intention | 10–25 | C/B/A/S |
| Jade | Discipline | 25–60 | C/B/A/S |
| Lapis Lazuli | Influence | 60–140 | C/B/A/S |
| Ammolite | Fortitude | 140–260 | C/B/A/S |
| Onyx | Transcendence | 260–700 | C/B/A/S |
| Supernova | Sovereign | 700+ | — (top tier, no sub-levels) |

`CalculateRankAndLevel` splits each band into C/B/A/S quartiles; `FormatRankTitle` renders `Name | Quality | Level` (e.g. `Jade | Discipline | A`). Titles enrich feed cards, chat threads, and profiles. All rank math is async — the client never computes rank.

### 7.7 Seasons (6-month halves, `modules/seasons/entity.go`)

Exactly two non-overlapping seasons per year: H1 = Jan 1 → Jun 30, H2 = Jul 1 → Dec 31 (UTC, computed without a DB round-trip via `SeasonForTime`). Per-user archives keep final position, Gold received, region/scope, and an extensible JSON snapshot payload (given seals, rank, level — no migration needed to extend). Workers backfill/reconcile weekly + seasonal gold (`cmd/migrate` modes); admins can force-close (archives N users); the profile shows a live `seconds_remaining` countdown.

---

## 8. Feed, Anti-Doomscroll & Moderation

Designs: [`docs/Feed_Module_Changes.md`](docs/Feed_Module_Changes.md), [`issues/opt-feed.md`](issues/opt-feed.md).

### 8.1 Smart feed

- **Mixer:** Allies + Local geo-ring + World (~10%); Go-side blending (80/20 allies-local vs world), shuffle, per-author repeat cap (2 on first pass, backfill uncapped when the pool is thin), deterministic tie-break `ORDER BY created_at DESC, id DESC` so pagination is stable.
- **Endpoints:** `GET /feed?lat=&lon=&cursor=&limit=` (default 10, RFC3339Nano cursor); profile grids `GET /profiles/me|/:id/posts` (18 default / 30 max, `next_cursor`) and full card lists `.../posts/list` (10/30, `anchor_post_id` inclusive via `created_at+1µs` with cursor fallback). Visibility enforced server-side (self sees all; strangers see `ANYONE` + ally posts only if ally).
- **Adaptive geo** (`feed.*` config): rings **5 / 10 / 18 km** (kRing 1→2→3), 24h activity window; high (≥30 posts + ≥15 authors) → **70%** local, medium (≥15 + ≥8) → **50%**, low → **30%**; smallest passing ring wins, else kRing 3. H3 helpers live in the map module (`computeH3Indices`, `SetUserRegion`).
- **Perf program** (P0–P3 in `opt-feed.md`): batch media fetch (kill 200× LATERAL `json_agg`), partial `idx_posts_feed_cursor`, covering `idx_wallets_rank`, POST_SEAL expression index on `metadata->>'post_id'`, ally-list Redis cache, async Vision uploads, Go-side random sampling replacing SQL `random()`, short-TTL feed cache. Target: 1–2s → 200–400ms → <50ms cached. Migrations `072_feed_performance_indexes`, `076/077_feed_opt_phase1/2` carry the index work.

### 8.2 Anti-Doomscroll (cross-device safe)

The headline bug this system fixed: a break timer that reset when the user opened a second device. The fix anchors everything to an immutable wall-clock `break_start_at` — all devices compute the same remaining time.

```
[ACTIVE] ── limit reached ──► [COOLDOWN]
   ▲                              │
   │      away ≥ BreakDuration     │ (via break_start_at anchor)
   └────────── reset ◄─────────────┘
[ACTIVE] ── away ≥ 5 min ──► reset counter → [ACTIVE @ 0]
```

- Limits `feed_time_limit_mins ∈ {0,20,30,40}` (default 20 min = 1200s; `0` = unlimited), break **300s**, away-reset **300s**, anti-cheat buffer **5s**.
- `GET /feed/state` (call on open/return — applies off-feed → break transitions) + `POST /feed/state/sync {delta_seconds}` (periodic accumulator, clamped to wall-clock + 5s so clients can't lie about time). Response: `accumulated_active_seconds`, `is_in_cooldown`, `break_seconds_remaining`, `accumulated_break_seconds`, `max_allowed_seconds`, `server_timestamp`, `action_required ∈ {trigger_friction, enforce_cooldown}`.
- Client contract: friction % = `accumulated/max` from the server only (never stored locally); countdown from `break_seconds_remaining`; always re-fetch state on app open. API contracts and response fields were frozen — the whole fix is server-side.
- Storage: one row per user in `feed_fatigue_states` (`accumulated_active_seconds`, `accumulated_break_seconds`, `last_sync_timestamp`, `is_in_cooldown`, `break_start_at`).
- Write-behind: likes, seals, and fatigue live in Redis buffers; the worker flushes every **30s** (`flushFatigueStates` UPSERT, `flushLikes` batch into `post_interactions` + `likes_count`, `flushSeals` atomic counter drain into `seals_count/seals_amount`) with requeue-on-PG-failure so no data is lost. Covered by miniredis unit tests.

### 8.3 Posts / comments / likes / seals

- `POST /posts {caption, visibility: ANYONE|ALLIES_ONLY, comment_permission: ANYONE|ALLIES_ONLY|NO_ONE, media_attachments[]}` with post-idempotency keys (migration `059`); `POST /feed/media/upload` (Vision appropriateness check, MinIO/S3, multi-res video fields per `057/058`).
- Threaded comments (`parent_id`, 4 cursor variants for top-level/replies × with/without cursor); like = toggle with `viewer_has_liked` on every card; comment likes; comment translate endpoint.
- Seals = monetized reaction: `POST /posts/:id/seals {amount 1–10, comment}` → economy debit → Redis counters → worker → post aggregates; `GET /posts/:id/seals` lists givers with amounts and comments.

### 8.4 Moderation

- `accepted` report decisions normalized to `actioned` server-side so sanctions and strikes are never dropped.
- Typed author strikes (`post_removed`, `comment_removed`, legacy `content_violation` read-compat); publishing-restriction ladder on 30-day strikes: **3→24h, 6→72h, 9→7d** from the latest strike.
- All content strikes feed smart-feed ranking (distribution multiplier × strike penalty); shadow mode suppresses probabilistically instead of hard-hiding.
- Reporter reputation deltas (bulk `UNNEST` upserts); thresholds/ratios in `config.yaml` (`moderation.*`: `shadow_mode`, 4 level thresholds + ratios, `daily_report_limit: 10`, `min_activation_views: 50`).
- Supporting tables: `reports`, `reported_post_hides`, `report_cooldowns`, `media_abuse_logs`, feed moderation controls, post controls (`hide_likes_count`, `is_deleted`).

---

## 9. Geo, Tasks & Champions

Design: [`docs/Geo_Module.md`](docs/Geo_Module.md).

### 9.1 H3 spatial index (no region polygons, no imports, no compliance)

The founder's vision needed competitive world regions ("Champions"). Storing city polygons + `ST_Intersects` per action doesn't scale globally, so regions are **computed, not stored**: Uber H3 divides Earth into deterministic hexagonal cells, and `h3.LatLngToCell(lat,lng,5)` in Go is the region identity — O(1), zero DB, works worldwide on day one.

| H3 res | Avg area | Use |
|---|---|---|
| 2 | ~86,700 km² | Country-scale zone (user + task `h3_res2`) |
| 4 | ~1,770 km² | Large city (user + task `h3_res4`) |
| 5 | ~253 km² | **District arena / Champion cell (primary)** |
| 6 | ~36 km² | Neighborhood task density |
| 7 | ~5 km² | Hyper-local feed radius |

Hierarchy is free: every res-5 cell has a parent at res-4/3/2 via `cell.Parent(n)`. PostGIS is **retained** for `ST_DWithin` radius search — H3 replaces only region membership, never proximity queries.

### 9.2 Leaderboards & weekly champion cycle

- Keys: `leaderboard:arena:{h3}:week:{yyyy}:{ww}`, `leaderboard:city:{parent}:week:…`, `leaderboard:global:week:…` — all three updated in one Redis pipeline on every Gold earn; champion = `ZREVRANGE 0 0`; 8-day TTL for auto-cleanup.
- **Monday 00:00 UTC worker:** top scorer per active cell → `region_champions` snapshot (`h3_index, h3_res, user_id, week, year, gold_score` + lat/lon + city/region/country names) → push notification to the new champion → ZSET reset.
- `GET /map/ranking/timer` returns `next_reset_at`, `seconds_remaining`, and `HH:MM:SS` `formatted` for the map widget.
- `GET /map/champions?swLat=&swLng=&neLat=&neLng=` → `PolygonToCells(res5)` → single batched champion query; server returns `CellToBoundary` polygons so Flutter draws overlays with no H3 lib needed. `GET /map/h3/:h3/admin` resolves city/region/country (+ code + timestamp).
- Users opt in with `POST /map/region {latitude, longitude, participate_region, location_opt_in}` (legacy `participate_district` alias accepted on read and emitted on write until clients migrate).

### 9.3 Task marketplace

- `POST /tasks` = one ACID transaction: **debit wallet → insert task** (reward stored in centinels, H3 cells assigned, `INSUFFICIENT_FUNDS` → Quiet-Shop heartbeat, no popup).
- Lifecycle: `pending → accept → code_verified → confirmed` (or `rejected` / withdrawn). The verification code is returned to the creator only — never in list/nearby responses; the worker submits it, the creator confirms, the reward settles (`TASK_REWARD`), expiries refund (`TASK_REFUND`).
- Discovery: `GET /tasks/nearby` (PostGIS radius, creator info joined), `GET /tasks/my`, `GET /tasks/applied` (with caller's application status), full application inbox per task, cancel/withdraw, `workers_needed`/`workers_filled` counts, optional auto-shutdown.
- Task ↔ chat bridge: `ConversationKindTask` ties a task to its coordination thread.

### 9.4 Map tiles

`flutter_map` + OSM for MVP (free, no key); Mapbox is a one-line `urlTemplate` swap post-MVP. H3 `PolygonLayer` champion overlays and task-pin `MarkerLayer`s are identical on both providers.

---

## 10. Auth, Profiles, Chat, Notifications, Seasons, Settings

### 10.1 Auth (`/auth/*`)

- **Flows:** `register-email` / `login-email` / `check-email`, legacy `phone/request|verify` + `register-phone`, `email/request|verify` (6-digit OTP; purposes register|login|email_change|password_reset), Firebase `firebase-phone-login|register` + `firebase-email-login|register` (magic links), Apple/Google OIDC `login`, `refresh`, `logout`.
- **Sessions:** JWT access+refresh rotation, DB-backed sessions (device ID, IP, user agent, app version, hashed refresh token, revocation), `RequireAuth` (JWT + not-revoked + not shadow-banned/blocked) + `TouchSession` (`last_used_at`) on every protected route.
- **Guards:** auth limiter 10/min, register limiter 3/10min (IP-keyed); captcha, username, email, phone sub-modules; device metadata capture; suspicious-login hooks.
- **Activation hardening:** `activation_status`, `restrictions_until`, required distinct login days (3) + meaningful actions (5), max 3 registrations/device/day, 72/120h restriction windows — gates referrals and sensitive actions.
- **Lifecycle:** soft delete (`deleted_at`) → scheduled hard delete; 2FA enable/disable; multi-session list + revoke; admin login/ban/email-lookup/user-detail endpoints.

### 10.2 Profiles (`/profiles/*`, `/users/search`)

`me` CRUD + avatar upload + stats + allies + delete; `/:id` public view/stats/posts/relationship; allies add/remove/list; block/unblock, restrict/unrestrict, report user; name/username search + admin exact-email search. Stats are precomputed aggregates (economy/rank domains) with a 5-minute cache — never calculated on the fly. Honor score, patron status, and season-archive widgets round out the profile.

### 10.3 Chat (`/chats/*`, WS `GET /chats/ws`)

- Direct (`direct`) + task (`task`) conversations with a **request lifecycle** (`pending → accepted/declined`) so strangers can't force threads.
- Messages: idempotency keys, replies, forwards, media, soft delete (per-side or for-both), cursor pagination; read markers + `other_participant_read_at`; `RealtimeEnvelope` pushes message/read/request events over WS; Redis Pub/Sub fans out across API instances.
- Organization: pin/unpin messages + pinned list, mute, pin conversation, clear/delete conversation, unread counts + last-message previews, rank/reputation enrichment on participants.
- `chatSendLimiter`: 25/min per user.

### 10.4 Notifications (`/notifications/*`)

- **Durable inbox** (grouped by `group_key`, actor aggregation, deep links, 5 UI tabs: RECOGNITION / ACTIVITY / TASKS / RANK / SYSTEM, importance + badge status) + bell `unread-count`, `read-all`, `:id/read`, `devices` register/unregister (ios/android/huawei with app version + locale).
- **25+ kinds:** `ranking_up`, `moved_user`, `season_end|warning|result`, `post_liked|commented|replied|rejected`, `seal_received|silver_received`, `task_applied|accepted|completed|proof_submitted|expired|verification_required|reward_delivered`, `medal_issued`, `rank_advanced|district_leader|top_50`, `payment_confirmed|security_signin|profile_verified`, `message_received`.
- **Pipeline:** domain modules `Enqueue` → Kafka `system.events` → dispatcher → `push.dispatch` → `push.{ios,android,huawei}` → per-platform workers (FCM/APNs/Huawei) → `push.dlq` on failure; idempotent send tracking prevents duplicates; retry + notification preferences (per-kind toggles, keywords, quiet rules).

### 10.5 Seasons (`/seasons/*`, `/admin/seasons`)

`current` (+ live `seconds_remaining`), `me/archive`, `users/:id/archive`; admin list (participants, open/closed) + `:id/force-close` (archives N users). Archive rows carry final position, Gold received, region/scope, and an extensible JSON snapshot. Weekly + seasonal gold backfill/reconcile run through `cmd/migrate`.

### 10.6 Leaderboard (`/leaderboard`, `/admin/leaderboard/*`)

Scoped reads + my-rank for clients; admin scopes/add-user/remove-user/adjust-score/reset for operators. Keys follow the arena/city/global weekly pattern from §9.2.

### 10.7 Settings (`/settings/*`)

- **Security:** get, change-password, 2FA enable/disable, sessions list/delete/delete-all, delete-account reason → verify → finalize (5/hr sensitive limiter).
- **Feed:** get/patch (time-limit 0/20/30/40).
- **Interactions:** messages/comments/mentions prefs, blocked list + unblock, keyword filters CRUD.
- **Notifications:** per-channel preferences. **Support:** bug reports + contact messages.

### 10.8 Admin (`/admin/*`)

Public `POST /admin/login` (email+password → JWT iff `is_admin`). Then: users get/search, `ban` (temporary/permanent + all-session revoke), posts get/search/delete (shadow-banned/hidden included, full-text caption search), comments delete, reports queue (`status/target_type/reason/limit/offset`), economy `adjust` (silvers; Gold direct mint disabled) + `violations`, ops `metrics` (JSON + Prometheus), seasons + leaderboard admin. Full SPA mapping: [`spa/routes.md`](spa/routes.md); build plan: [`spa/implementation-plan.md`](spa/implementation-plan.md).

---

## 11. API Reference

Base `/api/v1`. Route wiring: [`backend/internal/server/server.go`](backend/internal/server/server.go). Contracts: [`backend/docs/swagger.yaml`](backend/docs/swagger.yaml) + `/swagger/` UI. Mobile map: [`app/lib/src/core/api/client/endpoints.dart`](app/lib/src/core/api/client/endpoints.dart).

| Area | Endpoints |
|---|---|
| Health | `GET /health`, `GET /api/v1/health` |
| Auth | `POST /auth/login\|register-email\|login-email\|check-email\|phone/request\|phone/verify\|register-phone\|email/request\|email/verify\|firebase-phone-login\|firebase-phone-register\|firebase-email-login\|firebase-email-register\|refresh\|logout`, `POST /admin/login` |
| Economy | `GET /economy/balance\|transactions\|limits\|referral/stats`, `POST /economy/transfer\|accrual/claim\|posts/:postID/seals\|users/:userID/gift`, `POST /economy/admin/adjust`, `GET /economy/admin/violations` |
| Profiles | `GET /users/search`, `GET /profiles/ranks\|search\|me\|me/stats\|me/allies\|me/posts\|me/posts/list\|:user_id\|:user_id/stats\|:user_id/allies\|:user_id/relationship\|:user_id/posts\|:user_id/posts/list`, `PATCH /profiles/me`, `POST /profiles/me/avatar\|:user_id/allies\|:user_id/block\|:user_id/restrict\|:user_id/report`, `DELETE /profiles/me\|:user_id/allies\|:user_id/block\|:user_id/restrict` |
| Ranks | `GET /ranks`, `GET /ranks/me` (legacy `GET /profiles/me/rank`) |
| Leaderboard | `GET /leaderboard\|leaderboard/me`, admin `GET /admin/leaderboard/scopes`, `POST /admin/leaderboard/add-user\|remove-user\|adjust-score\|reset` |
| Feed | `GET /feed\|feed/state\|feed/search/profiles`, `POST /feed/state/sync\|feed/media/upload\|feed/comments/:id/likes` |
| Posts | `POST /posts`, `PATCH\|DELETE /posts/:id`, `GET\|POST /posts/:id/comments`, `DELETE /posts/:id/comments/:comment_id`, `POST /posts/:id/comments/:comment_id/report\|translate`, `POST /posts/:id/report\|likes`, `GET /posts/:id/likes\|seals`, `POST /posts/:id/seals` |
| Tasks/Map | `POST /tasks`, `GET /tasks/my\|applied\|nearby\|:task_id\|:task_id/applications\|:task_id/applications/:app_id`, `DELETE /tasks/:id`, `POST /tasks/:id/apply\|…/applications/:app_id/accept\|reject`, `DELETE …/applications/:app_id`, `POST …/verify-code\|confirm`, `POST /map/region`, `GET /map/champions\|map/ranking/timer\|map/h3/:h3/admin` |
| Chat | `GET /chats/ws` (WS), `POST /chats/media/upload\|conversations/direct\|conversations/:id/messages\|conversations/:id/read\|conversations/:id/accept\|decline\|pin-message`, `GET /chats/conversations\|conversations/:id/messages\|conversations/:id/pinned-messages`, `DELETE /chats/conversations/:id/messages/:msg_id\|conversations/:id/pin-message\|conversations/:id`, `PUT /chats/conversations/:id/mute\|pin` |
| Notifications | `GET /notifications\|notifications/unread-count`, `POST /notifications/read-all\|:id/read\|devices`, `DELETE /notifications/devices/:token` |
| Seasons | `GET /seasons/current\|seasons/me/archive\|seasons/users/:id/archive`, admin `GET /admin/seasons`, `POST /admin/seasons/:id/force-close` |
| Settings | `GET\|PATCH /settings/feed\|notifications\|interactions*\|security*`, `POST /settings/support/bugs\|contact`, `DELETE /settings/security/sessions*\|security/delete-account\|interactions/blocked/:id\|interactions/messages/keywords/:id` |
| Payment | `POST /payment/webhook` (RevenueCat; no JWT, token-verified) |
| Admin | `GET /admin/reports\|posts/search\|posts/:id\|users/search\|users/:id\|ops/metrics\|ops/metrics/prometheus`, `POST /admin/ban`, `DELETE /admin/posts/:id\|comments/:comment_id` |

---

## 12. Getting Started

### 12.1 Prerequisites

- **Go** 1.24+ (1.25 recommended; CGO required for H3 — `gcc/musl-dev`)
- **Docker** + **Docker Compose**
- **Flutter SDK** `>=3.1.5 <4.0.0`
- **Node.js** 20+ (Admin SPA)
- **Air** (optional hot reload): `go install github.com/air-verse/air@latest`
- **Local-only secret files** (never committed): root `.env`, `app/.env`, `google/*` or `backend/firebase-service-account.json` — copy shapes from `.env.example` and your Firebase console.

### 12.2 Start infrastructure

Dev (hot-reload, host ports):

```powershell
docker-compose -f infras/docker-compose.yml up -d
```

- **PostgreSQL**: `localhost:5433` (dev DB/user/pass)
- **Redis**: `localhost:6380`
- **API**: `localhost:8081`

Prod-like (Kafka, MinIO, Nginx, Fail2ban):

```powershell
# fill .env first: DB_PASSWORD, REDIS_PASSWORD, JWT_SECRET (≥32 chars)
docker compose up -d --build
```

Kafka topics are auto-created by `kafka-setup`.

### 12.3 Run backend

```powershell
cd backend
go run ./cmd/api        # or: air
go run ./cmd/worker     # or: air -c .air.worker.toml
```

Migrations / backfills:

```powershell
cd backend
go run ./cmd/migrate -mode migrate
go run ./cmd/migrate -mode backfill-gold-weekly -weeks 12
go run ./cmd/migrate -mode reconcile-gold-weekly -weeks 12
go run ./cmd/migrate -mode backfill-gold-seasonal -weeks 12
go run ./cmd/migrate -mode reconcile-gold-seasonal -weeks 12
```

Config: `backend/config.yaml` (prod defaults) + `backend/config.local.yaml` (localhost). Sections — `server` (timeouts, 500 MB body), `database` (25 open/5 idle, 5m lifetime), `redis` (pool 10), `cache` (profile stats TTL), `feed` rings/shares, `moderation` (shadow_mode, 4 thresholds+ratios, 10 reports/day), `activation` (72/120h, 3 login days, 5 meaningful actions, 3 regs/device/day), `eventbus` (kafka:9092), `admin` seed, `storage` (MinIO buckets + ffmpeg + temp bucket), `firebase`, `jwt` (15m/24h; local 24h/168h), `cors` (`Idempotency-Key` allowed), `oauth` (Apple/Google issuers).

### 12.4 Run mobile

```powershell
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define-from-file=app/.env
flutter run --debug --flavor dev -t lib/main_dev.dart   # dev flavor
```

Live DB: `docker exec -it brightbund-db psql -U user -d brightbund` (container names still carry the historic prefix).

### 12.5 Run Admin SPA

```powershell
cd spa
npm install
npm run dev     # :3001, proxies /api → :8080
npm run build   # → spa/dist, served by nginx at /admin/
```

Open `http://localhost:3001/admin/login`. Seed: register the `admin.emails` user via normal auth, restart API (`EnsureAdmins` promotes), then log in. Refresh prod with rebuild + `docker compose up -d nginx`.

---

## 13. Anti-Abuse & Economic Integrity

1. **Idempotent operations** — `reference_id` UNIQUE on every ledger write, post-creation keys, chat message keys, device tokens, send tracking. Replays return existing rows; double-spend is structurally impossible.
2. **Layered rate limiting** — Fiber limiters (auth/register/chat/settings), Fail2ban at the edge, monthly transfer caps, P2P + pair cooldowns, report cooldowns, seal-decay windows.
3. **Quiet-Shop UX** — `INSUFFICIENT_FUNDS` surfaces as a heartbeat micro-animation on the shop icon, never a blocking modal.
4. **Zero client trust** — ranks, balances, fatigue, geo, task verification all recomputed server-side from verified telemetry.
5. **Graph protection** — `user_interactions` + pair cooldowns + `REPEAT_TRANSFER_PATTERN` violations break A↔B farming rings; monthly caps bound blast radius.
6. **Moderation depth** — typed strikes, publishing ladder, shadow distribution, reporter reputation, activation gating, deferred-referral payout only for genuinely active referees.
7. **Auditability** — immutable ledger + violation logs (+IP/endpoint) + ops metrics (JSON + Prometheus) + full-text admin search over users and posts.

---

## 14. Testing & Verification

Go unit tests plus 19 curl-based end-to-end suites in [`tests/`](tests/). The canonical `test_all.sh` spins up admin + 3 users and walks health → auth-guard → economy → profiles/relationships → feed → map/task-lifecycle → ranks/settings/admin-reports, with per-request logging and PASS/FAIL tallies.

```bash
bash tests/test_all.sh
bash tests/test_eco.sh                  # Economy & ledger
bash tests/test_eco_new.sh              # New economy flows
bash tests/test_economy_cooldown.sh     # Cooldown enforcement
bash tests/test_feed.sh                 # Feed & anti-doomscroll
bash tests/test_feed_smart.sh           # Smart blending
bash tests/test_map.sh                  # Tasks & regions
bash tests/test_geolocation.sh
bash tests/test_geo_admin.sh            # H3 admin hierarchy
bash tests/test_ranks.sh                # Ranks
bash tests/test_allies.sh
bash tests/test_relationship_status.sh
bash tests/test_profiles.sh
bash tests/test_profile_get.sh
bash tests/test_profile_partial_update.sh
bash tests/test_referrals.sh
bash tests/test_seal_cooldowns.sh
bash tests/test_free_seal_lifecycle.sh
bash tests/test_issues.sh
```

```powershell
cd backend
go test -v ./...
go test -v ./internal/modules/...
```

CI runs `golangci-lint` + `go test ./...` against PostGIS 16 on main/develop. Deploy builds api/worker/migrate, tests, then SSH-deploys.

---

## 15. Roadmap & Ideas

### 15.1 Shipped MVP stages (from the RPD)

- **Stage 1 — Foundation & Economy (month 1):** infra, OAuth+JWT, double-entry ledger with idempotency, profiles + MinIO uploads.
- **Stage 2 — Core loop & geo (month 2):** PostGIS tasks, feed mixer, Give-Seal wiring, comments, doomscroll middleware, rate limits.
- **Stage 3 — Gamification, revenue, launch (month 3):** async ranks, Redis ZSET leaderboards, WS chat + Pub/Sub, RevenueCat webhooks, store compliance.

### 15.2 Feed performance program (from the audit)

- **Phase 1 (quick wins, no schema):** partial/cov­ering/expression indexes, batch media fetch, bulk reporter deltas.
- **Phase 2 (structural):** async Vision uploads, Go-side sampling with precomputed strike counts, ally-list Redis cache, combined profile-grid query.
- **Phase 3 (advanced):** short-TTL feed cache, GiST-pushed geo CTE, templated comment queries with batched reply counts. Target: 1–2s → 200–400ms → <50ms cached.

### 15.3 Beyond MVP

Blockchain ledger export, wallet snapshots, reversal entries (refunds as new rows, never edits), multi-currency wallets, user transaction tags, read replicas, ledger date-partitioning, Redis balance cache, event-sourced ledger stream, ML ranking, clans/groups, Mapbox upgrade (one-line swap), App Store + Play submission (`privacy`/`terms`/`account-deletion` pages already served by Nginx).

---

## 16. Documentation & References

- [Product Requirements & Architecture (RPD)](docs/BrightBund_RPD.md) — modular monolith, 10 epics (auth → profiles → feed → economy → ranks → map → chat → payments → infra → store readiness), staged plan
- [Economy & Transaction System](docs/Economy_Transaction_System.md) — wallets/ledger schema, centinels, categories, atomic flows, history queries, fraud SQL
- [Feed Module Design](docs/Feed_Module_Changes.md) — doomscroll machine, profile posts endpoints, flush reliability, sanction ladder + adaptive geo params
- [Geospatial Architecture & Maps](docs/Geo_Module.md) — H3 mapping, assignment, champion cycle, radius search, tile path, definition of done
- [Ops commands](docs/command.md) — flavors, psql, cooldown test, migrate/backfill modes
- [Feed perf audit](issues/opt-feed.md) — P0–P3 roadmap with file-level fixes
- [Admin SPA routes](spa/routes.md) — guards + page→API mapping
- [Admin SPA plan](spa/implementation-plan.md) — scaffold → auth/layout → users → posts → reports/dashboard
- Backend contracts: [`backend/docs/swagger.yaml`](backend/docs/swagger.yaml) + `/swagger/` UI
- Legal/static: `index.html`, `privacy.html`, `terms.html`, `account-deletion-info.html`, `404.html`

---

## 17. Contributing & Secret Policy

1. Copy `.env.example` → `.env` (and equivalents for `app/`, `backend/`, `google/`) — never commit the real ones.
2. The root `.gitignore` blocks env files, Firebase credentials, keystores, and `google/`; keep it that way.
3. API contracts live in `backend/docs` (OpenAPI 3.0) — update them before implementing endpoint changes so mobile stays unblocked.
4. Domain PRs touching `economy` or `map` get extra-strict review (marked CRITICAL in the RPD).
5. Verify with the relevant `tests/*.sh` suite plus `go test ./...` before pushing.

---

## 18. License

This project is proprietary and confidential. All rights reserved.
