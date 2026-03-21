package feed

import (
	"errors"
	"testing"
	"time"
)

func TestShouldRestrictPublishing(t *testing.T) {
	now := time.Now()

	tests := []struct {
		name           string
		postRemoved30d int
		lastStrikeAt   time.Time
		expected       bool
	}{
		{
			name:           "below threshold does not restrict",
			postRemoved30d: 2,
			lastStrikeAt:   now.Add(-2 * time.Hour),
			expected:       false,
		},
		{
			name:           "24h window active at level 1",
			postRemoved30d: 3,
			lastStrikeAt:   now.Add(-23 * time.Hour),
			expected:       true,
		},
		{
			name:           "24h window expired at level 1",
			postRemoved30d: 3,
			lastStrikeAt:   now.Add(-25 * time.Hour),
			expected:       false,
		},
		{
			name:           "72h window active at level 2",
			postRemoved30d: 6,
			lastStrikeAt:   now.Add(-(72*time.Hour - time.Minute)),
			expected:       true,
		},
		{
			name:           "72h window expired at level 2",
			postRemoved30d: 6,
			lastStrikeAt:   now.Add(-73 * time.Hour),
			expected:       false,
		},
		{
			name:           "7d window active at level 3",
			postRemoved30d: 9,
			lastStrikeAt:   now.Add(-(7*24*time.Hour - time.Minute)),
			expected:       true,
		},
		{
			name:           "7d window expired at level 3",
			postRemoved30d: 9,
			lastStrikeAt:   now.Add(-(7*24*time.Hour + time.Minute)),
			expected:       false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := shouldRestrictPublishing(tt.postRemoved30d, tt.lastStrikeAt, now); got != tt.expected {
				t.Fatalf("expected %v, got %v", tt.expected, got)
			}
		})
	}
}

func TestStrikeTypeForTarget(t *testing.T) {
	tests := []struct {
		name       string
		targetType string
		expected   string
		err        error
	}{
		{name: "post target", targetType: ReportTargetPost, expected: "post_removed"},
		{name: "comment target", targetType: ReportTargetComment, expected: "comment_removed"},
		{name: "invalid target", targetType: "profile", err: ErrInvalidReportReason},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := strikeTypeForTarget(tt.targetType)
			if !errors.Is(err, tt.err) {
				t.Fatalf("expected err %v, got %v", tt.err, err)
			}
			if got != tt.expected {
				t.Fatalf("expected strike type %q, got %q", tt.expected, got)
			}
		})
	}
}
