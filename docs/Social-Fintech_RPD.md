# Social-Fintech

- Technical Design Document

  # Social-Fintech — Backend Architecture & Technical Design (MVP)

  **Author:** Almaz Team Lead / Architect

  **Status:** Review

  ***

  ## 1. Document Goals

  This document defines the target technical architecture for Social-Fintech MVP.
  It establishes the principles for server-side logic, domain modeling,
  and key technical decisions aimed at:

  - **Economic Security:** Protecting the value of Seals and Ranks.
  - **Anti-Abuse:** Preventing farming and manipulation of the social graph.
  - **Speed & Quality:** Enabling rapid MVP development with a clear path to scaling.
  - **Maintainability:** ensuring the code does not become "legacy" immediately after launch.

  ***

  ## 2. Architectural Approach

  ### 2.1 Strategy: Modular Monolith

  We will adopt a **Modular Monolith** architecture with **Clean Architecture** principles.

  ONLY MODULAR MONOLITH WITHOUT FURTHER CHANGES AND CROSS MODULAR LOGIC, BUSINESS LOGIC IS HANDLED ONLY BY SERVER SIDE

  - **Speed:** Eliminates the DevOps overhead of managing microservices (networking, tracing, distributed transactions) during the critical 3-month MVP phase.
  - **Data Integrity:** Allows us to use ACID transactions across domains (e.g., spending money to create a task) without complex sagas.
  - **Future-Proof:** The code will be structured into strict domains (internal/economy, internal/feed), making it easy to extract microservices later if scaling requires it.

  ***

  ## 3. High-Level System Design

  **Clients:**

  - Mobile App (Flutter — iOS / Android)

  **Infrastructure:**

  - **Load Balancer / API Gateway:** Entry point (SSL termination).
  - **Backend Application:** Go (Golang), fiber/net/gorm.
  - **Primary DB:** PostgreSQL, postgis. (Map tiles: `flutter_map` + OSM for MVP; Mapbox upgrade path post-MVP — see Geo_Module.md)
  - **Cache / Realtime:** Redis (Leaderboards, Pub/Sub, Rate Limits), zset, websocket .
  - Documentation: Swagger
  - Infra: Docker compose, CI/CD

  ***

  ## 4. Technology Stack

  - **Language:** Go (Golang) 1.22+
  - **Framework:** Fiber or Echo (High performance REST API)
  - **Database:** PostgreSQL 16 **with PostGIS extension** (Required for Geospatial queries).
  - **Cache:** Redis 7+
  - **Realtime:** WebSocket (Native or Gorilla)
  - **Documentation:** **OpenAPI 3.0 (Swagger)** — API contracts will be defined _before_ implementation to unblock Mobile development.

  ***

  ## 5. Domain Decomposition

  ### 5.1 Auth & Accounts

  **Responsibility:** Registration, Login, Session Management, Oauth.

  - **Principals:** Server-side validation of all tokens.
  - **Meta-data:** Storing basic Device ID / IP for anti-abuse analysis.

  ### 5.2 Profile

  **Responsibility:** Public profiles, Bios, Aggregated Stats.

  - **Note:** Profiles do not calculate stats on the fly. They read pre-calculated
    aggregates from the Economy/Rank domains to ensure fast load times.

  ### 5.3 Feed & Anti-Doomscroll

  **Responsibility:** Post creation, Comments, Feed Generation.

  - **Logic:**
    1. **Mixer:** The feed combines "Allies" (Subscription) + "Local" (Geo-radius) + "World" (Random ~10%).
    2. **Anti-Doomscroll:** The server tracks session_start_time in Redis.
    3. If current_session > 20 mins: The API adds a feed_degraded: true flag and increases response latency/reduces content quality. The visual "slowdown" is triggered by the mobile app based on this flag.

  ### 5.4 Economy (Critical)

  **Responsibility:** All transactions involving Silver/Gold Seals.

  **Architecture:** **Ledger-Based System (Double-Entry Bookkeeping).**

  - **Data Structure:**
    - ledger_entries (Append-only log of every movement).
    - wallets (Current calculated balance).
  - **Quiet Shop Logic:**
    - If a user tries to spend Silver Seals but has balance < cost, the API will **not** return a generic 500 error.
    - It will return a specific status (e.g., 402 Payment Required or code: "INSUFFICIENT_FUNDS").
    - The Mobile App detects this code and triggers the "Heartbeat" animation on the Shop Icon instead of showing an error popup.

  ### 5.5 Map & Tasks

  **Responsibility:** Geospatial tasks and discovery.

  **Tech:** **PostGIS**.

  - **Querying:** Using ST_DWithin and spatial indexing for millisecond-fast searches of tasks nearby.
  - **Lifecycle:** Creating a task wraps two operations in one transaction: Debit Wallet + Insert Task.

  ### 5.6 Ranks & Gamification

  **Responsibility:** Calculating User Status (Quartz -> Sovereign).

  - **Logic:** Ranks are calculated asynchronously via background workers based on Gold Seal history and Season activity.

  ### 5.7 Leaderboards(CRITICAL)

  **Responsibility:** Local and Global Rankings.

  **Tech:** **Redis Sorted Sets (ZSET)**.

  - **Performance:** Real-time rank calculation happens in Redis.
  - **Persistence:** Snapshots are saved to PostgreSQL for history.

  ### 5.8 Notifications & Chat

  **Responsibility:** 1:1 Messaging and User Alerts.

  **Tech:** WebSocket + Redis Pub/Sub (to scale across multiple server instances).

  ### 5.9 Payments(CRITICAL)

  **Responsibility:** IAP (Apple/Google) integration.

  - **Security:** Server-side receipt validation. Silver Seals are only minted after the
    server confirms the purchase validity directly with Apple/Google
    servers.

  ***

  ## 6. Anti-Abuse Strategy(CRITICAL)

  **Philosophy:** The Server is the only Source of Truth.

  1. **Rate Limiting:** Strict API limits on "Give Seal" and "Create Post" to prevent bot spam.
  2. **Graph Protection:** Logic to detect circular farming (e.g., User A gives to User B, User B gives back to User A repeatedly).
  3. **Limits:** Hard caps on how many Seals can be transferred to a single user per month.

  ***

  ## 7. Asynchronous Processes (Workers)

  We will use background workers for heavy lifting:

  - Daily free Silver Seal accrual.
  - Season transitions and rank recalculations.
  - Cleanup of expired tasks on the map.

  ***

  ## 8. MVP Constraints

  To ensure we launch in 3 months:

  - **No ML/AI** for the feed initially (Algorithmic sort only).
  - **No "Clans"** or complex group mechanics.
  - **Focus:** Core Economy stability and "Feel" of the app (Map/Feed).

  ***

  ## 9. Team Lead Responsibilities

  As Team Lead, I will oversee:

  1. **Architecture Integrity:** Ensuring no "spaghetti code" enters the codebase.
  2. **API Contracts:** Defining Swagger specs for the Mobile dev.
  3. **Code Review:** Strict review of all logic related to Economy and Map.

  **all parts that marked with CRITICAL are under OWNER review**

