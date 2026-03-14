package feed

import (
	"context"
	"math"
	"strings"
	"time"

	"github.com/brightbund-backend/internal/modules/profiles"
	"github.com/google/uuid"
)

const (
	// DefaultMaxAllowedActiveSeconds is the fallback limit (20 minutes)
	DefaultMaxAllowedActiveSeconds = 1200
	// BreakDurationSeconds is the mandatory break after the active phase (5 minutes)
	BreakDurationSeconds = 300
	// AwayResetThreshold is how long a user can be away (in active phase) before their timer resets
	AwayResetThreshold      = 300
	NetworkBufferSeconds    = 5.0
	FeedPresenceTTL         = 20 * time.Second
	ReportRateLimitPerHour  = 10
	AutoHideReportThreshold = 100
)

type Service struct {
	repo        Repository
	cache       CacheRepository
	profileRepo *profiles.Repository
}

func NewService(repo Repository, cache CacheRepository, profileRepo *profiles.Repository) *Service {
	return &Service{
		repo:        repo,
		cache:       cache,
		profileRepo: profileRepo,
	}
}

// getUserMaxSeconds returns the user's configured anti-doomscroll ceiling in seconds.
// Returns 0 if the user has set «no limit».
func (s *Service) getUserMaxSeconds(ctx context.Context, userID uuid.UUID) int {
	profile, err := s.profileRepo.GetProfile(ctx, userID.String())
	if err != nil || profile == nil {
		return DefaultMaxAllowedActiveSeconds
	}
	if profile.FeedTimeLimitMins == 0 {
		return 0 // No limit
	}
	return profile.FeedTimeLimitMins * 60
}

// ---------------- Anti-Doomscroll System ----------------

func (s *Service) GetFeedState(ctx context.Context, userID uuid.UUID) (*FeedStateResponse, error) {
	state, err := s.getOrInitState(ctx, userID)
	if err != nil {
		return nil, err
	}

	now := time.Now()
	// calledFromSync=false: gap since LastSyncTimestamp is off-feed time; counts toward break.
	state = s.applyStateTransitions(ctx, state, now, false)
	state.LastSyncTimestamp = now
	_ = s.cache.SetFatigueState(ctx, state)
	_ = s.cache.MarkUserDirty(ctx, userID) // Ensure transition (e.g. reset) is flushed to Postgres

	return &FeedStateResponse{
		AccumulatedActiveSeconds: state.AccumulatedActiveSeconds,
		IsInCooldown:             state.IsInCooldown,
		BreakSecondsRemaining:    s.calcBreakSecondsRemaining(state),
		AccumulatedBreakSeconds:  state.AccumulatedBreakSeconds,
		MaxAllowedSeconds:        state.MaxAllowedSeconds,
		ServerTimestamp:          now.UTC(),
	}, nil
}

