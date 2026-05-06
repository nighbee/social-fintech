package seasons

import (
	"testing"
	"time"
)

func TestSeasonForTime(t *testing.T) {
	cases := []struct {
		name     string
		now      time.Time
		wantYear int
		wantHalf int
	}{
		{"jan-1-is-h1", time.Date(2026, time.January, 1, 0, 0, 0, 0, time.UTC), 2026, 1},
		{"june-end-is-h1", time.Date(2026, time.June, 30, 23, 59, 59, 0, time.UTC), 2026, 1},
		{"july-1-is-h2", time.Date(2026, time.July, 1, 0, 0, 0, 0, time.UTC), 2026, 2},
		{"december-end-is-h2", time.Date(2026, time.December, 31, 23, 59, 59, 0, time.UTC), 2026, 2},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			year, half := SeasonForTime(tc.now)
			if year != tc.wantYear || half != tc.wantHalf {
				t.Errorf("SeasonForTime(%v) = (%d, %d), want (%d, %d)",
					tc.now, year, half, tc.wantYear, tc.wantHalf)
			}
		})
	}
}

func TestSeasonWindow(t *testing.T) {
	start, end := SeasonWindow(2026, 1)
	wantStart := time.Date(2026, time.January, 1, 0, 0, 0, 0, time.UTC)
	wantEnd := time.Date(2026, time.July, 1, 0, 0, 0, 0, time.UTC)
	if !start.Equal(wantStart) || !end.Equal(wantEnd) {
		t.Errorf("SeasonWindow(2026, 1) = (%v, %v), want (%v, %v)",
			start, end, wantStart, wantEnd)
	}

	start, end = SeasonWindow(2026, 2)
	wantStart = time.Date(2026, time.July, 1, 0, 0, 0, 0, time.UTC)
	wantEnd = time.Date(2027, time.January, 1, 0, 0, 0, 0, time.UTC)
	if !start.Equal(wantStart) || !end.Equal(wantEnd) {
		t.Errorf("SeasonWindow(2026, 2) = (%v, %v), want (%v, %v)",
			start, end, wantStart, wantEnd)
	}
}

func TestPreviousSeason(t *testing.T) {
	cases := []struct {
		name     string
		now      time.Time
		wantYear int
		wantHalf int
	}{
		{"h1-wraps-to-prev-h2", time.Date(2026, time.February, 14, 12, 0, 0, 0, time.UTC), 2025, 2},
		{"june-30-still-h1", time.Date(2026, time.June, 30, 23, 59, 0, 0, time.UTC), 2025, 2},
		{"july-1-is-h2-prev-is-h1", time.Date(2026, time.July, 1, 0, 0, 0, 0, time.UTC), 2026, 1},
		{"december-end-prev-is-h1", time.Date(2026, time.December, 31, 23, 59, 0, 0, time.UTC), 2026, 1},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			year, half := previousSeason(tc.now)
			if year != tc.wantYear || half != tc.wantHalf {
				t.Errorf("previousSeason(%v) = (%d, %d), want (%d, %d)",
					tc.now, year, half, tc.wantYear, tc.wantHalf)
			}
		})
	}
}
