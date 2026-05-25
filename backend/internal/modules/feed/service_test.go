package feed

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/brightbund-backend/internal/platform/observability"
	"github.com/google/uuid"
)

type testRepo struct {
	createPostFn              func(ctx context.Context, post *Post, media []MediaAttachment, idempotencyKey, requestFingerprint string) error
	getPostByIdempotencyKeyFn func(ctx context.Context, userID uuid.UUID, idempotencyKey string) (*uuid.UUID, string, error)
	updatePostFn              func(ctx context.Context, postID, userID uuid.UUID, req *UpdatePostRequest) error
	deletePostFn              func(ctx context.Context, postID, userID uuid.UUID, isModerator bool) error
	getPostFn                 func(ctx context.Context, postID uuid.UUID, viewerID uuid.UUID) (*PostResponse, error)
	getUserPostsGridFn        func(ctx context.Context, authorID, viewerID uuid.UUID, cursor time.Time, limit int) ([]PostGridItem, string, error)
	getUserPostsListFn        func(ctx context.Context, authorID, viewerID uuid.UUID, cursor time.Time, limit int) ([]PostResponse, string, error)
	getPostCreatedAtFn        func(ctx context.Context, postID uuid.UUID) (time.Time, error)

	createReportFn          func(ctx context.Context, reporterID uuid.UUID, targetType string, targetID uuid.UUID, reason, description string) error
	countRecentReportsByFn  func(ctx context.Context, reporterID uuid.UUID, since time.Time) (int, error)
	countReportsForTargetFn func(ctx context.Context, targetType string, targetID uuid.UUID) (int, error)
	weightedReportsForPost  func(ctx context.Context, postID uuid.UUID) (float64, error)
	postImpressions         func(ctx context.Context, postID uuid.UUID) (int, error)
	setPostReportControl    func(ctx context.Context, postID uuid.UUID, level int, distributionMultiplier float64) error
	incrementImpressions    func(ctx context.Context, postIDs []uuid.UUID) error
	hideTargetByReportsFn   func(ctx context.Context, targetType string, targetID uuid.UUID) error
	hidePostForReporterFn   func(ctx context.Context, reporterID, postID uuid.UUID) error
	markReportsReviewedFn   func(ctx context.Context, targetType string, targetID uuid.UUID, decision string) ([]uuid.UUID, error)
	applyReputationDeltaFn  func(ctx context.Context, reporterIDs []uuid.UUID, accepted bool) error
	markReputationAppliedFn func(ctx context.Context, targetType string, targetID uuid.UUID) error
	createPolicyStrikeFn    func(ctx context.Context, targetType string, targetID uuid.UUID, expiresAt time.Time) error
	hardBlockAuthorFn       func(ctx context.Context, targetType string, targetID uuid.UUID) error
	isUserAdminFn           func(ctx context.Context, userID uuid.UUID) (bool, error)
	deleteCommentFn         func(ctx context.Context, commentID, actorID uuid.UUID, isModerator bool) error

	batchFlushLikesFn             func(ctx context.Context, postID uuid.UUID, userIDs []uuid.UUID) error
	batchFlushSealsFn             func(ctx context.Context, postID uuid.UUID, count int, totalAmount int64) error
	upsertFatigueStateFn          func(ctx context.Context, state *FeedFatigueState) error
	updateMediaProcessingResultFn func(ctx context.Context, mediaID uuid.UUID, url1080p, url480p, thumbnail, status string) error

	lastCreatedPost *Post
}

func (r *testRepo) GetFatigueState(ctx context.Context, userID uuid.UUID) (*FeedFatigueState, error) {
	return nil, errors.New("not implemented")
}

func (r *testRepo) UpsertFatigueState(ctx context.Context, state *FeedFatigueState) error {
	if r.upsertFatigueStateFn != nil {
		return r.upsertFatigueStateFn(ctx, state)
	}
	return nil
}

func (r *testRepo) CreatePost(ctx context.Context, post *Post, media []MediaAttachment, idempotencyKey, requestFingerprint string) error {
	r.lastCreatedPost = post
	if r.createPostFn != nil {
		return r.createPostFn(ctx, post, media, idempotencyKey, requestFingerprint)
	}
	return nil
}

func (r *testRepo) GetPostByIdempotencyKey(ctx context.Context, userID uuid.UUID, idempotencyKey string) (*uuid.UUID, string, error) {
	if r.getPostByIdempotencyKeyFn != nil {
		return r.getPostByIdempotencyKeyFn(ctx, userID, idempotencyKey)
	}
	return nil, "", nil
}

func (r *testRepo) UpdatePost(ctx context.Context, postID, userID uuid.UUID, req *UpdatePostRequest) error {
	if r.updatePostFn != nil {
		return r.updatePostFn(ctx, postID, userID, req)
	}
	return nil
}

func (r *testRepo) DeletePost(ctx context.Context, postID, userID uuid.UUID, isModerator bool) error {
	if r.deletePostFn != nil {
		return r.deletePostFn(ctx, postID, userID, isModerator)
	}
	return nil
}

func (r *testRepo) GetSmartFeed(ctx context.Context, viewerID uuid.UUID, lat, lon float64, hasLocation bool, cursor time.Time, limit int) ([]PostResponse, string, error) {
	return nil, "", nil
}

func (r *testRepo) GetPost(ctx context.Context, postID uuid.UUID, viewerID uuid.UUID) (*PostResponse, error) {
	if r.getPostFn != nil {
		return r.getPostFn(ctx, postID, viewerID)
	}
	return &PostResponse{PostID: postID}, nil
}

func (r *testRepo) GetUserPostsGrid(ctx context.Context, authorID, viewerID uuid.UUID, cursor time.Time, limit int) ([]PostGridItem, string, error) {
	if r.getUserPostsGridFn != nil {
		return r.getUserPostsGridFn(ctx, authorID, viewerID, cursor, limit)
	}
	return nil, "", nil
}

func (r *testRepo) GetUserPostsList(ctx context.Context, authorID, viewerID uuid.UUID, cursor time.Time, limit int) ([]PostResponse, string, error) {
	if r.getUserPostsListFn != nil {
		return r.getUserPostsListFn(ctx, authorID, viewerID, cursor, limit)
	}
	return nil, "", nil
}

func (r *testRepo) GetPostCreatedAt(ctx context.Context, postID uuid.UUID) (time.Time, error) {
	if r.getPostCreatedAtFn != nil {
		return r.getPostCreatedAtFn(ctx, postID)
	}
	return time.Now(), nil
}

func (r *testRepo) CreateComment(ctx context.Context, comment *PostComment) error { return nil }

