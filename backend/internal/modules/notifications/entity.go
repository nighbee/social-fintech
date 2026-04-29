package notifications

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// Kind enumerates the notification types the backend can emit. Add new
// values here and document the payload schema before producing them, so
// frontend renderers can be updated in lockstep.
type Kind string

const (
	// KindRankingUp fires when the user climbs the leaderboard.
	// Payload: { "new_position": int, "old_position": int, "region": string, "scope": "city|region|country" }
	KindRankingUp Kind = "ranking_up"

	// KindMovedUser fires when the user's seal pushed someone *else* up.
	// Payload: { "username": string, "position": int, "scope": "city|country" }
	KindMovedUser Kind = "moved_user"

	// KindSeasonEnd fires once when a 6-month season closes.
	// Payload: { "season_year": int, "season_half": int, "final_position": int, "seals": int, "region": string }
	KindSeasonEnd Kind = "season_end"
)

// Notification is the durable inbox row backing the bell icon.
type Notification struct {
	ID        uuid.UUID       `db:"id" json:"id"`
	UserID    uuid.UUID       `db:"user_id" json:"user_id"`
	Kind      Kind            `db:"kind" json:"kind"`
	Title     string          `db:"title" json:"title"`
	Body      string          `db:"body" json:"body,omitempty"`
	Payload   json.RawMessage `db:"payload" json:"payload"`
	ReadAt    *time.Time      `db:"read_at" json:"read_at,omitempty"`
	CreatedAt time.Time       `db:"created_at" json:"created_at"`
}

// ListResponse pages over the user's inbox.
type ListResponse struct {
	Items      []Notification `json:"items"`
	NextCursor string         `json:"next_cursor,omitempty"`
	UnreadCount int           `json:"unread_count"`
}

// UnreadCountResponse powers the bell icon badge.
type UnreadCountResponse struct {
	Count int `json:"count"`
}

// Enqueue is the canonical helper input used by other modules to fire
// a notification without dealing with JSON marshalling boilerplate.
type Enqueue struct {
	UserID  uuid.UUID
	Kind    Kind
	Title   string
	Body    string
	Payload map[string]any
}
