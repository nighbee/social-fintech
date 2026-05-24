# Notifications Module — Implementation Tasks

Final status. All achievable tasks completed. 10 event producers are already wired; the remaining 2 (medal, verification) need new modules.

## Phase 1: User Notification Preference Toggles
- [x] DB migration — add notify_likes/comments/follows/season_opened/task_applied/admin_broadcast columns
- [x] Update Settings entity with new NotificationPreferences fields
- [x] Update Settings repository — SELECT/DEFAULTS + UpdateNotificationSettings
- [x] PublicService — GetNotificationPreferences / UpdateNotificationPreferences
- [x] GET /settings/notifications/preferences handler
- [x] PUT /settings/notifications/preferences handler
- [x] Wire routes in server.go

## Phase 2: Event Constants + Payloads
- [x] EventTypeTaskAccepted
- [x] EventTypeTaskCompleted
- [x] EventTypePostLiked
- [x] EventTypeProofSubmitted
- [x] EventTypeRewardDelivered
- [x] EventTypeFollowed
- [x] EventTypeCommentReceived
- [x] EventTypePostReplied
- [x] EventTypePaymentConfirmed
- [x] EventTypeSecuritySignin
- [x] EventTypeSealReceived
- [x] EventTypeRankAdvanced
- [x] EventTypeDistrictLeader
- [x] EventTypeTop50
- [x] EventTypeSeasonOpened
- [x] EventTypeSeasonWarning
- [x] EventTypeSeasonResult

## Phase 3: Kafka Mappings
- [x] feed.task_accepted
- [x] feed.task_completed
- [x] feed.post_liked
- [x] map.proof_submitted
- [x] economy.reward_delivered
- [x] feed.followed
- [x] feed.comment_received
- [x] feed.post_replied
- [x] payment.confirmed
- [x] auth.security_signin
- [x] economy.seal_received
- [x] leaderboard.rank_advanced
- [x] leaderboard.district_leader
- [x] leaderboard.top_50
- [x] season.season_opened
- [x] season.season_warning
- [x] season.season_result
- [x] moderation.post_rejected

## Phase 4: HandleSystemEvent Handlers
- [x] case TypeTaskAccepted — notify task owner about new applications
- [x] case TypeTaskCompleted — notify task owner about completion
- [x] case TypeTaskAssigned — notify assignee about being chosen
- [x] case TypeProofSubmitted — notify task owner about proof
- [x] case TypeProofApproved — notify worker about approval
- [x] case TypeProofRejected — notify worker about rejection
- [x] case TypePostLiked — notify post author
- [x] case TypeCommentReceived — notify post author
- [x] case TypePostReplied — notify parent comment author
- [x] case TypePostRejected — notify about moderation rejection
- [x] case TypeFollowed — notify followed user
- [x] case TypeRewardDelivered — notify about reward
- [x] case TypePaymentConfirmed — notify about payment
- [x] case TypeSecuritySignin — notify about new login
- [x] case TypeSealReceived — notify about seal received
- [x] case TypeSeasonOpened — broadcast to all users

## Phase 5: Notification Preference Gating
- [x] isEventMuted helper — checks user prefs before creating notification
- [x] Gate all HandleSystemEvent cases through isEventMuted

## Phase 6: Personalized Push Text
- [x] resolveUsername — cross-module helper via repository
- [x] resolveTaskTitle — cross-module helper via repository
- [x] Personalized push for all notification types

## Phase 7: Event Producers (Emit → Kafka)
### Achievable (already wired or now wired)
- [x] TypeTaskApplied — map/service.go (SubmitApplication)
- [x] TypeTaskAccepted — map/service.go (AcceptApplication)
- [x] TypeTaskCompleted — map/service.go (MarkComplete)
- [x] TypeProofSubmitted — map/service.go (SubmitProof)
- [x] TypePostLiked — feed/service.go (ToggleLike)
- [x] TypeCommentReceived — feed/service.go (CreateComment, no parentID)
- [x] TypePostReplied — feed/service.go (CreateComment, has parentID)
- [x] TypeFollowed — feed/service.go (ToggleFollow)
- [x] TypePostRejected — feed/handler.go (Vision API flags content)
- [x] TypeRewardDelivered — economy/service.go (RewardForTaskCompletion)
- [x] TypeSealReceived — economy/service.go (TransferSeal)
- [x] TypeSecuritySignin — auth/service.go (new device / new IP)
- [x] TypeSeasonOpened — seasons/worker.go (start worker)
- [x] TypeSeasonWarning — seasons/worker.go (CloseWorker, ↓7 days remaining)
- [x] TypeSeasonResult — seasons/service.go (CloseDueSeasons)
- [x] TypeRankAdvanced — map/worker.go (fireChampionChange)
- [x] TypeDistrictLeader — map/worker.go (fireChampionChange)
- [x] TypeTop50 — map/worker.go (top50 sweep)
- [x] TypeTaskExpired — map/worker.go (auto-shutdown sweep)
- [x] TypePaymentConfirmed — payment/service.go (ProcessIAP)

### Not achievable (no module exists)
- [ ] TypeMedalIssued — no achievement/medal system
- [ ] TypeVerificationRequired — no verification workflow
- [ ] TypeProfileVerified — no verification workflow
