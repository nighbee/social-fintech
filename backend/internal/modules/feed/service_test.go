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
	// BreakStartedAt is the authoritative clock. 240s have elapsed since the break began.
	breakStart := now.Add(-240 * time.Second)

	state := &FeedFatigueState{
		UserID:                   uuid.New(),
		AccumulatedActiveSeconds: 1200,
		AccumulatedBreakSeconds:  0,                         // will be overwritten from BreakStartedAt anchor
		LastSyncTimestamp:        now.Add(-5 * time.Second), // irrelevant for break phase now
		IsInCooldown:             true,
		BreakStartedAt:           &breakStart,
	}

	// calledFromSync=false: elapsed from BreakStartedAt = 240s → still < 300, no resolve
	result := svc.applyStateTransitions(state, now, false)

	if !result.IsInCooldown {
		t.Error("expected IsInCooldown=true — break not expired yet")
	}
	if result.AccumulatedActiveSeconds != 1200 {
		t.Error("accumulated active should not change during break")
	}
	// AccumulatedBreakSeconds is SET (not added) from BreakStartedAt elapsed
	if result.AccumulatedBreakSeconds != 240 {
		t.Errorf("expected AccumulatedBreakSeconds=240 (from BreakStartedAt anchor), got %d", result.AccumulatedBreakSeconds)
	}
}

func TestApplyStateTransitions_BreakPhase_ElapsedRefreshedDuringSync(t *testing.T) {
	svc := newTestService()
	now := time.Now()
	// 60s have elapsed since break started.
	breakStart := now.Add(-60 * time.Second)

	state := &FeedFatigueState{
		UserID:                   uuid.New(),
		AccumulatedActiveSeconds: 1200,
		AccumulatedBreakSeconds:  0, // will be overwritten
		LastSyncTimestamp:        now.Add(-15 * time.Second),
		IsInCooldown:             true,
		BreakStartedAt:           &breakStart,
	}

	// calledFromSync=true: AccumulatedBreakSeconds is refreshed from anchor (60s) so the
	// client gets an accurate countdown, but the break is NOT resolved (user still on feed).
	result := svc.applyStateTransitions(state, now, true)

	if !result.IsInCooldown {
		t.Error("expected IsInCooldown=true — break must not resolve during a sync call")
	}
	if result.AccumulatedBreakSeconds != 60 {
		t.Errorf("expected AccumulatedBreakSeconds=60 from anchor, got %d", result.AccumulatedBreakSeconds)
	}
}

func TestApplyStateTransitions_BreakPhase_Expired(t *testing.T) {
	svc := newTestService()
	now := time.Now()
	// 600s (10 min) have elapsed since break started — well past the 300s requirement.
	breakStart := now.Add(-600 * time.Second)

	state := &FeedFatigueState{
		UserID:                   uuid.New(),
		AccumulatedActiveSeconds: 1200,
		AccumulatedBreakSeconds:  0,                         // will be set to 600 from anchor, triggering reset
		LastSyncTimestamp:        now.Add(-5 * time.Second), // irrelevant for break resolution
		IsInCooldown:             true,
		BreakStartedAt:           &breakStart,
	}

	// calledFromSync=false: elapsed = 600 ≥ 300 → full reset
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

// ─── Multi-device exploit: secondary device cannot suppress break ─────────────

// TestBreakProgress_ImmutableToSecondaryDeviceSyncs verifies the core fix:
// a secondary device calling SyncFeedState (calledFromSync=true) repeatedly
// cannot freeze the break countdown, because AccumulatedBreakSeconds is computed
// from the immutable BreakStartedAt anchor — not from LastSyncTimestamp.
func TestBreakProgress_ImmutableToSecondaryDeviceSyncs(t *testing.T) {
	svc := newTestService()
	now := time.Now()
	// Break started 150s ago on Device A.
	breakStart := now.Add(-150 * time.Second)

	// Device B has been keeping LastSyncTimestamp fresh every few seconds.
	// In the old implementation this would cap offFeedSecs near 0, freezing the break.
	state := &FeedFatigueState{
		UserID:                   uuid.New(),
		AccumulatedActiveSeconds: 1200,
		AccumulatedBreakSeconds:  0,
		LastSyncTimestamp:        now.Add(-2 * time.Second), // Device B just synced 2s ago
		IsInCooldown:             true,
		BreakStartedAt:           &breakStart,
	}

	// Simulate Device B calling SyncFeedState (calledFromSync=true).
	result := svc.applyStateTransitions(state, now, true)

	// Break progress must reflect wall-clock elapsed since BreakStartedAt (150s),
	// NOT the tiny LastSyncTimestamp gap (2s) that Device B would cause in the old code.
	if result.AccumulatedBreakSeconds != 150 {
		t.Errorf("expected AccumulatedBreakSeconds=150 (device-agnostic), got %d — secondary device sync must not suppress break", result.AccumulatedBreakSeconds)
	}
	if !result.IsInCooldown {
		t.Error("break should not yet resolve at 150s (need 300s)")
	}
}

// TestBreakProgress_ResolvesRegardlessOfLastSyncTimestamp proves that even when
// LastSyncTimestamp is very recent (Device B was active), the break resolves
// correctly once 300s have elapsed from BreakStartedAt.
func TestBreakProgress_ResolvesRegardlessOfLastSyncTimestamp(t *testing.T) {
	svc := newTestService()
	now := time.Now()
	// 350s have elapsed since break started (past the 300s requirement).
	breakStart := now.Add(-350 * time.Second)

	// Device B kept LastSyncTimestamp almost live — in the old code this would
	// have prevented the break from ever resolving.
	state := &FeedFatigueState{
		UserID:                   uuid.New(),
		AccumulatedActiveSeconds: 1200,
		AccumulatedBreakSeconds:  0,
		LastSyncTimestamp:        now.Add(-1 * time.Second), // Device B was active 1s ago
		IsInCooldown:             true,
		BreakStartedAt:           &breakStart,
	}

	// calledFromSync=false: GetFeedState on return to feed — must resolve.
	result := svc.applyStateTransitions(state, now, false)

	if result.IsInCooldown {
		t.Error("break must resolve after 350s regardless of LastSyncTimestamp")
	}
	if result.AccumulatedActiveSeconds != 0 {
		t.Errorf("expected full active reset to 0, got %d", result.AccumulatedActiveSeconds)
	}
	if result.BreakStartedAt != nil {
		t.Error("BreakStartedAt must be nil after reset")
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
