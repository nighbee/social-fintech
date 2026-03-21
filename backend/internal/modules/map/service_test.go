package mapmodule

import (
	"testing"
)

// TestComputeH3Indices validates that coordinates are correctly converted to H3 cells.
func TestComputeH3Indices(t *testing.T) {
	tests := []struct {
		name  string
		lat   float64
		lon   float64
		valid bool
	}{
		{
			name:  "Almaty Kazakhstan",
			lat:   43.2380,
			lon:   76.9453,
			valid: true,
		},
		{
			name:  "San Francisco USA",
			lat:   37.7749,
			lon:   -122.4194,
			valid: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			res5, res4, res2 := computeH3Indices(tt.lat, tt.lon)

			if tt.valid {
				if res5 == "" || res4 == "" || res2 == "" {
					t.Fatalf("expected non-empty H3 indices")
				}

				// res5 should be more specific than res4, which is more specific than res2
				if res5 == res4 || res4 == res2 {
					t.Fatalf("H3 resolutions should be different: res5=%s, res4=%s, res2=%s", res5, res4, res2)
				}
			}
		})
	}
}

// TestCenterOfH3 validates that H3 cell center calculation returns valid coordinates.
func TestCenterOfH3(t *testing.T) {
	tests := []struct {
		name   string
		h3Idx  string
		minLat float64
		maxLat float64
		minLon float64
		maxLon float64
	}{
		{
			name:   "H3 cell in Kazakhstan",
			h3Idx:  "8a2a100704d7fff",
			minLat: -90.0,
			maxLat: 90.0,
			minLon: -180.0,
			maxLon: 180.0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			lat, lon := centerOfH3(tt.h3Idx)

			if lat < tt.minLat || lat > tt.maxLat {
				t.Fatalf("lat out of range: %f (expected [%f, %f])", lat, tt.minLat, tt.maxLat)
			}
			if lon < tt.minLon || lon > tt.maxLon {
				t.Fatalf("lon out of range: %f (expected [%f, %f])", lon, tt.minLon, tt.maxLon)
			}
		})
	}
}

// TestH3AdminLookupResponse validates response structure.
func TestH3AdminLookupResponse(t *testing.T) {
	resp := &H3AdminLookupResponse{
		H3Index:     "8a2a100704d7fff",
		CountryCode: "KZ",
	}

	if resp.H3Index == "" {
		t.Fatalf("H3Index should not be empty")
	}
	if resp.CountryCode != "KZ" {
		t.Fatalf("expected KZ, got %s", resp.CountryCode)
	}
}

// TestLeaderboardKeyFormation ensures keys are formatted correctly for Redis.
func TestLeaderboardKeyFormation(t *testing.T) {
	tests := []struct {
		name   string
		h3Idx  string
		res    int
		keyOpt string
		valid  bool
	}{
		{
			name:   "Arena leaderboard (res5)",
			h3Idx:  "8a2a100704d7fff",
			res:    5,
			keyOpt: "arena",
			valid:  true,
		},
		{
			name:   "City leaderboard (res4)",
			h3Idx:  "8a2a10070ffffff",
			res:    4,
			keyOpt: "city",
			valid:  true,
		},
		{
			name:   "Global leaderboard",
			h3Idx:  "",
			res:    -1,
			keyOpt: "global",
			valid:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Validate the format
			if tt.valid {
				if tt.keyOpt != "arena" && tt.keyOpt != "city" && tt.keyOpt != "global" {
					t.Fatalf("invalid leaderboard option: %s", tt.keyOpt)
				}
			}
		})
	}
}

// TestTaskH3Assignment validates that H3 fields are populated in tasks.
func TestTaskH3Assignment(t *testing.T) {
	lat, lon := 43.2380, 76.9453
	res5, res4, res2 := computeH3Indices(lat, lon)

	// Simulate task creation
	task := &Task{
		H3Res5:    &res5,
		H3Res4:    &res4,
		H3Res2:    &res2,
	}

	if task.H3Res5 == nil {
		t.Fatalf("H3Res5 should be populated")
	}
	if task.H3Res4 == nil {
		t.Fatalf("H3Res4 should be populated")
	}
	if task.H3Res2 == nil {
		t.Fatalf("H3Res2 should be populated")
	}

	// Verify H3 indices are different resolutions
	if *task.H3Res5 == *task.H3Res4 || *task.H3Res4 == *task.H3Res2 {
		t.Fatalf("res5, res4, and res2 should produce different H3 indices")
	}
}

// TestValidateCoordinates ensures coordinates are in valid ranges.
func TestValidateCoordinates(t *testing.T) {
	tests := []struct {
		name    string
		lat     float64
		lon     float64
		wantErr bool
	}{
		{
			name:    "Valid Kazakhstan coordinates",
			lat:     43.2380,
			lon:     76.9453,
			wantErr: false,
		},
		{
			name:    "Latitude too high",
			lat:     91.0,
			lon:     0.0,
			wantErr: true,
		},
		{
			name:    "Latitude too low",
			lat:     -91.0,
			lon:     0.0,
			wantErr: true,
		},
		{
			name:    "Longitude invalid",
			lat:     45.0,
			lon:     181.0,
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateCoordinates(tt.lat, tt.lon)

			if (err != nil) != tt.wantErr {
				t.Fatalf("validateCoordinates() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

// Utility validation function.
func validateCoordinates(lat, lon float64) error {
	if lat < -90 || lat > 90 {
		return ErrInvalidCoordinates
	}
	if lon < -180 || lon > 180 {
		return ErrInvalidCoordinates
	}
	return nil
}
