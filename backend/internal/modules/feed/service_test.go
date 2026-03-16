package feed

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
)

type testRepo struct {
	createPostFn func(ctx context.Context, post *Post, media []MediaAttachment) error
	updatePostFn func(ctx context.Context, postID, userID uuid.UUID, req *UpdatePostRequest) error
	deletePostFn func(ctx context.Context, postID, userID uuid.UUID) error
	getPostFn    func(ctx context.Context, postID uuid.UUID, viewerID uuid.UUID) (*PostResponse, error)

	createReportFn          func(ctx context.Context, reporterID uuid.UUID, targetType string, targetID uuid.UUID, reason, description string) error
	countRecentReportsByFn  func(ctx context.Context, reporterID uuid.UUID, since time.Time) (int, error)
	countReportsForTargetFn func(ctx context.Context, targetType string, targetID uuid.UUID) (int, error)
	weightedReportsForPost  func(ctx context.Context, postID uuid.UUID) (float64, error)
	postImpressions         func(ctx context.Context, postID uuid.UUID) (int, error)
	setPostReportControl    func(ctx context.Context, postID uuid.UUID, level int, distributionMultiplier float64) error
	incrementImpressions    func(ctx context.Context, postIDs []uuid.UUID) error
	hideTargetByReportsFn   func(ctx context.Context, targetType string, targetID uuid.UUID) error
	hidePostForReporterFn   func(ctx context.Context, reporterID, postID uuid.UUID) error

	lastCreatedPost *Post
}

func (r *testRepo) GetFatigueState(ctx context.Context, userID uuid.UUID) (*FeedFatigueState, error) {
	return nil, errors.New("not implemented")
}

func (r *testRepo) UpsertFatigueState(ctx context.Context, state *FeedFatigueState) error {
	return nil
}

func (r *testRepo) CreatePost(ctx context.Context, post *Post, media []MediaAttachment) error {
	r.lastCreatedPost = post
	if r.createPostFn != nil {
		return r.createPostFn(ctx, post, media)
	}
	return nil
}

func (r *testRepo) UpdatePost(ctx context.Context, postID, userID uuid.UUID, req *UpdatePostRequest) error {
	if r.updatePostFn != nil {
		return r.updatePostFn(ctx, postID, userID, req)
	}
	return nil
}