- Code of Conduct

  # Social-Fintech MVP Decomposition

  **MVP workload**, decomposed into **Epics → Features → Engineering Work**,

  ***

  ## EPIC 1 — Authentication & Accounts

  ### Feature 1.1 — User Registration & Login

  Backend work:

  - OAuth integration (Apple)
  - OAuth integration (Google)
  - Email / phone auth (if approved)
  - Backend token verification
  - JWT issuance (access + refresh)
  - Token refresh flow
  - Session invalidation
  - Device metadata capture

  Mobile work:

  - Auth screens (login / signup)
  - Provider login flows
  - Token storage
  - Session restore on app launch
  - Logout handling

  ***

  ### Feature 1.2 — Account Security

  Backend work:

  - Server-side session tracking
  - Rate limiting on auth endpoints
  - Suspicious login detection (basic)

  Mobile work:

  - Error handling for auth limits
  - Forced re-auth UI

  ***

  ## EPIC 2 — Profiles

  ### Feature 2.1 — User Profile

  Backend work:

  - Profile data model
  - CRUD profile endpoints
  - Region / city resolution
  - Profile visibility rules

  Mobile work:

  - Profile screen
  - Edit profile UI
  - Avatar upload

  ***

  ### Feature 2.2 — Profile Statistics

  Backend work:

  - Aggregated stats endpoints
  - Cached profile stats

  Mobile work:

  - Stats display
  - Loading / error states

  ***

  ## EPIC 3 — Feed & Interactions

  ### Feature 3.1 — Feed Retrieval

  Backend work:

  - Feed query logic (allies + local + world)
  - Pagination
  - Feed ordering rules
  - Server-side session tracking

  Mobile work:

  - Feed UI
  - Infinite scroll
  - Pull-to-refresh

  ***

  ### Feature 3.2 — Post Creation

  Backend work:

  - Post creation endpoint
  - Media upload handling(minio s3)
  - Content validation

  Mobile work:

  - Create post UI
  - Image picker
  - Upload progress handling

  ***

  ### Feature 3.3 — Comments

  Backend work:

  - Comment CRUD
  - Comment threading (if enabled)
  - Rate limiting

  Mobile work:

  - Comment UI
  - Submit / delete comment

  ***

  ### Feature 3.4 — Silver Seal Interaction

  Backend work:

  - Seal spend operation
  - Validation (balance, limits)
  - Ledger entry creation

  Mobile work:

  - Seal interaction UI
  - Error states (insufficient balance)

  ***

  ### Feature 3.5 — Anti-Doomscroll

  Backend work:

  - Session time tracking
  - Feed degradation flag

  Mobile work:

  - Scroll behavior adjustment

  ***

  ## EPIC 4 — Economy & Seals

  ### Feature 4.1 — Ledger System

  Backend work:

  - Ledger schema
  - Atomic transaction logic
  - Idempotency enforcement
  - Balance recalculation
  - Audit logging

  ***

  ### Feature 4.2 — Silver Seal Balance

  Backend work:

  - Balance storage
  - Balance retrieval endpoint

  Mobile work:

  - Balance display

  ***

  ### Feature 4.3 — Free Daily Accrual

  Backend work:

  - Scheduled accrual job
  - Cap enforcement
  - Server-time validation

  ***

  ### Feature 4.4 — Limits & Cooldowns

  Backend work:

  - Monthly transfer caps
  - Cooldown timers
  - Violation logging

  Mobile work:

  - Error messaging

  ***

  ## EPIC 5 — Ranks & Leaderboards

  ### Feature 5.1 — Rank Calculation

  Backend work:

  - Rank rules engine
  - Progress calculation
  - Rank persistence

  Mobile work:

  - Rank UI
  - Progress display

  ***

  ### Feature 5.2 — Leaderboards

  Backend work:

  - Redis ZSET leaderboards
  - Periodic recalculation
  - Region-based segmentation

  Mobile work:

  - Leaderboard UI
  - Region switch

  ***

  ### Feature 5.3 — Seasons

  Backend work:

  - Season lifecycle
  - Season rollover jobs
  - Historical data storage

  Mobile work:

  - Season history UI

  ***

  ## EPIC 6 — Map & Tasks

  ### Feature 6.1 — Task Creation

  Backend work:

  - Task schema
  - Geo-indexing
  - Silver Seal spend on create

  Mobile work:

  - Map UI
  - Create task UI

  ***

  ### Feature 6.2 — Task Lifecycle

  Backend work:

  - Status transitions
  - Ownership rules
  - Expiry handling

  Mobile work:

  - Task interaction UI

  ***

  ## EPIC 7 — Chat & Notifications

  ### Feature 7.1 — 1:1 Chat

  Backend work:

  - WebSocket server
  - Message persistence
  - Delivery acknowledgment

  Mobile work:

  - Chat UI
  - Realtime updates

  ***

  ### Feature 7.2 — Notifications

  Backend work:

  - Notification events
  - In-app notification storage

  Mobile work:

  - Notification list UI

  ***

  ## EPIC 8 — Payments & Monetization

  ### Feature 8.1 — In-App Purchases

  Backend work:

  - Receipt validation (Apple / Google)
  - Idempotent purchase handling
  - Ledger integration

  Mobile work:

  - Store UI
  - Purchase flow

  ***

  ## EPIC 9 — Platform & Infrastructure

  ### Feature 9.1 — Deployment

  Backend work:

  - CI/CD pipeline
  - Environment configuration

  ***

  ### Feature 9.2 — Observability

  Backend work:

  - Structured logging
  - Error tracking
  - Metrics

  ***

  ### Feature 9.3 — Security & Rate Limiting

  Backend work:

  - Global rate limits
  - Abuse detection hooks

  ***

  ## EPIC 10 — App Store Readiness

  ### Feature 10.1 — Store Compliance

  Work:

  - Privacy policy alignment
  - App Store review fixes
  - Production config

  ***

  Anything not listed here is **explicitly out of scope for MVP** and requires a new epic or a post-MVP phase.