func (r *testRepo) GetComment(ctx context.Context, commentID uuid.UUID, viewerID uuid.UUID) (*CommentResponse, error) {
	return nil, nil
}

func (r *testRepo) GetCommentThreadParent(ctx context.Context, commentID uuid.UUID) (*CommentThreadParent, error) {
	return nil, nil
}

func (r *testRepo) GetThreadedComments(ctx context.Context, postID uuid.UUID, viewerID uuid.UUID, parentID *uuid.UUID, cursor string, limit int) ([]CommentResponse, string, error) {
	return nil, "", nil
}

func (r *testRepo) GetPostPermissionsInfo(ctx context.Context, postID uuid.UUID) (string, uuid.UUID, error) {
	return CommentPermAnyone, uuid.New(), nil
}

func (r *testRepo) ToggleCommentLike(ctx context.Context, commentID uuid.UUID, userID uuid.UUID) error {
	return nil
}

func (r *testRepo) DeleteComment(ctx context.Context, commentID, actorID uuid.UUID, isModerator bool) error {
	if r.deleteCommentFn != nil {
		return r.deleteCommentFn(ctx, commentID, actorID, isModerator)
	}
	return nil
}

func (r *testRepo) CreateReport(ctx context.Context, reporterID uuid.UUID, targetType string, targetID uuid.UUID, reason, description string) error {
	if r.createReportFn != nil {
		return r.createReportFn(ctx, reporterID, targetType, targetID, reason, description)
	}
	return nil
}

func (r *testRepo) HidePostForReporter(ctx context.Context, reporterID, postID uuid.UUID) error {
	if r.hidePostForReporterFn != nil {
		return r.hidePostForReporterFn(ctx, reporterID, postID)
	}
	return nil
}

func (r *testRepo) CountRecentReportsByUser(ctx context.Context, reporterID uuid.UUID, since time.Time) (int, error) {
	if r.countRecentReportsByFn != nil {
		return r.countRecentReportsByFn(ctx, reporterID, since)
	}
	return 0, nil
}

func (r *testRepo) CountReportsForTarget(ctx context.Context, targetType string, targetID uuid.UUID) (int, error) {
	if r.countReportsForTargetFn != nil {
		return r.countReportsForTargetFn(ctx, targetType, targetID)
	}
	return 0, nil
}

func (r *testRepo) GetWeightedReportsForPost(ctx context.Context, postID uuid.UUID) (float64, error) {
	if r.weightedReportsForPost != nil {
		return r.weightedReportsForPost(ctx, postID)
	}
	return 0, nil
}

func (r *testRepo) GetPostImpressions(ctx context.Context, postID uuid.UUID) (int, error) {
	if r.postImpressions != nil {
		return r.postImpressions(ctx, postID)
	}
	return 0, nil
}

func (r *testRepo) SetPostReportControl(ctx context.Context, postID uuid.UUID, level int, distributionMultiplier float64) error {
	if r.setPostReportControl != nil {
		return r.setPostReportControl(ctx, postID, level, distributionMultiplier)
	}
	return nil
}

func (r *testRepo) IncrementPostImpressions(ctx context.Context, postIDs []uuid.UUID) error {
	if r.incrementImpressions != nil {
		return r.incrementImpressions(ctx, postIDs)
	}
	return nil
}

func (r *testRepo) MarkReportsReviewed(ctx context.Context, targetType string, targetID uuid.UUID, decision string) ([]uuid.UUID, error) {
	if r.markReportsReviewedFn != nil {
		return r.markReportsReviewedFn(ctx, targetType, targetID, decision)
	}
	return nil, nil
}

func (r *testRepo) ApplyReporterReputationDelta(ctx context.Context, reporterIDs []uuid.UUID, accepted bool) error {
	if r.applyReputationDeltaFn != nil {
		return r.applyReputationDeltaFn(ctx, reporterIDs, accepted)
	}
	return nil
}

func (r *testRepo) MarkReportReputationApplied(ctx context.Context, targetType string, targetID uuid.UUID) error {
	if r.markReputationAppliedFn != nil {
		return r.markReputationAppliedFn(ctx, targetType, targetID)
	}
	return nil
}

func (r *testRepo) CreateAuthorPolicyStrikeForTarget(ctx context.Context, targetType string, targetID uuid.UUID, expiresAt time.Time) error {
	if r.createPolicyStrikeFn != nil {
		return r.createPolicyStrikeFn(ctx, targetType, targetID, expiresAt)
	}
	return nil
}

func (r *testRepo) HideTargetByReports(ctx context.Context, targetType string, targetID uuid.UUID) error {
	if r.hideTargetByReportsFn != nil {
		return r.hideTargetByReportsFn(ctx, targetType, targetID)
	}
	return nil
}

func (r *testRepo) HardBlockAuthorByTarget(ctx context.Context, targetType string, targetID uuid.UUID) error {
	if r.hardBlockAuthorFn != nil {
		return r.hardBlockAuthorFn(ctx, targetType, targetID)
	}
	return nil
}

func (r *testRepo) ToggleLike(ctx context.Context, postID uuid.UUID, userID uuid.UUID) error {
	return nil
}

func (r *testRepo) IsUserAdmin(ctx context.Context, userID uuid.UUID) (bool, error) {
	if r.isUserAdminFn != nil {
		return r.isUserAdminFn(ctx, userID)
	}
	return false, nil
}

func (r *testRepo) GetPostAuthorID(ctx context.Context, postID uuid.UUID) (uuid.UUID, error) {
	return uuid.Nil, nil
}

func (r *testRepo) GetCommentAuthorID(ctx context.Context, commentID uuid.UUID) (uuid.UUID, error) {
	return uuid.Nil, nil
}

func (r *testRepo) GetOrCreateReportCooldown(ctx context.Context, reporterID, targetUserID uuid.UUID) (*ReportCooldown, error) {
	return &ReportCooldown{ReporterID: reporterID, TargetUserID: targetUserID, CooldownUntil: time.Now()}, nil
}

func (r *testRepo) UpdateReportCooldown(ctx context.Context, cooldown *ReportCooldown) error {
	return nil
}

func (r *testRepo) LogMediaAbuse(ctx context.Context, userID uuid.UUID, violationType, detectionDetails string, metadata interface{}) error {
	return nil
}

func (r *testRepo) SearchPosts(ctx context.Context, query string, limit, offset int) ([]PostResponse, int, error) {
	return nil, 0, nil
}

func (r *testRepo) ListReports(ctx context.Context, status, targetType, reason string, limit, offset int) ([]ReportItem, int, error) {
	return nil, 0, nil
}

