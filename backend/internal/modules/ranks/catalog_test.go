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
		{seals: 10, want: "Moonstone"},
		{seals: 20, want: "Moonstone"},
		{seals: 30, want: "Jade"},
		{seals: 50, want: "Jade"},
		{seals: 70, want: "Lapis Lazuli"},
		{seals: 100, want: "Lapis Lazuli"},
		{seals: 170, want: "Ammolite"},
		{seals: 250, want: "Ammolite"},
		{seals: 300, want: "Onyx"},
		{seals: 500, want: "Onyx"},
		{seals: 1000, want: "Supernova"},
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
		{seals: 6, wantRank: "Pearl", wantLevel: "A"},
		{seals: 8, wantRank: "Pearl", wantLevel: "S"},
		{seals: 10, wantRank: "Moonstone", wantLevel: "C"},
		{seals: 15, wantRank: "Moonstone", wantLevel: "B"},
		{seals: 20, wantRank: "Moonstone", wantLevel: "A"},
		{seals: 21, wantRank: "Moonstone", wantLevel: "A"},
		{seals: 26, wantRank: "Moonstone", wantLevel: "S"},
		{seals: 30, wantRank: "Jade", wantLevel: "C"},
		{seals: 50, wantRank: "Jade", wantLevel: "A"},
		{seals: 60, wantRank: "Jade", wantLevel: "S"},
		{seals: 65, wantRank: "Jade", wantLevel: "S"},
		{seals: 70, wantRank: "Lapis Lazuli", wantLevel: "C"},
		{seals: 100, wantRank: "Lapis Lazuli", wantLevel: "B"},
		{seals: 145, wantRank: "Lapis Lazuli", wantLevel: "S"},
		{seals: 170, wantRank: "Ammolite", wantLevel: "C"},
		{seals: 235, wantRank: "Ammolite", wantLevel: "A"},
		{seals: 268, wantRank: "Ammolite", wantLevel: "S"},
		{seals: 300, wantRank: "Onyx", wantLevel: "C"},
		{seals: 650, wantRank: "Onyx", wantLevel: "A"},
		{seals: 900, wantRank: "Onyx", wantLevel: "S"},
		{seals: 1000, wantRank: "Supernova", wantLevel: "C"},
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
		{rank: "Pearl", quality: "Origin", level: "C", want: "Pearl | Origin | C"},
		{rank: "Moonstone", quality: "Clarity", level: "B", want: "Moonstone | Clarity | B"},
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
	expectedQualities := []string{"Origin", "Clarity", "Integrity", "Ascendance", "Fortitude", "Transcendence", "Sovereign"}

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
		{"Moonstone", 10, 30},
		{"Jade", 30, 70},
		{"Lapis Lazuli", 70, 170},
		{"Ammolite", 170, 300},
		{"Onyx", 300, 1000},
		{"Supernova", 1000, 999999},
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