- Stages for 3 month (+1 month in advance)
  STAGES ARE REVIEWED BY TEAM LEAD AND OWNER
  ## **Stage 1: Foundation & Economy Core (Month 1):**
  Focus:
  Setting up the infrastructure, security, and the immutable ledger
  system. This is the most critical phase for system integrity.
  Backend Work:
  ### Week 1: Infrastructure & Setup
  - Initialize Go module, Docker Compose, and Database (PostgreSQL + PostGIS).
  - Configure CI/CD pipelines (GitHub Actions) for automated testing/builds.
  - Setup Redis connection and Structured Logging (Zap).
  ### Week 2: Authentication & Sessions
  - Implement OAuth (Apple/Google) validation.
  - Implement JWT issuance (Access/Refresh tokens) and Middleware.
  - Device metadata capture for security logging.
  ### Week 3: The Ledger (Economy Domain)
  - Implement double-entry ledger schema (ledger_entries, wallets).
  - Write atomic SQL transaction logic for funds transfer.
  - Implement idempotency checks to prevent double-spending.
  ### Week 4: Profiles & Data
  - User Profile CRUD (Create, Read, Update, Delete).
  - Profile statistics aggregation (reading from the Ledger).
  - Image upload handling (Integration with S3/MinIO).
  Mobile Work:
  - App skeleton setup (Navigation, Theme, State Management).
  - Authentication screens (Login, Signup, Social Auth).
  - Profile viewing and editing screens.
  - Integration with Backend Auth API.
  ### Stage 1 Deliverable:
  A deployed backend where users can securely register, log in, and the
  internal currency system is fully functional and testable via API.
  ***
  ## Stage 2: Core Loop & Geo-Services (Month 2)
  Focus: Content, Map, and Interactions. This makes the application functional as a social platform.
  Backend Work:
  ### Week 5: Geo-Services (Map Domain)
  - Implement PostGIS spatial queries (Find tasks within radius).
  - Task Creation logic (Transactional: Debit Seal -> Create Task).
  - Task Lifecycle management (Open -> Closed).
  ### Week 6: Feed & Content
  - Feed Mixer logic (Allies + Local + Random).
  - Post creation endpoint (Text + Media).
  - Pagination and Sorting optimization.
  ### Week 7: Interactions & Anti-Doomscroll
  - Implement "Give Seal" logic (Connecting Feed to Economy).
  - Implement Comments and basic moderation tools.
  - Anti-Doomscroll Middleware (Session time tracking in Redis + Feed degradation flag).
  ### Week 8: Stability & Integration
  - Integration testing of Map and Feed.
  - Performance tuning of SQL queries.
  - Rate limiting configuration.
  Mobile Work:
  - `flutter_map` + OSM tiles integration and custom markers (Mapbox upgrade path documented in Geo_Module.md).
  - Task creation UI.
  - Feed UI with infinite scrolling.
  - "Quiet Shop" logic implementation (UI handling for insufficient funds).
  ### Stage 2 Deliverable:
  A functioning social app where users can post content, see nearby tasks
  on a map, interact with content using Seals, and experience the
  anti-doomscroll mechanic.
  ***
  ## Stage 3: Gamification, Revenue & Launch (Month 3)
  Focus: Retention mechanics, Real-time features, and Monetization. This phase prepares the app for the App Store.
  Backend Work:
  ### Week 9: Ranks & Workers
  - Asynchronous workers for Rank calculation (Gold Seal history).
  - Season logic (Time-based boundaries for stats).
  - Background jobs for daily free accruals.
  ### Week 10: Leaderboards
  - Redis ZSET implementation for real-time rankings.
  - Global vs Local leaderboard segmentation.
  - Snapshots for historical data.
  ### Week 11: Real-time Communication
  - WebSocket Hub implementation for 1:1 Chat.
  - Redis Pub/Sub for message distribution.
  - Push Notification triggers.
  ### Week 12: Monetization & Compliance
  - RevenueCat Webhook integration (IAP validation).
  - App Store compliance checks (Privacy policy API, Account deletion).
  - Final Security Audit and Load Testing.
  Mobile Work:
  - Rank and Leaderboard screens (High fidelity UI).
  - Chat interface.
  - In-App Purchase UI (Store).
  - Final bug fixing and polish.
  ## Stage 3 Deliverable:
  Production-ready MVP containing all business logic, monetization, and social features,
  ready for submission to Apple App Store and Google Play.

[Social-Fintech MVP Tasks](https://www.notion.so/2e389788f5bf80c7aa2ddfba06110c9c?pvs=21)

Simple tracking

[Epics](Epics%202e389788f5bf80529776ec54b5a05919.csv)

[Untitled](Untitled%202e389788f5bf80ae8940dd0b79f83174.csv)