func (r *testRepo) DeletePost(ctx context.Context, postID, userID uuid.UUID) error {
	if r.deletePostFn != nil {
		return r.deletePostFn(ctx, postID, userID)
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
	return nil, "", nil
}

func (r *testRepo) GetUserPostsList(ctx context.Context, authorID, viewerID uuid.UUID, cursor time.Time, limit int) ([]PostResponse, string, error) {
	return nil, "", nil
}

func (r *testRepo) GetPostCreatedAt(ctx context.Context, postID uuid.UUID) (time.Time, error) {
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
	return nil, nil
}

func (r *testRepo) ApplyReporterReputationDelta(ctx context.Context, reporterIDs []uuid.UUID, accepted bool) error {
	return nil
}

func (r *testRepo) MarkReportReputationApplied(ctx context.Context, targetType string, targetID uuid.UUID) error {
	return nil
}

func (r *testRepo) CreateAuthorPolicyStrikeForTarget(ctx context.Context, targetType string, targetID uuid.UUID, expiresAt time.Time) error {
	return nil
}

func (r *testRepo) HideTargetByReports(ctx context.Context, targetType string, targetID uuid.UUID) error {
	if r.hideTargetByReportsFn != nil {
		return r.hideTargetByReportsFn(ctx, targetType, targetID)
	}
	return nil
}

func (r *testRepo) ListReports(ctx context.Context, status, targetType, reason string, limit, offset int) ([]ReportItem, int, error) {
	return nil, 0, nil
}

func (r *testRepo) IsAlly(ctx context.Context, userID, targetUserID uuid.UUID) (bool, error) {
	return false, nil
}

func (r *testRepo) IsUserAdmin(ctx context.Context, userID uuid.UUID) (bool, error) {
	return false, nil
}

func (r *testRepo) GetInteractions(ctx context.Context, postID uuid.UUID, interactionType string, cursor string, limit int) ([]InteractionResponse, string, error) {
	return nil, "", nil
}

func (r *testRepo) GetSeals(ctx context.Context, postID uuid.UUID, cursor string, limit int) ([]SealResponse, string, error) {
	return nil, "", nil
}

func (r *testRepo) ToggleLike(ctx context.Context, postID uuid.UUID, userID uuid.UUID) error {
	return nil
}

func (r *testRepo) BatchFlushLikes(ctx context.Context, postID uuid.UUID, userIDs []uuid.UUID) error {
	return nil
}

func (r *testRepo) BatchFlushSeals(ctx context.Context, postID uuid.UUID, count int, totalAmount int64) error {
	return nil
}

type testCacheRepo struct {
	anyOnFeed bool
}

func (t *testCacheRepo) GetFatigueState(ctx context.Context, userID uuid.UUID) (*FeedFatigueState, error) {
	return nil, nil
}

func (t *testCacheRepo) SetFatigueState(ctx context.Context, state *FeedFatigueState) error {
	return nil
}

func (t *testCacheRepo) MarkUserDirty(ctx context.Context, userID uuid.UUID) error {
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

	result := svc.applyStateTransitions(context.Background(), state, now, false)

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

	result := svc.applyStateTransitions(context.Background(), state, now, true)

	if result.AccumulatedBreakSeconds != 120 {
		t.Errorf("expected break seconds to stay frozen, got %d", result.AccumulatedBreakSeconds)
	}
	if !result.LastSyncTimestamp.Equal(now) {
		t.Error("expected LastSyncTimestamp to be refreshed during sync")
	}
}

func TestApplyStateTransitions_BreakPhase_ReentryAdvancesWhenNoDeviceOnFeed(t *testing.T) {
	svc := newTestService(false)
	now := time.Now()

	state := &FeedFatigueState{
		UserID:                   uuid.New(),
		AccumulatedActiveSeconds: 1200,
		AccumulatedBreakSeconds:  100,
		LastSyncTimestamp:        now.Add(-50 * time.Second),
		IsInCooldown:             true,
	}

	result := svc.applyStateTransitions(context.Background(), state, now, false)

	if result.AccumulatedBreakSeconds != 150 {
		t.Errorf("expected accumulated break to become 150, got %d", result.AccumulatedBreakSeconds)
	}
	if result.IsInCooldown != true {
		t.Error("expected cooldown to continue")
	}
}

func TestApplyStateTransitions_BreakPhase_ReentryFrozenWhenAnotherDeviceOnFeed(t *testing.T) {
	svc := newTestService(true)
	now := time.Now()

	state := &FeedFatigueState{
		UserID:                   uuid.New(),
		AccumulatedActiveSeconds: 1200,
		AccumulatedBreakSeconds:  100,
		LastSyncTimestamp:        now.Add(-50 * time.Second),
		IsInCooldown:             true,
	}

	result := svc.applyStateTransitions(context.Background(), state, now, false)

	if result.AccumulatedBreakSeconds != 100 {
		t.Errorf("expected break to stay frozen at 100, got %d", result.AccumulatedBreakSeconds)
	}
	if !result.LastSyncTimestamp.Equal(now) {
		t.Error("expected LastSyncTimestamp to move to now on reentry")
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

	result := svc.applyStateTransitions(context.Background(), state, now, false)

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

	rem := svc.calcBreakSecondsRemaining(state)
	if rem != 180 {
		t.Errorf("expected 180, got %d", rem)
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
		deletePostFn: func(ctx context.Context, gotPostID, gotUserID uuid.UUID) error {
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