func (s *Service) SyncFeedState(ctx context.Context, userID uuid.UUID, req *SyncFeedStateRequest) (*FeedStateResponse, error) {
	if req.DeltaSeconds <= 0 {
		return nil, ErrInvalidDelta
	}
	if req.DeviceID == "" {
		return nil, ErrInvalidDeviceID
	}

	now := time.Now()
	state, err := s.getOrInitState(ctx, userID)
	if err != nil {
		return nil, err
	}
	_ = s.cache.MarkDeviceOnFeed(ctx, userID, req.DeviceID, FeedPresenceTTL)

	// 1. Apply state transitions.
	// calledFromSync=true: user IS on the feed — off-feed gap must NOT count toward break.
	state = s.applyStateTransitions(ctx, state, now, true)

	// 2. If in break, return current state without accumulating active time.
	if state.IsInCooldown {
		_ = s.cache.SetFatigueState(ctx, state)
		_ = s.cache.MarkUserDirty(ctx, userID)
		return &FeedStateResponse{
			AccumulatedActiveSeconds: state.AccumulatedActiveSeconds,
			IsInCooldown:             true,
			BreakSecondsRemaining:    s.calcBreakSecondsRemaining(state),
			AccumulatedBreakSeconds:  state.AccumulatedBreakSeconds,
			MaxAllowedSeconds:        state.MaxAllowedSeconds,
			ServerTimestamp:          now.UTC(),
			ActionRequired:           "enforce_cooldown",
		}, nil
	}

	// 3. Anti-Cheat Engine
	realElapsed := now.Sub(state.LastSyncTimestamp).Seconds()
	if realElapsed < 0 {
		realElapsed = 0
	}

	maxPossibleDelta := realElapsed + NetworkBufferSeconds
	deltaSec := float64(req.DeltaSeconds)

	if deltaSec > maxPossibleDelta {
		// Cheat detected or clock jumped: cap the delta to real elapsed time
		deltaSec = math.Floor(realElapsed)
	}

	// 4. Accumulate active time
	state.AccumulatedActiveSeconds += int(deltaSec)
	state.LastSyncTimestamp = now

	// 5. Cooldown check — skip if user set no limit (maxSeconds == 0)
	actionRequired := ""
	if state.MaxAllowedSeconds > 0 && state.AccumulatedActiveSeconds >= state.MaxAllowedSeconds {
		state.IsInCooldown = true
		state.BreakStartedAt = &now
		state.AccumulatedBreakSeconds = 0
		actionRequired = "trigger_friction"
	}

	// 6. Save to cache and mark dirty for async Postgres flush
	_ = s.cache.SetFatigueState(ctx, state)
	_ = s.cache.MarkUserDirty(ctx, userID)

	return &FeedStateResponse{
		AccumulatedActiveSeconds: state.AccumulatedActiveSeconds,
		IsInCooldown:             state.IsInCooldown,
		BreakSecondsRemaining:    s.calcBreakSecondsRemaining(state),
		AccumulatedBreakSeconds:  state.AccumulatedBreakSeconds,
		MaxAllowedSeconds:        state.MaxAllowedSeconds,
		ServerTimestamp:          now.UTC(),
		ActionRequired:           actionRequired,
	}, nil
}

func (s *Service) getOrInitState(ctx context.Context, userID uuid.UUID) (*FeedFatigueState, error) {
	state, err := s.cache.GetFatigueState(ctx, userID)
	if err == nil && state != nil {
		return state, nil
	}

	// Fallback to database
	state, err = s.repo.GetFatigueState(ctx, userID)
	if err != nil {
		// Init fresh
		state = &FeedFatigueState{
			UserID:                   userID,
			AccumulatedActiveSeconds: 0,
			LastSyncTimestamp:        time.Now(),
			IsInCooldown:             false,
		}
	}

	// Fetch dynamic limit ONCE and cache it
	state.MaxAllowedSeconds = s.getUserMaxSeconds(ctx, userID)
	_ = s.cache.SetFatigueState(ctx, state)

	return state, nil
}

// applyStateTransitions implements the break/reset state machine.
// Called on every GetFeedState / SyncFeedState to advance the state.
//
// calledFromSync=true  → caller is SyncFeedState (user IS on the feed).
//   - Active phase: accumulate time via SyncFeedState delta, no away-reset here.
//   - Break phase:  break countdown does NOT advance and LastSyncTimestamp is refreshed.
//
// calledFromSync=false → caller is GetFeedState (user just opened / re-entered the feed).
//   - Active phase: gap since LastSyncTimestamp is off-feed time; if ≥ AwayResetThreshold, reset.
//   - Break phase:  break countdown advances only while no device is currently on feed.
func (s *Service) applyStateTransitions(ctx context.Context, state *FeedFatigueState, now time.Time, calledFromSync bool) *FeedFatigueState {
	if state.IsInCooldown {
		if calledFromSync {
			// While feed is open on this device, cooldown is frozen.
			state.LastSyncTimestamp = now
			return state
		}

		// User is entering/re-entering feed. Advance break only by confirmed off-feed time.
		anyOnFeed := false
		if s.cache != nil {
			active, err := s.cache.AnyDeviceOnFeed(ctx, state.UserID)
			if err == nil {
				anyOnFeed = active
			}
		}

		if !anyOnFeed {
			offFeedSeconds := int(now.Sub(state.LastSyncTimestamp).Seconds())
			if offFeedSeconds > 0 {
				state.AccumulatedBreakSeconds += offFeedSeconds
			}
		}

		state.LastSyncTimestamp = now
		if state.AccumulatedBreakSeconds >= BreakDurationSeconds {
			state.AccumulatedActiveSeconds = 0
			state.AccumulatedBreakSeconds = 0
			state.IsInCooldown = false
			state.BreakStartedAt = nil
		}
	} else {
		// Active phase — away-reset only fires when coming from outside the feed (GetFeedState).
		// While actively syncing, LastSyncTimestamp is always fresh, so awaySeconds stays small.
		if !calledFromSync {
			awaySeconds := now.Sub(state.LastSyncTimestamp).Seconds()
			if awaySeconds >= float64(AwayResetThreshold) {
				state.AccumulatedActiveSeconds = 0
				state.IsInCooldown = false
			}
		}
	}
	return state
}

