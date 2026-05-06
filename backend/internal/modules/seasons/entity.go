package seasons

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// Season describes one 6-month ranking period. Half=1 spans Jan 1 → Jun 30
// (UTC), half=2 spans Jul 1 → Dec 31. There are exactly two seasons per
// year and they never overlap.
type Season struct {
	ID         uuid.UUID  `db:"id" json:"id"`
	SeasonYear int        `db:"season_year" json:"season_year"`
	SeasonHalf int        `db:"season_half" json:"season_half"`
	StartsAt   time.Time  `db:"starts_at" json:"starts_at"`
	EndsAt     time.Time  `db:"ends_at" json:"ends_at"`
	ClosedAt   *time.Time `db:"closed_at" json:"closed_at,omitempty"`
	CreatedAt  time.Time  `db:"created_at" json:"created_at"`
}

// CurrentSeasonResponse powers the "season status" widget on the
// profile screen — used to show how long is left in the current
// 6-month window.
type CurrentSeasonResponse struct {
	Season           Season `json:"season"`
	SecondsRemaining int64  `json:"seconds_remaining"`
}

// ArchiveItem is one row of the user's per-season archive.
//
// SealCount stores the number of Gold Seals the user **received** during
// the season (whole seals, not centinels). Per-season "given" seals,
// rank, and level live inside SnapshotPayload so we can extend the
// schema without migrations — see seasons.snapshotProvider for the
// payload shape.
type ArchiveItem struct {
	UserID          uuid.UUID       `db:"user_id" json:"user_id"`
	SeasonID        uuid.UUID       `db:"season_id" json:"season_id"`
	SeasonYear      int             `db:"season_year" json:"season_year"`
	SeasonHalf      int             `db:"season_half" json:"season_half"`
	FinalPosition   *int            `db:"final_position" json:"final_position,omitempty"`
	SealCount       int64           `db:"seal_count" json:"seal_count"`
	Region          string          `db:"region" json:"region,omitempty"`
	Scope           string          `db:"scope" json:"scope,omitempty"`
	SnapshotPayload json.RawMessage `db:"snapshot_payload" json:"snapshot_payload,omitempty" swaggertype:"object"`
	StartsAt        time.Time       `db:"starts_at" json:"starts_at"`
	EndsAt          time.Time       `db:"ends_at" json:"ends_at"`
	CreatedAt       time.Time       `db:"created_at" json:"created_at"`
}

type ArchiveResponse struct {
	Items []ArchiveItem `json:"items"`
}

// SeasonForTime returns the (year, half) that contains `t`. Used by the
// service to answer "which season are we in right now" without a DB
// round-trip.
func SeasonForTime(t time.Time) (year, half int) {
	t = t.UTC()
	year = t.Year()
	if t.Month() <= time.June {
		half = 1
	} else {
		half = 2
	}
	return year, half
}

// SeasonWindow returns the [start, end) UTC time window for a given
// (year, half) pair.
func SeasonWindow(year, half int) (start, end time.Time) {
	switch half {
	case 1:
		start = time.Date(year, time.January, 1, 0, 0, 0, 0, time.UTC)
		end = time.Date(year, time.July, 1, 0, 0, 0, 0, time.UTC)
	case 2:
		start = time.Date(year, time.July, 1, 0, 0, 0, 0, time.UTC)
		end = time.Date(year+1, time.January, 1, 0, 0, 0, 0, time.UTC)
	}
	return start, end
}
