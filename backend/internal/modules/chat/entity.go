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
	PinnedCount          int        `db:"pinned_count" json:"pinned_count"`
	PinnedMessages       []PinnedMessage `db:"-" json:"pinned_messages,omitempty"`
	IsMuted              bool       `db:"is_muted" json:"is_muted"`
	IsPinned             bool       `db:"is_pinned" json:"is_pinned"`
	ClearedAt            *time.Time `db:"cleared_at" json:"cleared_at,omitempty"`
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
	MediaJSON           []byte         `db:"media" json:"-"`
	Media               []MessageMedia `json:"media"`
	ReplyToMessageID    *string        `db:"reply_to_message_id" json:"reply_to_message_id,omitempty"`
	ForwardedFromUserID *string        `db:"forwarded_from_user_id" json:"forwarded_from_user_id,omitempty"`
	DeletedAt           *time.Time     `db:"deleted_at" json:"deleted_at,omitempty"`
	DeletedByUserID     *string        `db:"deleted_by_user_id" json:"deleted_by_user_id,omitempty"`
	CreatedAt           time.Time      `db:"created_at" json:"created_at"`
	ViewerMessageRead   bool           `json:"viewer_message_read"`
}

type CreateDirectConversationRequest struct {
	RecipientID string `json:"recipient_id"`
}

type SendMessageRequest struct {
	Body                string         `json:"body"`
	Media               []MessageMedia `json:"media"`
	IdempotencyKey      string         `json:"idempotency_key"`
	ReplyToMessageID    *string        `json:"reply_to_message_id,omitempty"`
	ForwardedFromUserID *string        `json:"forwarded_from_user_id,omitempty"`
}

type MarkReadRequest struct {
	LastReadMessageID *string `json:"last_read_message_id,omitempty"`
}

type PinnedMessage struct {
	ID             string    `db:"id" json:"id"`
	ConversationID string    `db:"conversation_id" json:"conversation_id"`
	MessageID      string    `db:"message_id" json:"message_id"`
	PinnedBy       string    `db:"pinned_by" json:"pinned_by"`
	PinnedAt       time.Time `db:"pinned_at" json:"pinned_at"`
	MessageBody    string    `db:"message_body" json:"message_body"`
	SenderID       *string   `db:"sender_id" json:"sender_id,omitempty"`
}

type PinMessageRequest struct {
	MessageID string `json:"message_id"`
}

type UnpinMessageRequest struct {
	MessageID string `json:"message_id"`
}

type ListPinnedMessagesResponse struct {
	Items []PinnedMessage `json:"items"`
}

type DeleteMessageRequest struct {
	ForBoth bool `json:"for_both"`
}

type MuteConversationRequest struct {
	Muted bool `json:"muted"`
}

type PinConversationRequest struct {
	Pinned bool `json:"pinned"`
}

type DeleteConversationRequest struct {
	ForBoth bool `json:"for_both"`
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
	MessageID      string     `json:"message_id,omitempty"`
	ReadByUserID   string     `json:"read_by_user_id,omitempty"`
	ReadAt         *time.Time `json:"read_at,omitempty"`
}

type wsClientCommand struct {
	Type              string  `json:"type"`
	ConversationID    *string `json:"conversation_id,omitempty"`
	LastReadMessageID *string `json:"last_read_message_id,omitempty"`
}
