package mapmodule

import "testing"

func TestPickChampionUserID_UsesFallbackWhenNoTies(t *testing.T) {
	got := pickChampionUserID("b-user", nil)
	if got != "b-user" {
		t.Fatalf("expected fallback user, got %q", got)
	}
}

func TestPickChampionUserID_PicksLexicographicallySmallest(t *testing.T) {
	got := pickChampionUserID("z-user", []string{
		"c-user",
		"a-user",
		"b-user",
	})
	if got != "a-user" {
		t.Fatalf("expected lexicographically smallest user, got %q", got)
	}
}