func (r *testRepo) IsAlly(ctx context.Context, userID, targetUserID uuid.UUID) (bool, error) {
	return false, nil
}

func (r *testRepo) GetInteractions(ctx context.Context, postID uuid.UUID, interactionType string, cursor string, limit int) ([]InteractionResponse, string, error) {
	return nil, "", nil
}

func (r *testRepo) GetSeals(ctx context.Context, postID uuid.UUID, cursor string, limit int) ([]SealResponse, string, error) {
	return nil, "", nil
}

func (r *testRepo) UpdateMediaProcessingResult(ctx context.Context, mediaID uuid.UUID, url1080p, url480p, thumbURL, status string) error {
	if r.updateMediaProcessingResultFn != nil {
		return r.updateMediaProcessingResultFn(ctx, mediaID, url1080p, url480p, thumbURL, status)
	}
	return nil
}

func (r *testRepo) BatchFlushLikes(ctx context.Context, postID uuid.UUID, userIDs []uuid.UUID) error {
	if r.batchFlushLikesFn != nil {
		return r.batchFlushLikesFn(ctx, postID, userIDs)
	}
	return nil
}

func (r *testRepo) BatchFlushSeals(ctx context.Context, postID uuid.UUID, count int, totalAmount int64) error {
	if r.batchFlushSealsFn != nil {
		return r.batchFlushSealsFn(ctx, postID, count, totalAmount)
	}
	return nil
}

type testCacheRepo struct {
	anyOnFeed    bool
	fatigueState *FeedFatigueState
	lastSetState *FeedFatigueState
	dirtyUsers   []uuid.UUID
}

func (t *testCacheRepo) GetFatigueState(ctx context.Context, userID uuid.UUID) (*FeedFatigueState, error) {
	if t.fatigueState == nil {
		return nil, errors.New("cache miss")
	}
	return t.fatigueState, nil
}

func (t *testCacheRepo) SetFatigueState(ctx context.Context, state *FeedFatigueState) error {
	t.lastSetState = state
	t.fatigueState = state
	return nil
}

func (t *testCacheRepo) MarkUserDirty(ctx context.Context, userID uuid.UUID) error {
	t.dirtyUsers = append(t.dirtyUsers, userID)
	return nil
}

func (t *testCacheRepo) MarkDeviceOnFeed(ctx context.Context, userID uuid.UUID, deviceID string, ttl time.Duration) error {
	return nil
}

func (t *testCacheRepo) AnyDeviceOnFeed(ctx context.Context, userID uuid.UUID) (bool, error) {
	return t.anyOnFeed, nil
}

func newTestService(anyOnFeed bool) *Service {
	return &Service{cache: &testCacheRepo{anyOnFeed: anyOnFeed}}
}

func TestApplyStateTransitions_ActivePhase_ResetAfterLongAway(t *testing.T) {
	svc := newTestService(false)
	now := time.Now()

	state := &FeedFatigueState{
		UserID:                   uuid.New(),
		AccumulatedActiveSeconds: 900,
		LastSyncTimestamp:        now.Add(-301 * time.Second),
		IsInCooldown:             false,
	}

	result := svc.applyStateTransitions(state, now, false, true)

	if result.AccumulatedActiveSeconds != 0 {
		t.Errorf("expected full reset to 0, got %d", result.AccumulatedActiveSeconds)
	}
	if result.IsInCooldown {
		t.Error("expected IsInCooldown=false after reset")
	}
}

func TestApplyStateTransitions_BreakPhase_SyncFreezesAndRefreshesLastSync(t *testing.T) {
	svc := newTestService(true)
	now := time.Now()
	prev := now.Add(-10 * time.Second)

	state := &FeedFatigueState{
		UserID:                   uuid.New(),
		AccumulatedActiveSeconds: 1200,
		AccumulatedBreakSeconds:  120,
		LastSyncTimestamp:        prev,
		IsInCooldown:             true,
	}

	result := svc.applyStateTransitions(state, now, true, false)

	if result.AccumulatedBreakSeconds != 120 {
		t.Errorf("expected break seconds to stay frozen, got %d", result.AccumulatedBreakSeconds)
	}
	if !result.LastSyncTimestamp.Equal(now) {
		t.Error("expected LastSyncTimestamp to be refreshed during sync")
	}
}

func TestApplyStateTransitions_BreakPhase_TracksElapsedFromBreakStartAt(t *testing.T) {
	svc := newTestService(false)
	now := time.Now()
	breakStart := now.Add(-150 * time.Second)

	state := &FeedFatigueState{
		UserID:                   uuid.New(),
		AccumulatedActiveSeconds: 1200,
		AccumulatedBreakSeconds:  100,
		LastSyncTimestamp:        now.Add(-50 * time.Second),
		IsInCooldown:             true,
		BreakStartedAt:           &breakStart,
	}

	result := svc.applyStateTransitions(state, now, false, true)

	if result.AccumulatedBreakSeconds != 150 {
		t.Errorf("expected break seconds to reflect wall-clock elapsed (150), got %d", result.AccumulatedBreakSeconds)
	}
	if result.IsInCooldown != true {
		t.Error("expected cooldown to continue")
	}
}

func TestApplyStateTransitions_BreakPhase_SyncPausesBreakWhenOnFeed(t *testing.T) {
	svc := newTestService(true)
	now := time.Now()
	breakStart := now.Add(-140 * time.Second)

	state := &FeedFatigueState{
		UserID:                   uuid.New(),
		AccumulatedActiveSeconds: 1200,
		AccumulatedBreakSeconds:  100,
		LastSyncTimestamp:        now.Add(-50 * time.Second),
		IsInCooldown:             true,
		BreakStartedAt:           &breakStart,
	}

	result := svc.applyStateTransitions(state, now, true, false)

	if result.AccumulatedBreakSeconds != 100 {
		t.Errorf("expected break seconds to stay frozen during on-feed sync, got %d", result.AccumulatedBreakSeconds)
	}
	if !result.LastSyncTimestamp.Equal(now) {
		t.Error("expected LastSyncTimestamp to move to now during sync")
	}
}

