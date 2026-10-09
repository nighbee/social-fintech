# Social-Fintech - Instructional Context

This file provides foundational mandates and project-specific context for Gemini CLI when interacting with the Social-Fintech codebase.

## Project Overview
Social-Fintech is a high-integrity social platform designed with a focus on economic security, anti-abuse, and gamification. It centers around a dual-currency system ("Silver Seals" and "Gold Seals") and a progression system ("Ranks") to incentivize meaningful interactions and protect the social graph.

### Core Architecture
- **Strategy:** Modular Monolith with Clean Architecture principles.
- **Backend:** Go (Golang) 1.24+ using the Fiber framework.
- **Frontend:** Mobile App built with Flutter (iOS/Android).
- **Primary Database:** PostgreSQL 16 with PostGIS extension for geospatial features.
- **Cache & Real-time:** Redis 7 (ZSET for leaderboards, Pub/Sub for scaling WebSockets).
- **Object Storage:** MinIO (S3-compatible) for media and avatars.
- **Authentication:** Firebase Auth integration + Backend-side JWT session management (OIDC/OAuth).

## Domain Structure
The backend is organized into strict domains located in `backend/internal/modules/`:
- **Auth:** Registration, login, and session management.
- **Profiles:** User and company profile management.
- **Economy:** Double-entry ledger system for Seals.
- **Feed:** Geo-aware content discovery with "Anti-Doomscroll" mechanics.
- **Map & Tasks:** Geospatial task discovery using PostGIS.
- **Gamification/Ranks:** Asynchronous rank and status calculations.
- **Leaderboards:** Real-time rankings using Redis Sorted Sets.
- **Chat:** 1:1 messaging via WebSockets.
- **Payment:** IAP receipt validation and ledger integration.

## Getting Started

### Prerequisites
- Docker and Docker Compose
- Go 1.24+
- Flutter SDK (>=3.1.5)
- PostgreSQL (PostGIS), Redis, and MinIO (managed via Docker)

### Running the Project
1.  **Infrastructure:**
    ```powershell
    docker-compose up -d
    ```
    *Note: Starts DB (port 5434), Redis (port 6380), and MinIO (port 9000).*

2.  **Backend API:**
    ```powershell
    cd backend
    go run cmd/api/main.go
    # For hot-reload development:
    air
    ```

3.  **Backend Worker:**
    ```powershell
    cd backend
    go run cmd/worker/main.go
    # For hot-reload development:
    air -c .air.worker.toml
    ```

4.  **Frontend App:**
    ```powershell
    cd app
    flutter pub get
    dart run build_runner build --delete-conflicting-outputs
    flutter run
    ```

## Development Conventions

### Backend (Go)
- **Framework:** Fiber v2.
- **Database Access:** `sqlx` for structured SQL queries.
- **Logging:** Structured logging using `uber-go/zap`.
- **API Contracts:** OpenAPI 3.0/Swagger documentation. Update `backend/docs` when changing endpoints.
- **Migrations:** Located in `backend/migrations`. SQL-based evolution.

### Frontend (Flutter)
- **State Management:** BLoC pattern (`flutter_bloc`).
- **Navigation:** `go_router`.
- **Networking:** `dio` with `talker_dio_logger`.
- **Data Modeling:** `freezed` and `json_serializable`.
- **DI:** `get_it` and `injectable`.
- **Maps:** `mapbox_maps_flutter`.

### Testing
- **Integration Tests:** Shell scripts using `curl` located in the root `tests/` directory.
- **Verification:** Always run relevant tests from `tests/*.sh` after making changes to domain logic.

## Anti-Abuse & Integrity Mandates
- **Server as Source of Truth:** Never trust client-side calculations for economy or rank logic.
- **Idempotency:** All ledger operations and payments MUST be idempotent.
- **Rate Limiting:** Mandatory for all high-value interaction endpoints (giving seals, posting).
- **Quiet Shop Logic:** Frontend should handle `INSUFFICIENT_FUNDS` errors with visual cues (Heartbeat animation) rather than disruptive popups.
