package chat

import "time"

const (
	ConversationKindDirect = "direct"
	ConversationKindTask   = "task"

	MessageTypeUser   = "user"
	MessageTypeSystem = "system"
)

type Conversation struct {
	ID                   string     `db:"id" json:"id"`
	Kind                 string     `db:"kind" json:"kind"`
	TaskID               *string    `db:"task_id" json:"task_id,omitempty"`
	LastMessageID        *string    `db:"last_message_id" json:"last_message_id,omitempty"`
	LastMessageAt        *time.Time `db:"last_message_at" json:"last_message_at,omitempty"`
	LastMessagePreview   *string    `db:"last_message_preview" json:"last_message_preview,omitempty"`
	LastMessageType      *string    `db:"last_message_type" json:"last_message_type,omitempty"`
	LastMessageSenderID  *string    `db:"last_message_sender_id" json:"last_message_sender_id,omitempty"`
	UnreadCount          int        `db:"unread_count" json:"unread_count"`
	OtherUserID          *string    `db:"other_user_id" json:"other_user_id,omitempty"`
	OtherUsername        *string    `db:"other_username" json:"other_username,omitempty"`
	OtherDisplayName     *string    `db:"other_display_name" json:"other_display_name,omitempty"`
	OtherAvatarURL       *string    `db:"other_avatar_url" json:"other_avatar_url,omitempty"`
	// OtherReputationScore is the conversation partner's lifetime received Gold
	// Seals (whole seals). OtherRankTier is the derived tier string. Both are
	// populated at read time so callers don't need a follow-up /me/rank
	// request per conversation row.
	OtherReputationScore *int       `db:"other_reputation_score" json:"other_reputation_score,omitempty"`
	OtherRankTier        *string    `db:"-" json:"other_rank_tier,omitempty"`
	LastReadAt           *time.Time `db:"last_read_at" json:"last_read_at,omitempty"`
	OtherParticipantRead *time.Time `db:"other_participant_read_at" json:"other_participant_read_at,omitempty"`
	CreatedAt            time.Time  `db:"created_at" json:"created_at"`
	UpdatedAt            time.Time  `db:"updated_at" json:"updated_at"`
}

type MessageMedia struct {
	Type         string `json:"type"`
	URL          string `json:"url"`
	ThumbnailURL string `json:"thumbnail_url,omitempty"`
}

type Message struct {
	ID                string         `db:"id" json:"id"`
	ConversationID    string         `db:"conversation_id" json:"conversation_id"`
	SenderID          *string        `db:"sender_id" json:"sender_id,omitempty"`
	MessageType       string         `db:"message_type" json:"message_type"`
	Body              string         `db:"body" json:"body"`
	MediaJSON         []byte         `db:"media" json:"-"`
	Media             []MessageMedia `json:"media"`
	CreatedAt         time.Time      `db:"created_at" json:"created_at"`
	ViewerMessageRead bool           `json:"viewer_message_read"`
}

type CreateDirectConversationRequest struct {
	RecipientID string `json:"recipient_id"`
}

type SendMessageRequest struct {
	Body           string         `json:"body"`
	Media          []MessageMedia `json:"media"`
	IdempotencyKey string         `json:"idempotency_key"`
}

type MarkReadRequest struct {
	LastReadMessageID *string `json:"last_read_message_id,omitempty"`
}

type ListConversationsResponse struct {
	Items      []Conversation `json:"items"`
	NextCursor string         `json:"next_cursor,omitempty"`
}

type ListMessagesResponse struct {
	Items      []Message `json:"items"`
	NextCursor string    `json:"next_cursor,omitempty"`
}

type RealtimeEnvelope struct {
	Type           string     `json:"type"`
	ConversationID string     `json:"conversation_id,omitempty"`
	Message        *Message   `json:"message,omitempty"`
	ReadByUserID   string     `json:"read_by_user_id,omitempty"`
	ReadAt         *time.Time `json:"read_at,omitempty"`
}

type wsClientCommand struct {
	Type              string  `json:"type"`
	ConversationID    *string `json:"conversation_id,omitempty"`
	LastReadMessageID *string `json:"last_read_message_id,omitempty"`
}