// calcBreakSecondsRemaining returns off-feed seconds the user still needs to wait
// before the break resolves. Uses AccumulatedBreakSeconds (off-feed time only)
// so the countdown only ticks while the user is away from the feed.
func (s *Service) calcBreakSecondsRemaining(state *FeedFatigueState) int {
	if !state.IsInCooldown {
		return 0
	}
	remaining := BreakDurationSeconds - state.AccumulatedBreakSeconds
	if remaining < 0 {
		return 0
	}
	return remaining
}

// ---------------- Content System ----------------

func (s *Service) CreatePost(ctx context.Context, userID uuid.UUID, req *CreatePostRequest) (*PostResponse, error) {
	if req.Caption == "" && len(req.MediaAttachments) == 0 {
		return nil, ErrPostRequiresMedia
	}

	// Normalize media type to lowercase to match DB check constraint (image/video).
	for i := range req.MediaAttachments {
		req.MediaAttachments[i].Type = strings.ToLower(req.MediaAttachments[i].Type)
	}

	post := &Post{
		ID:                uuid.New(),
		UserID:            userID,
		Caption:           req.Caption,
		Visibility:        req.Visibility,
		CommentPermission: req.CommentPermission,
		HideLikesCount:    req.HideLikesCount,
		IsPublic:          req.Visibility == VisibilityAnyone,
		LocationCity:      req.LocationCity,
		LocationCountry:   req.LocationCountry,
		LocationLat:       req.LocationLat,
		LocationLon:       req.LocationLon,
	}

	err := s.repo.CreatePost(ctx, post, req.MediaAttachments)
	if err != nil {
		return nil, err
	}

	return s.repo.GetPost(ctx, post.ID, userID)
}

func (s *Service) UpdatePost(ctx context.Context, userID, postID uuid.UUID, req *UpdatePostRequest) (*PostResponse, error) {
	if req == nil {
		return nil, ErrInvalidPostUpdate
	}

	if req.CommentPermission == nil && req.HideLikesCount == nil {
		return nil, ErrInvalidPostUpdate
	}

	if req.CommentPermission != nil {
		perm := strings.TrimSpace(*req.CommentPermission)
		if perm != CommentPermAnyone && perm != CommentPermAlliesOnly && perm != CommentPermNoOne {
			return nil, ErrInvalidCommentPermission
		}
		req.CommentPermission = &perm
	}

	if err := s.repo.UpdatePost(ctx, postID, userID, req); err != nil {
		return nil, err
	}

	return s.repo.GetPost(ctx, postID, userID)
}

func (s *Service) DeletePost(ctx context.Context, userID, postID uuid.UUID) error {
	return s.repo.DeletePost(ctx, postID, userID)
}

func (s *Service) GetFeed(ctx context.Context, viewerID uuid.UUID, cursor string, limit int, lat, lon float64, hasLocation bool) (*FeedResponse, error) {
	feedDegraded := false
	if state, err := s.getOrInitState(ctx, viewerID); err == nil && state != nil {
		now := time.Now()
		state = s.applyStateTransitions(ctx, state, now, false)
		state.LastSyncTimestamp = now
		_ = s.cache.SetFatigueState(ctx, state)
		_ = s.cache.MarkUserDirty(ctx, viewerID)
		feedDegraded = state.IsInCooldown
	}

	// Default to current time if cursor is empty
	cursorTime := time.Now()
	if cursor != "" {
		if t, err := time.Parse(time.RFC3339Nano, cursor); err == nil {
			cursorTime = t
		}
	}

	items, nextCursor, err := s.repo.GetSmartFeed(ctx, viewerID, lat, lon, hasLocation, cursorTime, limit)
	if err != nil {
		return nil, err
	}

	return &FeedResponse{
		Items:        items,
		NextCursor:   nextCursor,
		FeedDegraded: feedDegraded,
	}, nil
}

