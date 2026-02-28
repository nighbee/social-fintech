# Mapbox Map Implementation Plan

## API Status from Swagger (as of February 26, 2026)
- Available map endpoints:
1. `GET /map/champions`
2. `POST /map/region`
- Missing endpoints for full map task lifecycle shown in product mocks (task feed/details/apply/cancel/verify/confirm/comments/messages flows).

## Stage 1 (Current): Show Map Only
Goal: open Map tab and render a real Mapbox map.

Scope:
1. Add `mapbox_maps_flutter` dependency.
2. Configure map token from `--dart-define=MAPBOX_ACCESS_TOKEN=...`.
3. Render `MapWidget` in `MapPage` with default US camera center.
4. Show fallback UI when token is missing.
5. Keep existing app shell (`CustomAppBar`, `CustomNavBar`) unchanged.

Acceptance criteria:
1. `Map` tab opens without crash.
2. Map tiles render when token is provided.
3. Clear message is shown when token is missing.

## Stage 2: Feature Architecture Baseline (Clean Architecture + BLoC)
Goal: introduce production-ready map module structure.

Scope:
1. Add `map/domain`, `map/data`, `map/presentation/bloc`.
2. Create `MapBloc` with states: `initial/loading/loadingError/loaded`.
3. Register map dependencies in GetIt/Injectable.
4. Add base `MapViewModel`.

## Stage 3: Region Selection + Backend Sync
Goal: user selects region and persists it via backend.

Scope:
1. Camera interaction + selected region model.
2. Integrate `POST /map/region`.
3. Loading/success/error UX and retry.

## Stage 4: Region Champions
Goal: display and navigate champions data.

Scope:
1. Integrate `GET /map/champions`.
2. Add ranking bottom sheet/page.
3. Open public profile from champion item.

## Stage 5: Task Flow on Map (Requires API Expansion)
Goal: implement core task scenarios from design references.

Scope (requires backend contracts):
1. Load tasks on map.
2. Task detail card and apply/cancel actions.
3. Acceptance/decline states and visual status changes.

## Stage 6: Verification Code, Comments, Messages
Goal: complete transactional flow from references.

Scope:
1. Verification code input flow.
2. Comment and messaging overlays.
3. Success/failure completion states.

## Stage 7: Hardening and QA
Goal: production readiness.

Scope:
1. Localization and copy review.
2. Edge cases: offline/network/permissions/empty states.
3. Unit/BLoC/widget tests and smoke checks for Android/iOS.
