package mapmodule

import (
	"testing"
	"time"
)

func TestPickChampionUserID_UsesFallbackWhenNoTies(t *testing.T) {
	got := pickChampionUserID("b-user", nil, nil, nil)
	if got != "b-user" {
		t.Fatalf("expected fallback user, got %q", got)
	}
}

func TestPickChampionUserID_PicksEarliestFirstSeen(t *testing.T) {
	ties := []string{
		"c-user",
		"a-user",
		"b-user",
	}
	firstSeen := map[string]int64{
		"c-user": 300,
		"a-user": 200,
		"b-user": 100,
	}
	got := pickChampionUserID("z-user", ties, firstSeen, nil)
	if got != "b-user" {
		t.Fatalf("expected earliest first-seen user, got %q", got)
	}
}

func TestPickChampionUserID_FallsBackToOldestAccountWhenNoFirstSeen(t *testing.T) {
	createdAt := map[string]time.Time{
		"c-user": time.Date(2026, 3, 20, 10, 0, 0, 0, time.UTC),
		"a-user": time.Date(2026, 3, 18, 10, 0, 0, 0, time.UTC),
		"b-user": time.Date(2026, 3, 19, 10, 0, 0, 0, time.UTC),
	}
	got := pickChampionUserID("z-user", []string{
		"c-user",
		"a-user",
		"b-user",
	}, nil, createdAt)
	if got != "a-user" {
		t.Fatalf("expected oldest account user, got %q", got)
	}
}