func (s *Service) CreateComment(ctx context.Context, userID, postID uuid.UUID, req *CreateCommentRequest) (*CommentResponse, error) {
	if req.ContentText == "" && len(req.MediaAttachments) == 0 {
		return nil, ErrCommentRequiresText
	}

	mediaAttachments := make([]MediaAttachment, 0, len(req.MediaAttachments))
	seen := make(map[string]struct{}, len(req.MediaAttachments))
	for _, item := range req.MediaAttachments {
		item.Type = strings.ToLower(item.Type)
		key := item.Type + "|" + item.URL + "|" + item.ThumbnailURL
		if _, exists := seen[key]; exists {
			continue
		}
		seen[key] = struct{}{}
		mediaAttachments = append(mediaAttachments, item)
	}
	if len(mediaAttachments) > 10 {
		return nil, ErrTooManyMediaAttachments
	}

	permission, authorID, err := s.repo.GetPostPermissionsInfo(ctx, postID)
	if err != nil {
		return nil, err // ErrPostNotFound usually
	}

	// Fast path check
	if permission == CommentPermNoOne {
		// Only author can comment if set to NoOne, or nobody. Assuming nobody for NoOne.
		if userID != authorID {
			return nil, ErrCommentNotAllowed
		}
	}

	if permission == CommentPermAlliesOnly {
		if userID != authorID {
			isAlly, err := s.repo.IsAlly(ctx, userID, authorID)
			if err != nil {
				return nil, err
			}
			if !isAlly {
				return nil, ErrCommentNotAllowed
			}
		}
	}

	comment := &PostComment{
		ID:               uuid.New(),
		PostID:           postID,
		UserID:           userID,
		ParentCommentID:  req.ParentID,
		Content:          req.ContentText,
		MediaAttachments: mediaAttachments,
	}

	if req.ParentID != nil {
		parentInfo, err := s.repo.GetCommentThreadParent(ctx, *req.ParentID)
		if err != nil {
			return nil, err
		}
		if parentInfo.PostID != postID {
			return nil, ErrCommentNotFound
		}

		rootID := *req.ParentID
		if parentInfo.RootCommentID != nil {
			rootID = *parentInfo.RootCommentID
		}
		comment.RootCommentID = &rootID
	}

	err = s.repo.CreateComment(ctx, comment)
	if err != nil {
		return nil, err
	}

	return s.repo.GetComment(ctx, comment.ID, userID)
}

func (s *Service) GetThreadedComments(ctx context.Context, viewerID, postID uuid.UUID, parentID *uuid.UUID, cursor string, limit int) (*ThreadedCommentsResponse, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	// Add cursor parsing, offset calculations
	comments, nextCursor, err := s.repo.GetThreadedComments(ctx, postID, viewerID, parentID, cursor, limit)
	if err != nil {
		return nil, err
	}
	if comments == nil {
		comments = []CommentResponse{}
	}

	return &ThreadedCommentsResponse{
		Comments:   comments,
		NextCursor: nextCursor,
	}, nil
}

func (s *Service) DeleteComment(ctx context.Context, actorID, commentID uuid.UUID) error {
	isAdmin, err := s.repo.IsUserAdmin(ctx, actorID)
	if err != nil {
		return err
	}
	return s.repo.DeleteComment(ctx, commentID, actorID, isAdmin)
}

func (s *Service) validateReportReason(reason string) bool {
	switch strings.TrimSpace(reason) {
	case ReportReasonSpam,
		ReportReasonHate,
		ReportReasonNudity,
		ReportReasonViolence,
		ReportReasonIllegal,
		ReportReasonGambling,
		ReportReasonCopyright,
		ReportReasonFakeAccount,
		ReportReasonManipulation:
		return true
	default:
		return false
	}
}

func (s *Service) reportTarget(ctx context.Context, reporterID uuid.UUID, targetType string, targetID uuid.UUID, reason, description string) error {
	if !s.validateReportReason(reason) {
		return ErrInvalidReportReason
	}

	recentCount, err := s.repo.CountRecentReportsByUser(ctx, reporterID, time.Now().Add(-1*time.Hour))
	if err != nil {
		return err
	}
	if recentCount >= ReportRateLimitPerHour {
		return ErrReportRateLimited
	}

	if err := s.repo.CreateReport(ctx, reporterID, targetType, targetID, reason, description); err != nil {
		if strings.Contains(err.Error(), "duplicate key") || strings.Contains(err.Error(), "uq_reports_reporter_target") {
			return ErrDuplicateReport
		}
		return err
	}

	totalReports, err := s.repo.CountReportsForTarget(ctx, targetType, targetID)
	if err != nil {
		return err
	}
	if totalReports >= AutoHideReportThreshold {
		if err := s.repo.HideTargetByReports(ctx, targetType, targetID); err != nil {
			return err
		}
	}

	return nil
}

