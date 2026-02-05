package economy

import (
	"testing"
	"time"
)

// Mock helpers directly if simple, or just test pure logic functions if extracted.
// Since logic is embedded in service methods which strictly require repo,
// and I don't want to mock the whole repo here without a framework,
// I will verify the decay/cooldown calculation logic by extracting it or simulating it?

// Actually, I can extract the calculation logic to be testable.
// Let's create a small helper test file to test the pure functions I can extract or verify constants.

func TestGetCooldownDuration(t *testing.T) {
	tests := []struct {
		level    int
		expected time.Duration
	}{
		{1, 30 * 24 * time.Hour},
		{2, 45 * 24 * time.Hour},
		{3, 60 * 24 * time.Hour},
		{4, 90 * 24 * time.Hour},
		{5, 120 * 24 * time.Hour},
		{0, 120 * 24 * time.Hour}, // Default
		{6, 120 * 24 * time.Hour}, // Default
	}

	for _, tt := range tests {
		got := getCooldownDuration(tt.level)
		if got != tt.expected {
			t.Errorf("getCooldownDuration(%d) = %v; want %v", tt.level, got, tt.expected)
		}
	}
}

func TestDecayLogic(t *testing.T) {
	// Simulating the decay logic from service.go
	// repeatLevel = cooldown.RepeatLevel
	// if diff >= SealDecayThreshold2 { repeatLevel = max(repeatLevel-2, 1) }
	// else if diff >= SealDecayThreshold1 { repeatLevel = max(repeatLevel-1, 1) }

	tests := []struct {
		name         string
		initialLevel int
		daysPassed   int
		expected     int
	}{
		{"No decay - 30 days", 3, 30, 3},
		{"No decay - 119 days", 3, 119, 3},
		{"Decay 1 level - 120 days", 3, 120, 2},
		{"Decay 1 level - 239 days", 3, 239, 2},
		{"Decay 2 levels - 240 days", 3, 240, 1},
		{"Decay 2 levels - 300 days", 5, 300, 3},
		{"Min level cap at 1", 2, 240, 1},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			diff := time.Duration(tt.daysPassed) * 24 * time.Hour

			level := tt.initialLevel
			if diff >= SealDecayThreshold2 {
				level = max(level-2, 1)
			} else if diff >= SealDecayThreshold1 {
				level = max(level-1, 1)
			}

			if level != tt.expected {
				t.Errorf("DecayLogic(%d days, start level %d) = %d; want %d", tt.daysPassed, tt.initialLevel, level, tt.expected)
			}
		})
	}
}