func TestApplyStateTransitions_BreakPhase_ResolvesAfterEnoughOffFeed(t *testing.T) {
	svc := newTestService(false)
	now := time.Now()
	breakStart := now.Add(-600 * time.Second)

	state := &FeedFatigueState{
		UserID:                   uuid.New(),
		AccumulatedActiveSeconds: 1200,
		AccumulatedBreakSeconds:  260,
		LastSyncTimestamp:        now.Add(-45 * time.Second),
		IsInCooldown:             true,
		BreakStartedAt:           &breakStart,
	}

	result := svc.applyStateTransitions(state, now, false, true)

	if result.IsInCooldown {
		t.Error("expected cooldown resolved")
	}
	if result.AccumulatedActiveSeconds != 0 {
		t.Errorf("expected active seconds reset to 0, got %d", result.AccumulatedActiveSeconds)
	}
	if result.AccumulatedBreakSeconds != 0 {
		t.Errorf("expected break seconds reset to 0, got %d", result.AccumulatedBreakSeconds)
	}
	if result.BreakStartedAt != nil {
		t.Error("expected BreakStartedAt nil after reset")
	}
}

func TestCalcBreakSecondsRemaining_MidBreak(t *testing.T) {
	svc := newTestService(false)
	state := &FeedFatigueState{IsInCooldown: true, AccumulatedBreakSeconds: 120}
	now := time.Now()

	rem := svc.calcBreakSecondsRemaining(state, now, false)
	if rem != 180 {
		t.Errorf("expected 180, got %d", rem)
	}
}

func TestCalcBreakSecondsRemaining_UsesBreakStartedAt(t *testing.T) {
	svc := newTestService(false)
	now := time.Now()
	breakStart := now.Add(-200 * time.Second)
	state := &FeedFatigueState{IsInCooldown: true, BreakStartedAt: &breakStart, AccumulatedBreakSeconds: 5}

	rem := svc.calcBreakSecondsRemaining(state, now, true)
	if rem != 100 {
		t.Errorf("expected 100 seconds remaining from break_start_at, got %d", rem)
	}
}

