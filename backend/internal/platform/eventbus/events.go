package eventbus

import (
	"encoding/json"
	"time"
)

// EventType defines the type of event happening in the system.
type EventType string

const (
	TypePostLiked            EventType = "social.post_liked"
	TypePostCommented        EventType = "social.post_commented"
	TypePostReplied          EventType = "social.post_replied"
	TypeSealReceived         EventType = "economy.seal_received"
	TypeSilverReceived       EventType = "economy.silver_received"
	TypeTaskApplied          EventType = "task.applied"
	TypeTaskAccepted         EventType = "task.accepted"
	TypeTaskCompleted        EventType = "task.completed"
	TypeProofSubmitted       EventType = "task.proof_submitted"
	TypeTaskExpired          EventType = "task.expired"
	TypeVerificationRequired EventType = "task.verification_required"
	TypeRewardDelivered      EventType = "task.reward_delivered"
	TypeMedalIssued          EventType = "achievement.medal_issued"
	TypeRankAdvanced         EventType = "leaderboard.rank_advanced"
	TypeDistrictLeader       EventType = "leaderboard.district_leader"
	TypeTop50                EventType = "leaderboard.top_50"
	TypeSeasonWarning        EventType = "leaderboard.season_warning"
	TypeSeasonResult         EventType = "leaderboard.season_result"
	TypeMessageReceived      EventType = "chat.message_received"
	TypeIAPReceived          EventType = "payment.iap_received"
	TypePaymentConfirmed     EventType = "system.payment_confirmed"
	TypeSecuritySignin       EventType = "system.security_signin"
	TypeProfileVerified      EventType = "system.profile_verified"
	TypePostRejected         EventType = "moderation.post_rejected"
	TypePushDispatch         EventType = "push.dispatch"
)

// PushNotificationEvent is emitted when a push needs to be fanned out.
type PushNotificationEvent struct {
	UserID     string         `json:"user_id"`
	Title      string         `json:"title"`
	Body       string         `json:"body"`
	Payload        map[string]any `json:"payload"`
	Category       string         `json:"category,omitempty"` // e.g., 'social', 'chat', 'economy'
	IdempotencyKey string         `json:"idempotency_key,omitempty"`
	RetryCount     int            `json:"retry_count,omitempty"`
	DeliverAfter   *time.Time     `json:"deliver_after,omitempty"`
}

// BaseEvent contains fields common to all system events.
type BaseEvent struct {
	Type      EventType `json:"type"`
	ActorID   string    `json:"actor_id"` // The user who triggered the action
	Timestamp time.Time `json:"timestamp"`
}

// SocialEvent is used for likes, comments, etc.
type SocialEvent struct {
	BaseEvent
	PostID       string `json:"post_id,omitempty"`
	PostAuthorID string `json:"post_author_id,omitempty"`
	CommentID    string `json:"comment_id,omitempty"`
	CommentText  string `json:"comment_text,omitempty"`
}

// EconomyEvent is used for seal transfers.
type EconomyEvent struct {
	BaseEvent
	RecipientID string `json:"recipient_id"`
	Amount      int    `json:"amount"`
	PostID      string `json:"post_id,omitempty"`
}

// TaskEvent is used for map task lifecycle.
type TaskEvent struct {
	BaseEvent
	TaskID    string `json:"task_id"`
	CreatorID string `json:"creator_id"`
	HelperID  string `json:"helper_id,omitempty"`
	Reward    int    `json:"reward,omitempty"`
}

// ChatEvent is used for direct messages.
type ChatEvent struct {
	BaseEvent
	RecipientID    string `json:"recipient_id"`
	ConversationID string `json:"conversation_id"`
	Preview        string `json:"preview"`
}

// PaymentEvent is used for IAP purchases.
type PaymentEvent struct {
	BaseEvent
	EventID   string  `json:"event_id"`
	ProductID string  `json:"product_id"`
	Amount    int64   `json:"amount"` // Seals amount
	Price     float64 `json:"price"`
	Currency  string  `json:"currency"`
}

// LeaderboardEvent is used for ranking, district, top-50, season events.
type LeaderboardEvent struct {
	BaseEvent
	Scope      string `json:"scope"`
	Region     string `json:"region,omitempty"`
	OldPos     int    `json:"old_position,omitempty"`
	NewPos     int    `json:"new_position,omitempty"`
	SeasonID   string `json:"season_id,omitempty"`
	Tier       string `json:"tier,omitempty"`
	Position   int    `json:"position,omitempty"`
	Seals      int    `json:"seals,omitempty"`
	SilverSent int    `json:"silver_sent,omitempty"`
	GoldHonors int    `json:"gold_honors,omitempty"`
	DaysLeft   int    `json:"days_left,omitempty"`
}

// MedalEvent is used for achievement medal issuance.
type MedalEvent struct {
	BaseEvent
	RecipientID string `json:"recipient_id"`
	MedalName   string `json:"medal_name"`
	MedalDesc   string `json:"medal_desc,omitempty"`
}

// SystemEvent is used for moderation, payment, security, verification.
type SystemEvent struct {
	BaseEvent
	UserID  string `json:"user_id"`
	Details string `json:"details,omitempty"`
	PostID  string `json:"post_id,omitempty"`
}

// Envelope wraps any event with its metadata for Kafka transport.
type Envelope struct {
	Type      EventType       `json:"type"`
	Payload   json.RawMessage `json:"payload"`
	Version   string          `json:"version"`
	CreatedAt time.Time       `json:"created_at"`
}
