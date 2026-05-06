package ranks

import (
	"strings"
	"testing"
)

func TestGetRankBySeals(t *testing.T) {
	tests := []struct {
		seals int
		want  string
	}{
		{seals: 0, want: "Pearl"},
		{seals: 5, want: "Pearl"},
		{seals: 9, want: "Pearl"},
		{seals: 10, want: "Moonstone"},
		{seals: 24, want: "Moonstone"},
		{seals: 25, want: "Jade"},
		{seals: 50, want: "Jade"},
		{seals: 59, want: "Jade"},
		{seals: 60, want: "Lapis Lazuli"},
		{seals: 100, want: "Lapis Lazuli"},
		{seals: 139, want: "Lapis Lazuli"},
		{seals: 140, want: "Ammolite"},
		{seals: 200, want: "Ammolite"},
		{seals: 259, want: "Ammolite"},
		{seals: 260, want: "Onyx"},
		{seals: 500, want: "Onyx"},
		{seals: 699, want: "Onyx"},
		{seals: 700, want: "Supernova"},
		{seals: 5000, want: "Supernova"},
	}

	for _, tt := range tests {
		rank := GetRankBySeals(tt.seals)
		if rank.Name != tt.want {
			t.Errorf("GetRankBySeals(%d) = %q, want %q", tt.seals, rank.Name, tt.want)
		}
	}
}

func TestCalculateRankAndLevel(t *testing.T) {
	tests := []struct {
		seals     int
		wantRank  string
		wantLevel string
	}{
		{seals: 0, wantRank: "Pearl", wantLevel: "C"},
		{seals: 2, wantRank: "Pearl", wantLevel: "C"},
		{seals: 3, wantRank: "Pearl", wantLevel: "B"},
		{seals: 5, wantRank: "Pearl", wantLevel: "A"},
		{seals: 7, wantRank: "Pearl", wantLevel: "A"},
		{seals: 8, wantRank: "Pearl", wantLevel: "S"},
		{seals: 9, wantRank: "Pearl", wantLevel: "S"},
		{seals: 10, wantRank: "Moonstone", wantLevel: "C"},
		{seals: 14, wantRank: "Moonstone", wantLevel: "B"},
		{seals: 18, wantRank: "Moonstone", wantLevel: "A"},
		{seals: 22, wantRank: "Moonstone", wantLevel: "S"},
		{seals: 24, wantRank: "Moonstone", wantLevel: "S"},
		{seals: 25, wantRank: "Jade", wantLevel: "C"},
		{seals: 34, wantRank: "Jade", wantLevel: "B"},
		{seals: 43, wantRank: "Jade", wantLevel: "A"},
		{seals: 52, wantRank: "Jade", wantLevel: "S"},
		{seals: 59, wantRank: "Jade", wantLevel: "S"},
		{seals: 60, wantRank: "Lapis Lazuli", wantLevel: "C"},
		{seals: 80, wantRank: "Lapis Lazuli", wantLevel: "B"},
		{seals: 100, wantRank: "Lapis Lazuli", wantLevel: "A"},
		{seals: 120, wantRank: "Lapis Lazuli", wantLevel: "S"},
		{seals: 139, wantRank: "Lapis Lazuli", wantLevel: "S"},
		{seals: 140, wantRank: "Ammolite", wantLevel: "C"},
		{seals: 170, wantRank: "Ammolite", wantLevel: "B"},
		{seals: 200, wantRank: "Ammolite", wantLevel: "A"},
		{seals: 230, wantRank: "Ammolite", wantLevel: "S"},
		{seals: 259, wantRank: "Ammolite", wantLevel: "S"},
		{seals: 260, wantRank: "Onyx", wantLevel: "C"},
		{seals: 370, wantRank: "Onyx", wantLevel: "B"},
		{seals: 480, wantRank: "Onyx", wantLevel: "A"},
		{seals: 590, wantRank: "Onyx", wantLevel: "S"},
		{seals: 699, wantRank: "Onyx", wantLevel: "S"},
		{seals: 700, wantRank: "Supernova", wantLevel: "C"},
		{seals: 5000, wantRank: "Supernova", wantLevel: "C"},
	}

	for _, tt := range tests {
		rank, level, _, _ := CalculateRankAndLevel(tt.seals)
		if rank.Name != tt.wantRank || level != tt.wantLevel {
			t.Errorf("CalculateRankAndLevel(%d) = (%q, %q), want (%q, %q)",
				tt.seals, rank.Name, level, tt.wantRank, tt.wantLevel)
		}
	}
}