func TestGetFeedState_CooldownRequiresEnforceCooldownAction(t *testing.T) {
	userID := uuid.New()
	cacheRepo := &testCacheRepo{
		fatigueState: &FeedFatigueState{
			UserID:                   userID,
			AccumulatedActiveSeconds: 1200,
			AccumulatedBreakSeconds:  120,
			LastSyncTimestamp:        time.Now().Add(-10 * time.Second),
			IsInCooldown:             true,
			MaxAllowedSeconds:        1200,
		},
	}
	svc := &Service{cache: cacheRepo}

	resp, err := svc.GetFeedState(context.Background(), userID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !resp.IsInCooldown {
		t.Fatal("expected cooldown state")
	}
	if resp.ActionRequired != "enforce_cooldown" {
		t.Fatalf("expected action_required=enforce_cooldown, got %q", resp.ActionRequired)
	}
	if resp.BreakSecondsRemaining <= 0 || resp.BreakSecondsRemaining >= BreakDurationSeconds {
		t.Fatalf("expected remaining break to stay within cooldown bounds, got %d", resp.BreakSecondsRemaining)
	}
	if len(cacheRepo.dirtyUsers) != 1 || cacheRepo.dirtyUsers[0] != userID {
		t.Fatal("expected user to be marked dirty for persistence")
	}
}

func TestSyncFeedState_ThresholdCrossingTriggersFriction(t *testing.T) {
	userID := uuid.New()
	now := time.Now()
	cacheRepo := &testCacheRepo{
		fatigueState: &FeedFatigueState{
			UserID:                   userID,
			AccumulatedActiveSeconds: 1195,
			LastSyncTimestamp:        now.Add(-10 * time.Second),
			IsInCooldown:             false,
			MaxAllowedSeconds:        1200,
		},
	}
	svc := &Service{cache: cacheRepo}

	resp, err := svc.SyncFeedState(context.Background(), userID, &SyncFeedStateRequest{
		DeltaSeconds: 5,
		DeviceID:     "device-a",
	}, true)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !resp.IsInCooldown {
		t.Fatal("expected cooldown after reaching the limit")
	}
	if resp.ActionRequired != "trigger_friction" {
		t.Fatalf("expected action_required=trigger_friction, got %q", resp.ActionRequired)
	}
	if resp.BreakSecondsRemaining != BreakDurationSeconds {
		t.Fatalf("expected full break duration remaining, got %d", resp.BreakSecondsRemaining)
	}
	if cacheRepo.lastSetState == nil || !cacheRepo.lastSetState.IsInCooldown {
		t.Fatal("expected cached state to be persisted in cooldown")
	}
}

func TestSyncFeedState_DuringCooldownEnforcesCooldownAction(t *testing.T) {
	userID := uuid.New()
	now := time.Now()
	breakStart := now.Add(-40 * time.Second)
	cacheRepo := &testCacheRepo{
		fatigueState: &FeedFatigueState{
			UserID:                   userID,
			AccumulatedActiveSeconds: 1200,
			AccumulatedBreakSeconds:  40,
			LastSyncTimestamp:        now.Add(-15 * time.Second),
			IsInCooldown:             true,
			BreakStartedAt:           &breakStart,
			MaxAllowedSeconds:        1200,
		},
	}
	svc := &Service{cache: cacheRepo}

	resp, err := svc.SyncFeedState(context.Background(), userID, &SyncFeedStateRequest{
		DeltaSeconds: 5,
		DeviceID:     "device-b",
	}, true)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.ActionRequired != "enforce_cooldown" {
		t.Fatalf("expected action_required=enforce_cooldown, got %q", resp.ActionRequired)
	}
	if resp.BreakSecondsRemaining != BreakDurationSeconds-40 {
		t.Fatalf("expected %d break seconds remaining, got %d", BreakDurationSeconds-40, resp.BreakSecondsRemaining)
	}
}

func TestGetUserPostsGrid_UsesDefaultAndMaxLimitRules(t *testing.T) {
	authorID := uuid.New()
	viewerID := uuid.New()

	var seenLimit int
	repo := &testRepo{
		getUserPostsGridFn: func(ctx context.Context, aID, vID uuid.UUID, cursor time.Time, limit int) ([]PostGridItem, string, error) {
			seenLimit = limit
			if aID != authorID || vID != viewerID {
				t.Fatalf("unexpected author/viewer ids: %s %s", aID, vID)
			}
			return []PostGridItem{}, "", nil
		},
	}
	svc := &Service{repo: repo, cache: &testCacheRepo{}}

	if _, err := svc.GetUserPostsGrid(context.Background(), authorID, viewerID, "", 0); err != nil {
		t.Fatalf("unexpected error for default limit case: %v", err)
	}
	if seenLimit != 18 {
		t.Fatalf("expected default grid limit=18, got %d", seenLimit)
	}

	if _, err := svc.GetUserPostsGrid(context.Background(), authorID, viewerID, "", 99); err != nil {
		t.Fatalf("unexpected error for max limit case: %v", err)
	}
	if seenLimit != 30 {
		t.Fatalf("expected clamped grid limit=30, got %d", seenLimit)
	}
}

func TestGetUserPostsList_UsesDefaultAndMaxLimitRules(t *testing.T) {
	authorID := uuid.New()
	viewerID := uuid.New()

	var seenLimit int
	repo := &testRepo{
		getUserPostsListFn: func(ctx context.Context, aID, vID uuid.UUID, cursor time.Time, limit int) ([]PostResponse, string, error) {
			seenLimit = limit
			if aID != authorID || vID != viewerID {
				t.Fatalf("unexpected author/viewer ids: %s %s", aID, vID)
			}
			return []PostResponse{}, "", nil
		},
	}
	svc := &Service{repo: repo, cache: &testCacheRepo{}}

	if _, err := svc.GetUserPostsList(context.Background(), authorID, viewerID, nil, "", 0); err != nil {
		t.Fatalf("unexpected error for default limit case: %v", err)
	}
	if seenLimit != 10 {
		t.Fatalf("expected default list limit=10, got %d", seenLimit)
	}

	if _, err := svc.GetUserPostsList(context.Background(), authorID, viewerID, nil, "", 99); err != nil {
		t.Fatalf("unexpected error for max limit case: %v", err)
	}
	if seenLimit != 30 {
		t.Fatalf("expected clamped list limit=30, got %d", seenLimit)
	}
}

func TestGetUserPostsList_AnchorPostUsesCreatedAtPlusMicrosecond(t *testing.T) {
	authorID := uuid.New()
	viewerID := uuid.New()
	anchorID := uuid.New()
	anchorTime := time.Now().Add(-3 * time.Hour)

	var seenCursor time.Time
	repo := &testRepo{
		getPostCreatedAtFn: func(ctx context.Context, postID uuid.UUID) (time.Time, error) {
			if postID != anchorID {
				t.Fatalf("unexpected anchor id: %s", postID)
			}
			return anchorTime, nil
		},
		getUserPostsListFn: func(ctx context.Context, aID, vID uuid.UUID, cursor time.Time, limit int) ([]PostResponse, string, error) {
			seenCursor = cursor
			return []PostResponse{}, "", nil
		},
	}
	svc := &Service{repo: repo, cache: &testCacheRepo{}}

	if _, err := svc.GetUserPostsList(context.Background(), authorID, viewerID, &anchorID, "", 10); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	expected := anchorTime.Add(time.Microsecond)
	if !seenCursor.Equal(expected) {
		t.Fatalf("expected cursor %s, got %s", expected.Format(time.RFC3339Nano), seenCursor.Format(time.RFC3339Nano))
	}
}

func TestGetUserPostsList_AnchorLookupFailureFallsBackToCursor(t *testing.T) {
	authorID := uuid.New()
	viewerID := uuid.New()
	anchorID := uuid.New()
	fallbackCursor := time.Now().Add(-90 * time.Minute).UTC().Format(time.RFC3339Nano)

	var seenCursor time.Time
	repo := &testRepo{
		getPostCreatedAtFn: func(ctx context.Context, postID uuid.UUID) (time.Time, error) {
			return time.Time{}, errors.New("anchor not found")
		},
		getUserPostsListFn: func(ctx context.Context, aID, vID uuid.UUID, cursor time.Time, limit int) ([]PostResponse, string, error) {
			seenCursor = cursor
			return []PostResponse{}, "", nil
		},
	}
	svc := &Service{repo: repo, cache: &testCacheRepo{}}

	if _, err := svc.GetUserPostsList(context.Background(), authorID, viewerID, &anchorID, fallbackCursor, 10); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	expected, _ := time.Parse(time.RFC3339Nano, fallbackCursor)
	if !seenCursor.Equal(expected) {
		t.Fatalf("expected fallback cursor %s, got %s", expected.Format(time.RFC3339Nano), seenCursor.Format(time.RFC3339Nano))
	}
}

func TestUpdatePost_EmptyPayloadReturnsError(t *testing.T) {
	repo := &testRepo{}
	svc := &Service{repo: repo, cache: &testCacheRepo{}}

	_, err := svc.UpdatePost(context.Background(), uuid.New(), uuid.New(), &UpdatePostRequest{})
	if !errors.Is(err, ErrInvalidPostUpdate) {
		t.Fatalf("expected ErrInvalidPostUpdate, got %v", err)
	}
}

func TestUpdatePost_InvalidCommentPermissionReturnsError(t *testing.T) {
	repo := &testRepo{}
	svc := &Service{repo: repo, cache: &testCacheRepo{}}
	perm := "INVALID"

	_, err := svc.UpdatePost(context.Background(), uuid.New(), uuid.New(), &UpdatePostRequest{CommentPermission: &perm})
	if !errors.Is(err, ErrInvalidCommentPermission) {
		t.Fatalf("expected ErrInvalidCommentPermission, got %v", err)
	}
}

func TestUpdatePost_SuccessTrimsPermissionAndReturnsPost(t *testing.T) {
	userID := uuid.New()
	postID := uuid.New()
	perm := "  NO_ONE  "

	repo := &testRepo{
		updatePostFn: func(ctx context.Context, gotPostID, gotUserID uuid.UUID, req *UpdatePostRequest) error {
			if gotPostID != postID {
				t.Fatalf("unexpected post id: %s", gotPostID)
			}
			if gotUserID != userID {
				t.Fatalf("unexpected user id: %s", gotUserID)
			}
			if req.CommentPermission == nil || *req.CommentPermission != CommentPermNoOne {
				t.Fatalf("expected trimmed comment permission %q, got %+v", CommentPermNoOne, req.CommentPermission)
			}
			return nil
		},
		getPostFn: func(ctx context.Context, gotPostID uuid.UUID, viewerID uuid.UUID) (*PostResponse, error) {
			if gotPostID != postID || viewerID != userID {
				t.Fatalf("unexpected get post args: %s %s", gotPostID, viewerID)
			}
			return &PostResponse{PostID: postID}, nil
		},
	}
	svc := &Service{repo: repo, cache: &testCacheRepo{}}

	resp, err := svc.UpdatePost(context.Background(), userID, postID, &UpdatePostRequest{CommentPermission: &perm})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.PostID != postID {
		t.Fatalf("expected post id %s, got %s", postID, resp.PostID)
	}
}

func TestDeletePost_DelegatesRepository(t *testing.T) {
	userID := uuid.New()
	postID := uuid.New()
	called := false

	repo := &testRepo{
		deletePostFn: func(ctx context.Context, gotPostID, gotUserID uuid.UUID, isModerator bool) error {
			called = true
			if gotPostID != postID || gotUserID != userID {
				t.Fatalf("unexpected delete args: %s %s", gotPostID, gotUserID)
			}
			return nil
		},
	}
	svc := &Service{repo: repo, cache: &testCacheRepo{}}

	if err := svc.DeletePost(context.Background(), userID, postID); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !called {
		t.Fatal("expected delete repository method to be called")
	}
}

func TestCreatePost_PassesHideLikesCountToRepository(t *testing.T) {
	userID := uuid.New()
	repo := &testRepo{
		getPostFn: func(ctx context.Context, postID uuid.UUID, viewerID uuid.UUID) (*PostResponse, error) {
			return &PostResponse{PostID: postID, HideLikesCount: true}, nil
		},
	}
	svc := &Service{repo: repo, cache: &testCacheRepo{}}

	resp, err := svc.CreatePost(context.Background(), userID, &CreatePostRequest{
		Caption:           "hello",
		Visibility:        VisibilityAnyone,
		CommentPermission: CommentPermAnyone,
		HideLikesCount:    true,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if repo.lastCreatedPost == nil {
		t.Fatal("expected repository CreatePost to be called")
	}
	if !repo.lastCreatedPost.HideLikesCount {
		t.Fatal("expected hide_likes_count to be persisted on post model")
	}
	if !resp.HideLikesCount {
		t.Fatal("expected response hide_likes_count=true")
	}
}

func TestCreatePost_RejectsTooManyVideos(t *testing.T) {
	userID := uuid.New()
	media := make([]MediaAttachment, 0, 5)
	for i := 0; i < 5; i++ {
		media = append(media, MediaAttachment{
			Type:            "video",
			URL_1080p:       "https://cdn.example.com/v.mp4",
			DurationSeconds: 10,
		})
	}

	svc := &Service{repo: &testRepo{}, cache: &testCacheRepo{}}
	_, err := svc.CreatePost(context.Background(), userID, &CreatePostRequest{
		Caption:           "hello",
		Visibility:        VisibilityAnyone,
		CommentPermission: CommentPermAnyone,
		MediaAttachments:  media,
	})
	if !errors.Is(err, ErrTooManyVideoAttachments) {
		t.Fatalf("expected ErrTooManyVideoAttachments, got %v", err)
	}
}

func TestCreatePost_RejectsUnsupportedMediaType(t *testing.T) {
	userID := uuid.New()
	svc := &Service{repo: &testRepo{}, cache: &testCacheRepo{}}

	_, err := svc.CreatePost(context.Background(), userID, &CreatePostRequest{
		Caption:           "hello",
		Visibility:        VisibilityAnyone,
		CommentPermission: CommentPermAnyone,
		MediaAttachments: []MediaAttachment{
			{Type: "gif", URL_1080p: "https://cdn.example.com/a.gif"},
		},
	})
	if !errors.Is(err, ErrUnsupportedMediaType) {
		t.Fatalf("expected ErrUnsupportedMediaType, got %v", err)
	}
}

func TestCreatePost_RejectsMissingMediaURL(t *testing.T) {
	userID := uuid.New()
	svc := &Service{repo: &testRepo{}, cache: &testCacheRepo{}}

	_, err := svc.CreatePost(context.Background(), userID, &CreatePostRequest{
		Caption:           "hello",
		Visibility:        VisibilityAnyone,
		CommentPermission: CommentPermAnyone,
		MediaAttachments: []MediaAttachment{
			{Type: "image"},
		},
	})
	if !errors.Is(err, ErrMediaURLRequired) {
		t.Fatalf("expected ErrMediaURLRequired, got %v", err)
	}
}

func TestCreatePost_TracksObservabilityOnRepositoryFailure(t *testing.T) {
	observability.ResetForTests()
	userID := uuid.New()
	repo := &testRepo{
		createPostFn: func(ctx context.Context, post *Post, media []MediaAttachment, idempotencyKey, requestFingerprint string) error {
			return errors.New("db down")
		},
	}
	svc := &Service{repo: repo, cache: &testCacheRepo{}}

	_, err := svc.CreatePost(context.Background(), userID, &CreatePostRequest{
		Caption:           "hello",
		Visibility:        VisibilityAnyone,
		CommentPermission: CommentPermAnyone,
		MediaAttachments: []MediaAttachment{
			{Type: "image", URL_1080p: "https://cdn.example.com/i.jpg"},
		},
	})
	if err == nil {
		t.Fatal("expected repository failure")
	}

	snap := observability.Snapshot()
	if snap.PostPublishAttempts != 1 || snap.PostPublishFailures != 1 {
		t.Fatalf("unexpected post publish metrics: attempts=%d failures=%d", snap.PostPublishAttempts, snap.PostPublishFailures)
	}
	found := false
	for _, rec := range snap.MediaPersistFailures {
		if rec.Key == "create_post_repo" && rec.Count == 1 {
			found = true
		}
	}
	if !found {
		t.Fatalf("expected create_post_repo media persist failure metric, got %+v", snap.MediaPersistFailures)
	}
}

func TestCreatePost_InvalidIdempotencyKey(t *testing.T) {
	userID := uuid.New()
	svc := &Service{repo: &testRepo{}, cache: &testCacheRepo{}}

	_, err := svc.CreatePost(context.Background(), userID, &CreatePostRequest{
		Caption:           "hello",
		IdempotencyKey:    "bad key with spaces",
		Visibility:        VisibilityAnyone,
		CommentPermission: CommentPermAnyone,
		MediaAttachments: []MediaAttachment{
			{Type: "image", URL_1080p: "https://cdn.example.com/img.jpg"},
		},
	})
	if !errors.Is(err, ErrInvalidIdempotencyKey) {
		t.Fatalf("expected ErrInvalidIdempotencyKey, got %v", err)
	}
}

func TestCreatePost_IdempotencyReplayReturnsExistingPost(t *testing.T) {
	userID := uuid.New()
	postID := uuid.New()
	repo := &testRepo{
		getPostByIdempotencyKeyFn: func(ctx context.Context, gotUserID uuid.UUID, key string) (*uuid.UUID, string, error) {
			if gotUserID != userID || key != "idem-key-1234" {
				t.Fatalf("unexpected idempotency lookup args: %s %s", gotUserID, key)
			}
			return &postID, postRequestFingerprint(&CreatePostRequest{
				Caption:           "hello",
				Visibility:        VisibilityAnyone,
				CommentPermission: CommentPermAnyone,
				MediaAttachments: []MediaAttachment{
					{Type: "image", URL_1080p: "https://cdn.example.com/img.jpg"},
				},
			}), nil
		},
		getPostFn: func(ctx context.Context, gotPostID uuid.UUID, viewerID uuid.UUID) (*PostResponse, error) {
			if gotPostID != postID || viewerID != userID {
				t.Fatalf("unexpected GetPost args: %s %s", gotPostID, viewerID)
			}
			return &PostResponse{PostID: postID}, nil
		},
	}
	svc := &Service{repo: repo, cache: &testCacheRepo{}}

	resp, err := svc.CreatePost(context.Background(), userID, &CreatePostRequest{
		Caption:           "hello",
		IdempotencyKey:    "idem-key-1234",
		Visibility:        VisibilityAnyone,
		CommentPermission: CommentPermAnyone,
		MediaAttachments: []MediaAttachment{
			{Type: "image", URL_1080p: "https://cdn.example.com/img.jpg"},
		},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.PostID != postID {
		t.Fatalf("expected replayed post id %s, got %s", postID, resp.PostID)
	}
}

func TestReportPost_HidesPostForReporterOnSuccess(t *testing.T) {
	reporterID := uuid.New()
	postID := uuid.New()
	hideCalled := false

	repo := &testRepo{
		hidePostForReporterFn: func(ctx context.Context, gotReporterID, gotPostID uuid.UUID) error {
			hideCalled = true
			if gotReporterID != reporterID || gotPostID != postID {
				t.Fatalf("unexpected hide args: %s %s", gotReporterID, gotPostID)
			}
			return nil
		},
	}
	svc := &Service{repo: repo, cache: &testCacheRepo{}}

	if err := svc.ReportPost(context.Background(), reporterID, postID, ReportReasonSpam, ""); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !hideCalled {
		t.Fatal("expected post to be hidden for reporter after successful report")
	}
}

func TestReportPost_HidesPostForReporterOnDuplicateReport(t *testing.T) {
	reporterID := uuid.New()
	postID := uuid.New()
	hideCalled := false

	repo := &testRepo{
		createReportFn: func(ctx context.Context, reporterID uuid.UUID, targetType string, targetID uuid.UUID, reason, description string) error {
			return errors.New("duplicate key value violates unique constraint uq_reports_reporter_target")
		},
		hidePostForReporterFn: func(ctx context.Context, gotReporterID, gotPostID uuid.UUID) error {
			hideCalled = true
			if gotReporterID != reporterID || gotPostID != postID {
				t.Fatalf("unexpected hide args: %s %s", gotReporterID, gotPostID)
			}
			return nil
		},
	}
	svc := &Service{repo: repo, cache: &testCacheRepo{}}

	err := svc.ReportPost(context.Background(), reporterID, postID, ReportReasonSpam, "")
	if !errors.Is(err, ErrDuplicateReport) {
		t.Fatalf("expected ErrDuplicateReport, got %v", err)
	}
	if !hideCalled {
		t.Fatal("expected post to remain hidden for reporter on duplicate report")
	}
}

func TestReportComment_DoesNotHidePostForReporter(t *testing.T) {
	reporterID := uuid.New()
	commentID := uuid.New()
	hideCalled := false

	repo := &testRepo{
		hidePostForReporterFn: func(ctx context.Context, gotReporterID, gotPostID uuid.UUID) error {
			hideCalled = true
			return nil
		},
	}
	svc := &Service{repo: repo, cache: &testCacheRepo{}}

	if err := svc.ReportComment(context.Background(), reporterID, commentID, ReportReasonSpam, ""); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if hideCalled {
		t.Fatal("did not expect HidePostForReporter for comment reports")
	}
}

func TestDeterminePostReportLevel_RequiresMinimumImpressions(t *testing.T) {
	level := determinePostReportLevel(25, 49)
	if level != 0 {
		t.Fatalf("expected level 0 before activation threshold, got %d", level)
	}
}

func TestDeterminePostReportLevel_UsesWeightedAndRatioThresholds(t *testing.T) {
	tests := []struct {
		name          string
		weighted      float64
		impressions   int
		expectedLevel int
	}{
		{name: "level1 by weighted", weighted: 3.1, impressions: 100, expectedLevel: 1},
		{name: "level2 by ratio", weighted: 6, impressions: 100, expectedLevel: 2},
		{name: "level3 by weighted", weighted: 11, impressions: 400, expectedLevel: 3},
		{name: "level4 by ratio", weighted: 13, impressions: 100, expectedLevel: 4},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			level := determinePostReportLevel(tt.weighted, tt.impressions)
			if level != tt.expectedLevel {
				t.Fatalf("expected level %d, got %d", tt.expectedLevel, level)
			}
		})
	}
}

func TestReportPost_AppliesPolicyForPostReports(t *testing.T) {
	reporterID := uuid.New()
	postID := uuid.New()
	applied := false

	repo := &testRepo{
		postImpressions: func(ctx context.Context, gotPostID uuid.UUID) (int, error) {
			if gotPostID != postID {
				t.Fatalf("unexpected post id for impressions: %s", gotPostID)
			}
			return 200, nil
		},
		weightedReportsForPost: func(ctx context.Context, gotPostID uuid.UUID) (float64, error) {
			if gotPostID != postID {
				t.Fatalf("unexpected post id for weighted reports: %s", gotPostID)
			}
			return 6, nil
		},
		setPostReportControl: func(ctx context.Context, gotPostID uuid.UUID, level int, distributionMultiplier float64) error {
			applied = true
			if gotPostID != postID {
				t.Fatalf("unexpected post id for set policy: %s", gotPostID)
			}
			if level != 3 {
				t.Fatalf("expected severe escalation to level 3, got %d", level)
			}
			if distributionMultiplier != reportDistributionMultiplier(level) {
				t.Fatalf("unexpected distribution multiplier: %v", distributionMultiplier)
			}
			return nil
		},
	}

	svc := &Service{repo: repo, cache: &testCacheRepo{}}
	if err := svc.ReportPost(context.Background(), reporterID, postID, ReportReasonNudity, ""); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !applied {
		t.Fatal("expected post report policy to be applied")
	}
}

func TestReportPost_Level4TriggersHardBlock(t *testing.T) {
	reporterID := uuid.New()
	postID := uuid.New()
	hardBlocked := false

	repo := &testRepo{
		postImpressions: func(ctx context.Context, gotPostID uuid.UUID) (int, error) {
			return 100, nil
		},
		weightedReportsForPost: func(ctx context.Context, gotPostID uuid.UUID) (float64, error) {
			return 13, nil // ratio 0.13 => level 4
		},
		setPostReportControl: func(ctx context.Context, gotPostID uuid.UUID, level int, distributionMultiplier float64) error {
			if level != 4 {
				t.Fatalf("expected level 4, got %d", level)
			}
			return nil
		},
		hardBlockAuthorFn: func(ctx context.Context, targetType string, targetID uuid.UUID) error {
			hardBlocked = true
			if targetType != ReportTargetPost || targetID != postID {
				t.Fatalf("unexpected hard block target: %s %s", targetType, targetID)
			}
			return nil
		},
	}

	svc := &Service{repo: repo, cache: &testCacheRepo{}}
	if err := svc.ReportPost(context.Background(), reporterID, postID, ReportReasonSpam, ""); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !hardBlocked {
		t.Fatal("expected hard block when post reaches moderation level 4")
	}
}

func TestReviewReports_AcceptedAliasBehavesAsActioned(t *testing.T) {
	targetID := uuid.New()
	reporterID := uuid.New()

	hideCalled := false
	setControlCalled := false
	markedReviewed := false
	markedReputationApplied := false
	strikeCalled := false
	reputationAccepted := false
	hardBlockCalled := false

	repo := &testRepo{
		hideTargetByReportsFn: func(ctx context.Context, targetType string, gotTargetID uuid.UUID) error {
			hideCalled = true
			if targetType != ReportTargetPost || gotTargetID != targetID {
				t.Fatalf("unexpected hide args: %s %s", targetType, gotTargetID)
			}
			return nil
		},
		setPostReportControl: func(ctx context.Context, gotPostID uuid.UUID, level int, distributionMultiplier float64) error {
			setControlCalled = true
			if gotPostID != targetID {
				t.Fatalf("unexpected post id: %s", gotPostID)
			}
			if level != 4 || distributionMultiplier != 0.0 {
				t.Fatalf("expected hard hide control level 4 with 0 multiplier, got level=%d multiplier=%v", level, distributionMultiplier)
			}
			return nil
		},
		hardBlockAuthorFn: func(ctx context.Context, targetType string, gotTargetID uuid.UUID) error {
			hardBlockCalled = true
			if targetType != ReportTargetPost || gotTargetID != targetID {
				t.Fatalf("unexpected hard block args: %s %s", targetType, gotTargetID)
			}
			return nil
		},
		markReportsReviewedFn: func(ctx context.Context, targetType string, gotTargetID uuid.UUID, decision string) ([]uuid.UUID, error) {
			markedReviewed = true
			if targetType != ReportTargetPost || gotTargetID != targetID {
				t.Fatalf("unexpected reviewed args: %s %s", targetType, gotTargetID)
			}
			if decision != ReportDecisionActioned {
				t.Fatalf("expected decision to be normalized to actioned, got %q", decision)
			}
			return []uuid.UUID{reporterID}, nil
		},
		applyReputationDeltaFn: func(ctx context.Context, reporterIDs []uuid.UUID, accepted bool) error {
			reputationAccepted = accepted
			if len(reporterIDs) != 1 || reporterIDs[0] != reporterID {
				t.Fatalf("unexpected reporter ids: %+v", reporterIDs)
			}
			return nil
		},
		markReputationAppliedFn: func(ctx context.Context, targetType string, gotTargetID uuid.UUID) error {
			markedReputationApplied = true
			if targetType != ReportTargetPost || gotTargetID != targetID {
				t.Fatalf("unexpected reputation apply args: %s %s", targetType, gotTargetID)
			}
			return nil
		},
		createPolicyStrikeFn: func(ctx context.Context, targetType string, gotTargetID uuid.UUID, expiresAt time.Time) error {
			strikeCalled = true
			if targetType != ReportTargetPost || gotTargetID != targetID {
				t.Fatalf("unexpected strike args: %s %s", targetType, gotTargetID)
			}
			if expiresAt.Before(time.Now().Add(29*24*time.Hour)) || expiresAt.After(time.Now().Add(31*24*time.Hour)) {
				t.Fatalf("unexpected strike expiration: %s", expiresAt)
			}
			return nil
		},
	}

	svc := &Service{repo: repo, cache: &testCacheRepo{}}

	if err := svc.ReviewReports(context.Background(), ReportTargetPost, targetID, ReportDecisionAccepted); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if !hideCalled {
		t.Fatal("expected hide target to be called for accepted alias")
	}
	if !setControlCalled {
		t.Fatal("expected post report control update for accepted alias")
	}
	if !markedReviewed {
		t.Fatal("expected reports to be marked reviewed")
	}
	if !markedReputationApplied {
		t.Fatal("expected report reputation to be marked applied")
	}
	if !reputationAccepted {
		t.Fatal("expected reporter reputation positive delta for actioned outcome")
	}
	if !strikeCalled {
		t.Fatal("expected author policy strike for actioned outcome")
	}
	if !hardBlockCalled {
		t.Fatal("expected hard block for actioned moderation outcome")
	}
}

func TestNormalizeReportDecision(t *testing.T) {
	if got := normalizeReportDecision(ReportDecisionAccepted); got != ReportDecisionActioned {
		t.Fatalf("expected accepted to normalize to actioned, got %q", got)
	}
	if got := normalizeReportDecision("  ACCEPTED  "); got != ReportDecisionActioned {
		t.Fatalf("expected uppercase accepted to normalize to actioned, got %q", got)
	}
	if got := normalizeReportDecision(ReportDecisionRejected); got != ReportDecisionRejected {
		t.Fatalf("expected rejected to stay unchanged, got %q", got)
	}
}

func TestNormalizeReportTargetType(t *testing.T) {
	if got := normalizeReportTargetType("  POST  "); got != ReportTargetPost {
		t.Fatalf("expected POST to normalize to %q, got %q", ReportTargetPost, got)
	}
	if got := normalizeReportTargetType("  CoMmEnT  "); got != ReportTargetComment {
		t.Fatalf("expected CoMmEnT to normalize to %q, got %q", ReportTargetComment, got)
	}
}

func TestReviewReports_NormalizesUppercaseTargetAndDecision(t *testing.T) {
	targetID := uuid.New()
	called := false

	repo := &testRepo{
		hideTargetByReportsFn: func(ctx context.Context, targetType string, gotTargetID uuid.UUID) error {
			called = true
			if targetType != ReportTargetPost || gotTargetID != targetID {
				t.Fatalf("unexpected args after normalization: %s %s", targetType, gotTargetID)
			}
			return nil
		},
		setPostReportControl: func(ctx context.Context, gotPostID uuid.UUID, level int, distributionMultiplier float64) error {
			return nil
		},
	}
	svc := &Service{repo: repo, cache: &testCacheRepo{}}

	if err := svc.ReviewReports(context.Background(), "  POST  ", targetID, "  ACCEPTED  "); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !called {
		t.Fatal("expected normalized review flow to execute")
	}
}
