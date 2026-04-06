# BrightBund Backend Issue Tracking & Tasks

## 1. Economy Module: Silver Seal Transfer Failures
- [ ] **Debug 1.0 Seal Transfer Failure**: investigate why sending exactly 1.0 Silver Seal fails (as reported by user).
- [ ] **Refactore `processSealTransfer`**: the transactions should be only with 1 amount, any other amount should be rejected 
- [ ] **Verify `CentinelsPerSeal` Consistency**: Ensure the `100` factor is correctly used across all calculations (accruals, transfers, rewards).

## 2. Settings Module: Interaction Settings 500 Error
- [ ] **Investigate `api/v1/settings/interactions`**: Reproduce the `500 interaction_fetch_failed` error.
- [ ] **Check `user_settings` Table**: Verify if the table exists and has the `who_can_send_messages` column (from migration `041`).
- [ ] **Fix Fallback Logic**: In `GetUserSettings`, ensure that if a user has no settings record yet, a default one is created/returned instead of erroring with 500.

## 3. Map Module: Tasks & Champions Missing
- [ ] **Tasks List Empty**: Debug why `/api/v1/map/tasks` returns an empty list even if tasks exist in the DB. Check coordinate order (Lat/Lon vs Lon/Lat).
- [ ] **Champions Rendering**: Investigate `GetRegionChampions` logic. Check if spatial indexing or region-based grouping is filtering out all results.
- [ ] **Coordinate Validation**: Verify if the frontend is sending coordinates in the format the backend expects (PostGIS usually uses `Long, Lat`).

## 4. Database & Infrastructure
- [ ] **Run Migrations Check**: Ensure all migrations (especially settings and maps) have been applied correctly to the local DB.
- [ ] **Check Logs**: Monitor `brightbund-api` logs during failed requests to see exact stack traces or SQL errors.
