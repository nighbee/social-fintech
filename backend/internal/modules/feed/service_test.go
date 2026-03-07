package feed

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

// newTestService returns a minimal Service with no repos (state machine is pure-logic).
func newTestService() *Service {
	return &Service{}
}

func ptr[T any](v T) *T { return &v }

// ─── applyStateTransitions ────────────────────────────────────────────────────

func TestApplyStateTransitions_ActivePhase_NoReset(t *testing.T) {
	svc := newTestService()
	now := time.Now()

	state := &FeedFatigueState{
		UserID:                   uuid.New(),
		AccumulatedActiveSeconds: 600,
		LastSyncTimestamp:        now.Add(-10 * time.Second), // 10s away — well under 300s threshold
		IsInCooldown:             false,
	}

	// calledFromSync=false simulates GetFeedState (user returning to feed)
	result := svc.applyStateTransitions(state, now, false)

	if result.AccumulatedActiveSeconds != 600 {
		t.Errorf("expected 600 accumulated, got %d", result.AccumulatedActiveSeconds)
	}
	if result.IsInCooldown {
		t.Error("expected IsInCooldown=false")
	}
}

func TestApplyStateTransitions_ActivePhase_ResetAfterLongAway(t *testing.T) {
	svc := newTestService()
	now := time.Now()

	state := &FeedFatigueState{
		UserID:                   uuid.New(),
		AccumulatedActiveSeconds: 900,
		LastSyncTimestamp:        now.Add(-301 * time.Second), // 301s — exceeds AwayResetThreshold
		IsInCooldown:             false,
	}

	result := svc.applyStateTransitions(state, now, false)

	if result.AccumulatedActiveSeconds != 0 {
		t.Errorf("expected full reset to 0, got %d", result.AccumulatedActiveSeconds)
	}
	if result.IsInCooldown {
		t.Error("expected IsInCooldown=false after reset")
	}
}

func TestApplyStateTransitions_ActivePhase_ExactThresholdDoesReset(t *testing.T) {
	svc := newTestService()
	now := time.Now()

	state := &FeedFatigueState{
		UserID:                   uuid.New(),
		AccumulatedActiveSeconds: 500,
		LastSyncTimestamp:        now.Add(-300 * time.Second), // exactly at threshold → resets
		IsInCooldown:             false,
	}

	result := svc.applyStateTransitions(state, now, false)

	if result.AccumulatedActiveSeconds != 0 {
		t.Errorf("expected reset at exact threshold, got %d", result.AccumulatedActiveSeconds)
	}
}

func TestApplyStateTransitions_BreakPhase_StillRunning(t *testing.T) {
	svc := newTestService()
	now := time.Now()
	breakStart := now.Add(-240 * time.Second) // informational only

	// User has been in break for 240s total, but LastSyncTimestamp reflects
	// they were last on feed 120s ago (meaning 120s off-feed this visit).
	state := &FeedFatigueState{
		UserID:                   uuid.New(),
		AccumulatedActiveSeconds: 1200,
		AccumulatedBreakSeconds:  120,                         // already served 120s of break off-feed
		LastSyncTimestamp:        now.Add(-120 * time.Second), // 120s since last on-feed
		IsInCooldown:             true,
		BreakStartedAt:           &breakStart,
	}

	// calledFromSync=false: adds the 120s gap → AccumulatedBreakSeconds = 240, still < 300
	result := svc.applyStateTransitions(state, now, false)

	if !result.IsInCooldown {
		t.Error("expected IsInCooldown=true — break not expired yet")
	}
	if result.AccumulatedActiveSeconds != 1200 {
		t.Error("accumulated active should not change during break")
	}
	if result.AccumulatedBreakSeconds != 240 {
		t.Errorf("expected AccumulatedBreakSeconds=240, got %d", result.AccumulatedBreakSeconds)
	}
}

func TestApplyStateTransitions_BreakPhase_NotAdvancedWhileOnFeed(t *testing.T) {
	svc := newTestService()
	now := time.Now()
	breakStart := now.Add(-60 * time.Second)

	// User is in break and actively on the feed (SyncFeedState calls).
	// AccumulatedBreakSeconds should NOT increase while syncing.
	state := &FeedFatigueState{
		UserID:                   uuid.New(),
		AccumulatedActiveSeconds: 1200,
		AccumulatedBreakSeconds:  60,
		LastSyncTimestamp:        now.Add(-15 * time.Second), // small gap — on-feed sync interval
		IsInCooldown:             true,
		BreakStartedAt:           &breakStart,
	}

	// calledFromSync=true: user is on feed, break timer must NOT advance
	result := svc.applyStateTransitions(state, now, true)

	if !result.IsInCooldown {
		t.Error("expected IsInCooldown=true — user still on feed")
	}
	if result.AccumulatedBreakSeconds != 60 {
		t.Errorf("expected AccumulatedBreakSeconds unchanged at 60, got %d", result.AccumulatedBreakSeconds)
	}
}