func (s *Service) ReportComment(ctx context.Context, reporterID, commentID uuid.UUID, reason, description string) error {
	return s.reportTarget(ctx, reporterID, ReportTargetComment, commentID, reason, description)
}

func (s *Service) ReportPost(ctx context.Context, reporterID, postID uuid.UUID, reason, description string) error {
	return s.reportTarget(ctx, reporterID, ReportTargetPost, postID, reason, description)
}

func (s *Service) ListReports(ctx context.Context, status, targetType, reason string, limit, offset int) (*ReportsListResponse, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	if offset < 0 {
		offset = 0
	}

	items, total, err := s.repo.ListReports(ctx, status, targetType, reason, limit, offset)
	if err != nil {
		return nil, err
	}

	return &ReportsListResponse{
		Items:  items,
		Total:  total,
		Limit:  limit,
		Offset: offset,
	}, nil
}

// ---------------- Interactions System ----------------

func (s *Service) ToggleCommentLike(ctx context.Context, commentID, userID uuid.UUID) (*CommentResponse, error) {
	err := s.repo.ToggleCommentLike(ctx, commentID, userID)
	if err != nil {
		return nil, err
	}
	return s.repo.GetComment(ctx, commentID, userID)
}

func (s *Service) ToggleLike(ctx context.Context, postID, userID uuid.UUID) (*PostResponse, error) {
	err := s.repo.ToggleLike(ctx, postID, userID)
	if err != nil {
		return nil, err
	}
	return s.repo.GetPost(ctx, postID, userID)
}

func (s *Service) GetInteractions(ctx context.Context, postID uuid.UUID, iType string, cursor string, limit int) (*InteractionListResponse, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	items, next, err := s.repo.GetInteractions(ctx, postID, iType, cursor, limit)
	if err != nil {
		return nil, err
	}
	return &InteractionListResponse{Items: items, NextCursor: next}, nil
}

func (s *Service) GetSeals(ctx context.Context, postID uuid.UUID, cursor string, limit int) (*SealListResponse, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	items, next, err := s.repo.GetSeals(ctx, postID, cursor, limit)
	if err != nil {
		return nil, err
	}
	return &SealListResponse{Items: items, NextCursor: next}, nil
}

// ---------------- Profile Posts ----------------

// GetUserPostsGrid returns a paginated grid of thumbnail items for a user's profile.
func (s *Service) GetUserPostsGrid(ctx context.Context, authorID, viewerID uuid.UUID, cursorStr string, limit int) (*UserPostsGridResponse, error) {
	if limit <= 0 || limit > 30 {
		limit = 18
	}
	cursor := time.Now()
	if cursorStr != "" {
		if t, err := time.Parse(time.RFC3339Nano, cursorStr); err == nil {
			cursor = t
		}
	}
	items, nextCursor, err := s.repo.GetUserPostsGrid(ctx, authorID, viewerID, cursor, limit)
	if err != nil {
		return nil, err
	}
	return &UserPostsGridResponse{Items: items, NextCursor: nextCursor}, nil
}

// GetUserPostsList returns a paginated full-PostResponse list for a user's profile.
// If anchorPostID is set, the list starts at (and includes) that post.
// Otherwise cursorStr is used as the exclusive upper bound.
func (s *Service) GetUserPostsList(ctx context.Context, authorID, viewerID uuid.UUID, anchorPostID *uuid.UUID, cursorStr string, limit int) (*FeedResponse, error) {
	if limit <= 0 || limit > 30 {
		limit = 10
	}
	cursor := time.Now()
	if anchorPostID != nil {
		anchorTime, err := s.repo.GetPostCreatedAt(ctx, *anchorPostID)
		if err == nil {
			// Add 1ns so the anchor post itself satisfies created_at < cursor.
			cursor = anchorTime.Add(time.Nanosecond)
		}
	} else if cursorStr != "" {
		if t, err := time.Parse(time.RFC3339Nano, cursorStr); err == nil {
			cursor = t
		}
	}
	items, nextCursor, err := s.repo.GetUserPostsList(ctx, authorID, viewerID, cursor, limit)
	if err != nil {
		return nil, err
	}
	return &FeedResponse{Items: items, NextCursor: nextCursor}, nil
}