func TestFormatRankTitle(t *testing.T) {
	tests := []struct {
		rank    string
		quality string
		level   string
		want    string
	}{
		{rank: "Pearl", quality: "Awareness", level: "C", want: "Pearl | Awareness | C"},
		{rank: "Moonstone", quality: "Intention", level: "B", want: "Moonstone | Intention | B"},
		{rank: "Supernova", quality: "Sovereign", level: "S", want: "Supernova | Sovereign | S"},
	}

	for _, tt := range tests {
		got := FormatRankTitle(tt.rank, tt.quality, tt.level)
		if got != tt.want {
			t.Errorf("FormatRankTitle(%q, %q, %q) = %q, want %q",
				tt.rank, tt.quality, tt.level, got, tt.want)
		}
	}
}

func TestGetAllRanksWithLevels(t *testing.T) {
	ranks := GetAllRanksWithLevels()

	if len(ranks) != 7 {
		t.Fatalf("GetAllRanksWithLevels() returned %d ranks, want 7", len(ranks))
	}

	for _, rank := range ranks {
		if len(rank.SubLevels) != 4 {
			t.Errorf("Rank %s has %d sub-levels, want 4", rank.Name, len(rank.SubLevels))
		}

		levels := []string{"C", "B", "A", "S"}
		for i, subLevel := range rank.SubLevels {
			if subLevel.Level != levels[i] {
				t.Errorf("Rank %s sub-level %d = %q, want %q",
					rank.Name, i, subLevel.Level, levels[i])
			}
		}
	}
}

func TestRankCatalogOrder(t *testing.T) {
	expectedNames := []string{"Pearl", "Moonstone", "Jade", "Lapis Lazuli", "Ammolite", "Onyx", "Supernova"}
	expectedQualities := []string{"Awareness", "Intention", "Discipline", "Influence", "Fortitude", "Transcendence", "Sovereign"}

	if len(RankCatalog) != 7 {
		t.Fatalf("RankCatalog has %d ranks, want 7", len(RankCatalog))
	}

	for i, rank := range RankCatalog {
		if rank.Name != expectedNames[i] {
			t.Errorf("RankCatalog[%d].Name = %q, want %q", i, rank.Name, expectedNames[i])
		}
		if rank.Quality != expectedQualities[i] {
			t.Errorf("RankCatalog[%d].Quality = %q, want %q", i, rank.Quality, expectedQualities[i])
		}
		if rank.Order != i+1 {
			t.Errorf("RankCatalog[%d].Order = %d, want %d", i, rank.Order, i+1)
		}
		if !strings.HasPrefix(rank.IconURL, "/assets/ranks/") {
			t.Errorf("RankCatalog[%d].IconURL = %q, want prefix '/assets/ranks/'", i, rank.IconURL)
		}
	}
}

func TestRankBoundaries(t *testing.T) {
	expectedBoundaries := []struct {
		name     string
		minSeals int
		maxSeals int
	}{
		{"Pearl", 0, 10},
		{"Moonstone", 10, 25},
		{"Jade", 25, 60},
		{"Lapis Lazuli", 60, 140},
		{"Ammolite", 140, 260},
		{"Onyx", 260, 700},
		{"Supernova", 700, 999999},
	}

	for i, rank := range RankCatalog {
		expected := expectedBoundaries[i]
		if rank.MinSeals != expected.minSeals {
			t.Errorf("%s.MinSeals = %d, want %d", rank.Name, rank.MinSeals, expected.minSeals)
		}
		if rank.MaxSeals != expected.maxSeals {
			t.Errorf("%s.MaxSeals = %d, want %d", rank.Name, rank.MaxSeals, expected.maxSeals)
		}
	}
}
