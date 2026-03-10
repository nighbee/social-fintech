package feed

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
)

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