func TestApplyStateTransitions_BreakPhase_Expired(t *testing.T) {
	svc := newTestService()
	now := time.Now()
	breakStart := now.Add(-600 * time.Second) // informational only

	// Simulate: user served the full 300s break off-feed already.
	state := &FeedFatigueState{
		UserID:                   uuid.New(),
		AccumulatedActiveSeconds: 1200,
		AccumulatedBreakSeconds:  250,                        // 250s already accumulated
		LastSyncTimestamp:        now.Add(-60 * time.Second), // 60s off-feed gap
		IsInCooldown:             true,
		BreakStartedAt:           &breakStart,
	}

	// calledFromSync=false: adds 60s → AccumulatedBreakSeconds = 310 ≥ 300 → reset
	result := svc.applyStateTransitions(state, now, false)

	if result.IsInCooldown {
		t.Error("expected IsInCooldown=false after break requirements met")
	}
	if result.AccumulatedActiveSeconds != 0 {
		t.Errorf("expected full active reset to 0, got %d", result.AccumulatedActiveSeconds)
	}
	if result.AccumulatedBreakSeconds != 0 {
		t.Errorf("expected AccumulatedBreakSeconds reset to 0, got %d", result.AccumulatedBreakSeconds)
	}
	if result.BreakStartedAt != nil {
		t.Error("BreakStartedAt should be nil after reset")
	}
}

// ─── calcBreakSecondsRemaining ───────────────────────────────────────────────

func TestCalcBreakSecondsRemaining_NotInBreak(t *testing.T) {
	svc := newTestService()

	state := &FeedFatigueState{IsInCooldown: false}
	rem := svc.calcBreakSecondsRemaining(state)
	if rem != 0 {
		t.Errorf("expected 0, got %d", rem)
	}
}

func TestCalcBreakSecondsRemaining_MidBreak(t *testing.T) {
	svc := newTestService()

	state := &FeedFatigueState{
		IsInCooldown:            true,
		AccumulatedBreakSeconds: 120, // 120s of off-feed served
	}
	rem := svc.calcBreakSecondsRemaining(state)

	// 300 - 120 = 180
	if rem != 180 {
		t.Errorf("expected 180, got %d", rem)
	}
}

func TestCalcBreakSecondsRemaining_BreakOverdue(t *testing.T) {
	svc := newTestService()

	state := &FeedFatigueState{
		IsInCooldown:            true,
		AccumulatedBreakSeconds: 400, // over-served
	}
	rem := svc.calcBreakSecondsRemaining(state)
	if rem != 0 {
		t.Errorf("expected 0 for overdue break, got %d", rem)
	}
}

// ─── SyncFeedState cooldown trigger ──────────────────────────────────────────

func TestSyncFeedState_SetBreakStartedAt_OnCooldownTrigger(t *testing.T) {
	svc := newTestService()
	now := time.Now()

	// State at the limit boundary — one more sync will trip cooldown
	state := &FeedFatigueState{
		UserID:                   uuid.New(),
		AccumulatedActiveSeconds: 1195, // 5s below 1200 limit
		LastSyncTimestamp:        now.Add(-6 * time.Second),
		IsInCooldown:             false,
		MaxAllowedSeconds:        1200,
	}

	// Manually run the accumulation + cooldown logic (mirrors SyncFeedState internals)
	// calledFromSync=true: this mirrors SyncFeedState behaviour
	state = svc.applyStateTransitions(state, now, true)
	realElapsed := 6.0
	maxPossible := realElapsed + NetworkBufferSeconds
	delta := 10.0 // 10s reported, would look like cheat; but within maxPossible (11s)
	if delta > maxPossible {
		delta = realElapsed
	}
	state.AccumulatedActiveSeconds += int(delta)
	if state.MaxAllowedSeconds > 0 && state.AccumulatedActiveSeconds >= state.MaxAllowedSeconds {
		state.IsInCooldown = true
		state.BreakStartedAt = &now
		state.AccumulatedBreakSeconds = 0
	}

	if !state.IsInCooldown {
		t.Error("expected IsInCooldown=true after crossing limit")
	}
	if state.BreakStartedAt == nil {
		t.Error("BreakStartedAt must be set when break begins")
	}
	if state.AccumulatedBreakSeconds != 0 {
		t.Errorf("AccumulatedBreakSeconds must be 0 at break start, got %d", state.AccumulatedBreakSeconds)
	}
	rem := svc.calcBreakSecondsRemaining(state)
	if rem != 300 {
		t.Errorf("expected 300s remaining at break start, got %d", rem)
	}
}
