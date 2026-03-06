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
	AwayResetThreshold   = 300
	NetworkBufferSeconds = 5.0
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
	state = s.applyStateTransitions(state, now)
	state.LastSyncTimestamp = now
	_ = s.cache.SetFatigueState(ctx, state)
	_ = s.cache.MarkUserDirty(ctx, userID) // Ensure transition (e.g. reset) is flushed to Postgres

	return &FeedStateResponse{
		AccumulatedActiveSeconds: state.AccumulatedActiveSeconds,
		IsInCooldown:             state.IsInCooldown,
		BreakSecondsRemaining:    s.calcBreakSecondsRemaining(state, now),
		MaxAllowedSeconds:        state.MaxAllowedSeconds,
		ServerTimestamp:          now.UTC(),
	}, nil
}

func (s *Service) SyncFeedState(ctx context.Context, userID uuid.UUID, req *SyncFeedStateRequest) (*FeedStateResponse, error) {
	if req.DeltaSeconds <= 0 {
		return nil, ErrInvalidDelta
	}

	now := time.Now()
	state, err := s.getOrInitState(ctx, userID)
	if err != nil {
		return nil, err
	}

	// 1. Apply state transitions (break expiry or away-reset)
	state = s.applyStateTransitions(state, now)

	// 2. If in break, return current state without accumulating time
	if state.IsInCooldown {
		state.LastSyncTimestamp = now
		_ = s.cache.SetFatigueState(ctx, state)
		_ = s.cache.MarkUserDirty(ctx, userID)
		return &FeedStateResponse{
			AccumulatedActiveSeconds: state.AccumulatedActiveSeconds,
			IsInCooldown:             true,
			BreakSecondsRemaining:    s.calcBreakSecondsRemaining(state, now),
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
		actionRequired = "trigger_friction"
	}

	// 6. Save to cache and mark dirty for async Postgres flush
	_ = s.cache.SetFatigueState(ctx, state)
	_ = s.cache.MarkUserDirty(ctx, userID)

	return &FeedStateResponse{
		AccumulatedActiveSeconds: state.AccumulatedActiveSeconds,
		IsInCooldown:             state.IsInCooldown,
		BreakSecondsRemaining:    s.calcBreakSecondsRemaining(state, now),
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

// applyStateTransitions implements the hard break/reset state machine.
// Called on every GetFeedState / SyncFeedState to advance the state.
//
// Active phase: if the user has been away ≥ AwayResetThreshold → full reset.
// Break phase:  if break duration ≥ BreakDurationSeconds → full reset back to active.
func (s *Service) applyStateTransitions(state *FeedFatigueState, now time.Time) *FeedFatigueState {
	if state.IsInCooldown {
		// Break is running — check if it has expired.
		// If BreakStartedAt is nil (e.g. data gap from pre-migration rows), fall back
		// to LastSyncTimestamp so the break can still expire rather than getting stuck.
		breakStart := state.BreakStartedAt
		if breakStart == nil {
			breakStart = &state.LastSyncTimestamp
			state.BreakStartedAt = breakStart // recover: persist so calcBreakSecondsRemaining works
		}
		elapsed := now.Sub(*breakStart).Seconds()
		if elapsed >= float64(BreakDurationSeconds) {
			// Break expired → full reset
			state.AccumulatedActiveSeconds = 0
			state.IsInCooldown = false
			state.BreakStartedAt = nil
		}
	} else {
		// Active phase — if user was away long enough, reset the timer
		awaySeconds := now.Sub(state.LastSyncTimestamp).Seconds()
		if awaySeconds >= float64(AwayResetThreshold) {
			state.AccumulatedActiveSeconds = 0
			state.IsInCooldown = false
		}
	}
	return state
}

// calcBreakSecondsRemaining returns seconds left in the current break (0 if not in break).
func (s *Service) calcBreakSecondsRemaining(state *FeedFatigueState, now time.Time) int {
	if !state.IsInCooldown || state.BreakStartedAt == nil {
		return 0
	}
	elapsed := int(now.Sub(*state.BreakStartedAt).Seconds())
	remaining := BreakDurationSeconds - elapsed
	if remaining < 0 {
		return 0
	}
	return remaining
}

// ---------------- Content System ----------------

func (s *Service) CreatePost(ctx context.Context, userID uuid.UUID, req *CreatePostRequest) error {
	if req.Caption == "" && len(req.MediaAttachments) == 0 {
		return ErrPostRequiresMedia
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
		IsPublic:          req.Visibility == VisibilityAnyone,
	}

	return s.repo.CreatePost(ctx, post, req.MediaAttachments)
}

func (s *Service) GetFeed(ctx context.Context, viewerID uuid.UUID, cursor string, limit int) (*FeedResponse, error) {
	// Default to current time if cursor is empty
	cursorTime := time.Now()
	if cursor != "" {
		if t, err := time.Parse(time.RFC3339Nano, cursor); err == nil {
			cursorTime = t
		}
	}

	// Assuming requester's lat/lon is available in context or req (hardcoded for MVP stub)
	lat, lon := 0.0, 0.0

	items, nextCursor, err := s.repo.GetSmartFeed(ctx, viewerID, lat, lon, cursorTime, limit)
	if err != nil {
		return nil, err
	}

	return &FeedResponse{
		Items:      items,
		NextCursor: nextCursor,
	}, nil
}

func (s *Service) CreateComment(ctx context.Context, userID, postID uuid.UUID, req *CreateCommentRequest) error {
	if req.ContentText == "" && req.MediaAttachment == nil {
		return ErrCommentRequiresText
	}

	permission, authorID, err := s.repo.GetPostPermissionsInfo(ctx, postID)
	if err != nil {
		return err // ErrPostNotFound usually
	}

	// Fast path check
	if permission == CommentPermNoOne {
		// Only author can comment if set to NoOne, or nobody. Assuming nobody for NoOne.
		if userID != authorID {
			return ErrCommentNotAllowed
		}
	}

	if permission == CommentPermAlliesOnly {
		// TODO: Inject Profiles dependency or Social Network validation layer to check ally status
		// Assuming repo validates graph relation if not author
		if userID != authorID {
			// Placeholder: check real ally relation here
			// return ErrCommentNotAllowed
		} // else Author can always comment on their own Allies-only post
	}

	comment := &PostComment{
		ID:              uuid.New(),
		PostID:          postID,
		UserID:          userID,
		ParentCommentID: req.ParentID,
		Content:         req.ContentText,
		MediaAttachment: req.MediaAttachment,
	}

	return s.repo.CreateComment(ctx, comment)
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

	return &ThreadedCommentsResponse{
		Comments:   comments,
		NextCursor: nextCursor,
	}, nil
}

// ---------------- Interactions System ----------------

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
