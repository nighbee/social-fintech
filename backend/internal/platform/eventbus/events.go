package eventbus

import (
	"encoding/json"
	"time"
)

// EventType defines the type of event happening in the system.
type EventType string

const (
	TypePostLiked       EventType = "social.post_liked"
	TypePostCommented   EventType = "social.post_commented"
	TypeSealReceived    EventType = "economy.seal_received"
	TypeTaskApplied     EventType = "task.applied"
	TypeTaskAccepted    EventType = "task.accepted"
	TypeTaskCompleted   EventType = "task.completed"
	TypeMessageReceived EventType = "chat.message_received"
	TypeIAPReceived     EventType = "payment.iap_received"
)

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

// Envelope wraps any event with its metadata for Kafka transport.
type Envelope struct {
	Type      EventType       `json:"type"`
	Payload   json.RawMessage `json:"payload"`
	Version   string          `json:"version"`
	CreatedAt time.Time       `json:"created_at"`
}
