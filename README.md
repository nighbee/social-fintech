# BrightBund

<div align="center">

[![Go Version](https://img.shields.io/badge/Go-1.25+-00ADD8?style=for-the-badge&logo=go&logoColor=white)](https://golang.org)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![React](https://img.shields.io/badge/React-18-61DAFB?style=for-the-badge&logo=react&logoColor=black)](https://react.dev)
[![Vite](https://img.shields.io/badge/Vite-6.0-646CFF?style=for-the-badge&logo=vite&logoColor=white)](https://vitejs.dev)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16%20%2B%20PostGIS-336791?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Redis](https://img.shields.io/badge/Redis-7%20Alpine-DC382D?style=for-the-badge&logo=redis&logoColor=white)](https://redis.io)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com)

**High-integrity social platform engineered with economic security, anti-abuse mechanics, geospatial discovery, and gamified progression.**

[Key Features](#key-features) • [Architecture](#system-architecture) • [Project Layout](#project-layout) • [Getting Started](#getting-started) • [Core Modules](#core-domain-modules) • [Security & Anti-Abuse](#anti-abuse--economic-integrity) • [Testing](#testing--verification)

</div>

---

## Overview

**BrightBund** is a next-generation social ecosystem designed to eliminate social graph farming, engagement manipulation, and endless doomscrolling. Built upon a **dual-currency economy** (*Silver Seals* and *Gold Seals*) and an asynchronous **Rank Progression System**, BrightBund aligns incentives so that authentic community interaction, localized challenges, and high-value contributions are rewarded.

### Core Tenets

- **Server as Source of Truth**: All economic calculations, balances, transactions, and status evaluations are strictly enforced server-side.
- **Double-Entry Ledger**: Complete immutability and financial integrity for all virtual currency operations.
- **Anti-Doomscroll Feed**: Geospatially-aware content distribution prioritizing local and quality community engagement over algorithmic addiction loops.
- **Geospatial Discovery (PostGIS)**: Real-time region detection, champion tracking, and location-based community tasks.

---

## Key Features

- **Double-Entry Currency Engine**: Silver Seals (earned/soft currency) and Gold Seals (premium currency) backed by transactional ledger entries with zero float drift.
- **Geospatial Tasks & Maps**: PostGIS-powered regional champion rankings, localized quest systems, and geo-filtered feeds.
- **Dynamic Leaderboards**: Real-time rankings powered by Redis Sorted Sets (ZSET) for blazing fast query speeds.
- **Asynchronous Progression**: Dedicated background worker daemon (`asynq`) for computing weekly rank shifts, badge decay, and rewards.
- **Real-Time Communication**: WebSocket-driven 1:1 encrypted messaging and live notifications.
- **Multi-Client Support**: Cross-platform mobile client (Flutter) and administrative operations dashboard (React + Vite).

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
                              │     Nginx Gateway     │ (SSL / Fail2ban)
                              └───────────┬───────────┘
                                          │
            ┌─────────────────────────────┼─────────────────────────────┐
            │                             │                             │
            ▼                             ▼                             ▼
┌───────────────────────┐     ┌───────────────────────┐     ┌───────────────────────┐
│     React Admin SPA   │     │    Go API Gateway     │     │   Go Asynq Worker     │
│   (Vite Dashboard)    │     │   (Fiber v2 Server)   │     │  (Rank & Geo Daemon)  │
└───────────────────────┘     └───────────┬───────────┘     └───────────┬───────────┘
                                          │                             │
            ┌─────────────────────────────┴─────────────────────────────┴┐
            │                                                            │
            ▼                                                            ▼
┌───────────────────────┐     ┌───────────────────────┐     ┌───────────────────────┐
│  PostgreSQL + PostGIS │     │        Redis 7        │     │      MinIO / S3       │
│  (Data & Geo Tables)  │     │  (Cache, ZSET, Queue) │     │    (Media Storage)    │
└───────────────────────┘     └───────────────────────┘     └───────────────────────┘
```

---

## Project Layout

```
.
├── app/                  # Mobile application (Flutter 3.x, BLoC, GoRouter, Dio)
├── backend/              # Core API & Worker services (Go 1.25, Fiber v2, sqlx)
│   ├── cmd/
│   │   ├── api/          # Main HTTP/WebSocket API entrypoint
│   │   └── worker/       # Asynchronous background job worker daemon
│   ├── internal/
│   │   └── modules/      # Strict domain modules (auth, feed, economy, map, etc.)
│   ├── migrations/       # SQL schema migrations
│   └── docs/             # Swagger / OpenAPI contracts
├── spa/                  # Admin Control Center (React 18, Vite 6, Tailwind/CSS)
├── docs/                 # Product specifications (RPD, Economy, Geo, Feed)
├── infras/               # Docker Compose configurations & service orchestration
├── nginx/                # Reverse proxy configs & SSL orchestration
├── fail2ban/             # Security filters and rate-limiting rules
└── tests/                # Automated shell integration & load test suites
```

---

## Core Domain Modules

The backend is partitioned into isolated domain packages inside [`backend/internal/modules/`](backend/internal/modules/):

| Module | Responsibilities |
| --- | --- |
| **`auth`** | Multi-factor registration, Firebase Auth / OIDC session issuance, JWT rotation, and device binding. |
| **`profiles`** | User metadata, avatar management, and privacy preferences. |
| **`economy`** | Idempotent double-entry ledger for Silver and Gold seals, cooldown enforcement, and store transactions. |
| **`feed`** | Geo-aware post creation, reactions, comments, media attachments, and anti-doomscroll pacing. |
| **`map`** | PostGIS spatial queries, region bounding, territory champions, and location-bound challenges. |
| **`ranks`** | Asynchronous rank calculation, status level shifts, and seasonal progression. |
| **`leaderboards`** | High-performance Redis ZSET leaderboards (regional, national, global). |
| **`chat`** | Real-time WebSocket 1:1 messaging, presence tracking, and delivery receipts. |
| **`payment`** | App Store / Play Store IAP receipt validation and ledger balance fulfillment. |

---

## Getting Started

### Prerequisites

Ensure you have the following installed on your host machine:

- **Go**: 1.24+ (recommended 1.25)
- **Docker** and **Docker Compose**
- **Flutter SDK**: `>=3.1.5 <4.0.0`
- **Node.js**: 20+ (for Admin SPA)
- **Air** *(optional, for Go hot reload)*: `go install github.com/air-verse/air@latest`

---

### 1. Start Infrastructure Services

Spin up PostgreSQL (PostGIS), Redis, and MinIO storage:

```powershell
docker-compose -f infras/docker-compose.yml up -d
```

- **PostgreSQL**: `localhost:5433` (DB: `brightbund`, User: `user`, Pass: `password`)
- **Redis**: `localhost:6380`
- **API**: `localhost:8081`

---

### 2. Run Backend Services

#### API Server

```powershell
cd backend
go run cmd/api/main.go
# Or with hot-reload:
air
```

#### Background Worker

```powershell
cd backend
go run cmd/worker/main.go
# Or with hot-reload:
air -c .air.worker.toml
```

---

### 3. Run Mobile App (Flutter)

```powershell
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

---

### 4. Run Admin SPA (React + Vite)

```powershell
cd spa
npm install
npm run dev
```

Open [http://localhost:5173](http://localhost:5173) in your browser.

---

## Anti-Abuse & Economic Integrity

1. **Idempotent Operations**: Every ledger transfer, quest completion, and seal transaction enforces strict idempotency keys to prevent double-spend attacks.
2. **Aggressive Rate Limiting**: Token-bucket and sliding-window rate limiters guard high-value endpoints (seal transfers, post creation, reactions).
3. **Quiet Shop Paradigm**: Client UI reacts gracefully to `INSUFFICIENT_FUNDS` with non-intrusive micro-animations rather than disruptive friction modals.
4. **Zero Client Trust**: All rank tiers, seals, and task completions are validated strictly against verified backend telemetry.

---

## Testing & Verification

BrightBund maintains a comprehensive suite of end-to-end integration and security test scripts located in the [`tests/`](tests/) directory.

Run test suites using bash (or Git Bash on Windows):

```bash
# Run all integration tests
bash tests/test_all.sh

# Run domain-specific suites
bash tests/test_eco.sh          # Economy & ledger verification
bash tests/test_feed.sh         # Feed & anti-doomscroll verification
bash tests/test_map.sh          # PostGIS geospatial tasks & regions
bash tests/test_ranks.sh        # Gamification & rank logic
```

Unit tests for backend modules:

```powershell
cd backend
go test -v ./internal/modules/...
```

---

## Documentation & References

- [Product Requirements & Architecture (RPD)](docs/BrightBund_RPD.md)
- [Economy & Transaction System](docs/Economy_Transaction_System.md)
- [Feed Module Design](docs/Feed_Module_Changes.md)
- [Geospatial Architecture & Maps](docs/Geo_Module.md)

---

## License

This project is proprietary and confidential. All rights reserved.
