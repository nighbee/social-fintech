package mapmodule

import "testing"

func TestPickChampionUserID_UsesFallbackWhenNoTies(t *testing.T) {
	got := pickChampionUserID("b-user", nil, nil)
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
	got := pickChampionUserID("z-user", ties, firstSeen)
	if got != "b-user" {
		t.Fatalf("expected earliest first-seen user, got %q", got)
	}
}

func TestPickChampionUserID_FallsBackToLexicographicWhenNoFirstSeen(t *testing.T) {
	got := pickChampionUserID("z-user", []string{
		"c-user",
		"a-user",
		"b-user",
	}, nil)
	if got != "a-user" {
		t.Fatalf("expected lexicographically smallest user, got %q", got)
	}
}
