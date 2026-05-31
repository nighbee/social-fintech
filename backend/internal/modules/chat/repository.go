package chat

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

type Repository interface {
	EnsureDirectConversation(ctx context.Context, actorID, recipientID string, asRequest bool) (*Conversation, error)
	EnsureTaskConversation(ctx context.Context, taskID, creatorID, helperID string) (*Conversation, error)
	GetConversation(ctx context.Context, conversationID, userID string) (*Conversation, error)
	ListConversations(ctx context.Context, userID string, cursor *time.Time, limit int) ([]Conversation, error)
	ListMessages(ctx context.Context, conversationID, userID string, cursor *time.Time, limit int) ([]Message, error)
	CreateMessage(ctx context.Context, params CreateMessageParams) (*Message, bool, error)
	MarkConversationRead(ctx context.Context, conversationID, userID string, lastReadMessageID *string) (*time.Time, error)
	IsMember(ctx context.Context, conversationID, userID string) (bool, error)
	ListConversationParticipants(ctx context.Context, conversationID string) ([]string, error)
	IsAlly(ctx context.Context, userID, targetID string) (bool, error)
	GetMessageKeywords(ctx context.Context, userID string) ([]string, error)
	GetOtherParticipantReadAt(ctx context.Context, conversationID, viewerID string) (*time.Time, error)
	DeleteMessageForBoth(ctx context.Context, messageID, userID string) error
	DeleteMessageForMe(ctx context.Context, messageID, userID string) error
	ClearConversationForMe(ctx context.Context, conversationID, userID string) error
	DeleteConversationForBoth(ctx context.Context, conversationID string) error
	UpdateConversationPin(ctx context.Context, conversationID, userID string, isPinned bool) error
	UpdateConversationMute(ctx context.Context, conversationID, userID string, isMuted bool) error
	PinMessageInConversation(ctx context.Context, conversationID, messageID, pinnedByUserID string) error
	UnpinMessageInConversation(ctx context.Context, conversationID, messageID string) error
	ListPinnedMessages(ctx context.Context, conversationID string) ([]PinnedMessage, error)
	CountPinnedMessages(ctx context.Context, conversationID string) (int, error)
	AcceptChatRequest(ctx context.Context, conversationID, userID string) error
	DeclineChatRequest(ctx context.Context, conversationID, userID string) error
	GetMessagesWithSenderName(ctx context.Context, ids []string) (map[string]ReplyPreview, error)
	GetUserBasicInfo(ctx context.Context, userIDs []string) (map[string]ForwardedUser, error)
}

type PostgresRepository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *PostgresRepository {
	return &PostgresRepository{db: db}
}

type CreateMessageParams struct {
	ConversationID     string
	SenderID           *string
	MessageType        string
	Body               string
	Media              []MessageMedia
	IdempotencyKey      string
	RequestFingerprint  string
	ReplyToMessageID    *string
	ForwardedFromUserID *string
}

func (r *PostgresRepository) EnsureDirectConversation(ctx context.Context, actorID, recipientID string, asRequest bool) (*Conversation, error) {
	dKey := directPairKey(actorID, recipientID)

	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	requestStatus := RequestStatusAccepted
	if asRequest {
		requestStatus = RequestStatusPending
	}

	if _, err := tx.ExecContext(ctx, `
		INSERT INTO chat_conversations(kind, direct_key, created_by, request_status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, NOW(), NOW())
		ON CONFLICT (kind, direct_key) WHERE task_id IS NULL DO NOTHING
	`, ConversationKindDirect, dKey, actorID, requestStatus); err != nil {
		return nil, err
	}

	var conversationID string
	if err := tx.QueryRowContext(ctx, `
		SELECT id
		FROM chat_conversations
		WHERE kind = $1 AND direct_key = $2 AND task_id IS NULL
		LIMIT 1
	`, ConversationKindDirect, dKey).Scan(&conversationID); err != nil {
		return nil, err
	}

	if err := r.ensureMembersTx(ctx, tx, conversationID, actorID, recipientID); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}

	return r.GetConversation(ctx, conversationID, actorID)
}

func (r *PostgresRepository) EnsureTaskConversation(ctx context.Context, taskID, creatorID, helperID string) (*Conversation, error) {
	dKey := directPairKey(creatorID, helperID)

	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	if _, err := tx.ExecContext(ctx, `
		INSERT INTO chat_conversations(kind, direct_key, task_id, created_by, created_at, updated_at)
		VALUES ($1, $2, $3, $4, NOW(), NOW())
		ON CONFLICT (kind, task_id, direct_key) WHERE task_id IS NOT NULL DO NOTHING
	`, ConversationKindTask, dKey, taskID, creatorID); err != nil {
		return nil, err
	}

	var conversationID string
	if err := tx.QueryRowContext(ctx, `
		SELECT id
		FROM chat_conversations
		WHERE kind = $1 AND task_id = $2 AND direct_key = $3
		LIMIT 1
	`, ConversationKindTask, taskID, dKey).Scan(&conversationID); err != nil {
		return nil, err
	}

	if err := r.ensureMembersTx(ctx, tx, conversationID, creatorID, helperID); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}

	return r.GetConversation(ctx, conversationID, creatorID)
}

func (r *PostgresRepository) ensureMembersTx(ctx context.Context, tx *sqlx.Tx, conversationID string, userIDs ...string) error {
	for _, userID := range userIDs {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO chat_conversation_members(conversation_id, user_id, joined_at)
			VALUES ($1, $2, NOW())
			ON CONFLICT (conversation_id, user_id) DO NOTHING
		`, conversationID, userID); err != nil {
			return err
		}
	}
	return nil
}

func (r *PostgresRepository) GetConversation(ctx context.Context, conversationID, userID string) (*Conversation, error) {
	const query = `
		SELECT
			c.id, c.kind, c.task_id, c.request_status, c.last_message_id, c.last_message_at,
			c.last_message_preview, c.last_message_type, c.last_message_sender_id,
			c.created_at, c.updated_at,
			cm.unread_count, cm.last_read_at, cm.is_muted, cm.is_pinned, cm.cleared_at,
			COALESCE((SELECT COUNT(*) FROM chat_pinned_messages pm WHERE pm.conversation_id = c.id), 0)::int AS pinned_count,
			op.user_id AS other_user_id,
			u.username AS other_username,
			COALESCE(p.display_name, '') AS other_display_name,
			COALESCE(p.avatar_url, '') AS other_avatar_url,
			COALESCE(w.total_received_amount / 100, 0)::int AS other_reputation_score,
			op.last_read_at AS other_participant_read_at
		FROM chat_conversations c
		JOIN chat_conversation_members cm
			ON cm.conversation_id = c.id AND cm.user_id = $2
		LEFT JOIN LATERAL (
			SELECT m.user_id, m.last_read_at
			FROM chat_conversation_members m
			WHERE m.conversation_id = c.id
			  AND m.user_id <> $2
			ORDER BY m.joined_at ASC
			LIMIT 1
		) op ON TRUE
		LEFT JOIN users u ON u.id = op.user_id
		LEFT JOIN profiles p ON p.user_id = op.user_id
		LEFT JOIN wallets w ON w.user_id = op.user_id AND w.currency = 'GOLD_SEAL'
		WHERE c.id = $1
		LIMIT 1
	`

	var item Conversation
	if err := r.db.GetContext(ctx, &item, query, conversationID, userID); err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrConversationNotFound
		}
		return nil, err
	}
	fillOtherRankTier(&item)
	return &item, nil
}

func (r *PostgresRepository) ListConversations(ctx context.Context, userID string, cursor *time.Time, limit int) ([]Conversation, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	const query = `
		SELECT
			c.id, c.kind, c.task_id, c.request_status, c.last_message_id, c.last_message_at,
			c.last_message_preview, c.last_message_type, c.last_message_sender_id,
			c.created_at, c.updated_at,
			cm.unread_count, cm.last_read_at, cm.is_muted, cm.is_pinned, cm.cleared_at,
			COALESCE((SELECT COUNT(*) FROM chat_pinned_messages pm WHERE pm.conversation_id = c.id), 0)::int AS pinned_count,
			op.user_id AS other_user_id,
			u.username AS other_username,
			COALESCE(p.display_name, '') AS other_display_name,
			COALESCE(p.avatar_url, '') AS other_avatar_url,
			COALESCE(w.total_received_amount / 100, 0)::int AS other_reputation_score,
			op.last_read_at AS other_participant_read_at
		FROM chat_conversation_members cm
		JOIN chat_conversations c ON c.id = cm.conversation_id
		LEFT JOIN LATERAL (
			SELECT m.user_id, m.last_read_at
			FROM chat_conversation_members m
			WHERE m.conversation_id = c.id
			  AND m.user_id <> $1
			ORDER BY m.joined_at ASC
			LIMIT 1
		) op ON TRUE
		LEFT JOIN users u ON u.id = op.user_id
		LEFT JOIN profiles p ON p.user_id = op.user_id
		LEFT JOIN wallets w ON w.user_id = op.user_id AND w.currency = 'GOLD_SEAL'
		WHERE cm.user_id = $1
		  AND ($2::timestamptz IS NULL OR COALESCE(c.last_message_at, c.created_at) < $2)
		  AND (cm.cleared_at IS NULL OR COALESCE(c.last_message_at, c.created_at) > cm.cleared_at OR cm.is_pinned = true)
		ORDER BY cm.is_pinned DESC, COALESCE(c.last_message_at, c.created_at) DESC, c.id DESC
		LIMIT $3
	`

	items := make([]Conversation, 0, limit)
	if err := r.db.SelectContext(ctx, &items, query, userID, cursor, limit); err != nil {
		return nil, err
	}
	for i := range items {
		fillOtherRankTier(&items[i])
	}
	return items, nil
}

func (r *PostgresRepository) ListMessages(ctx context.Context, conversationID, userID string, cursor *time.Time, limit int) ([]Message, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	const query = `
		SELECT m.id, m.conversation_id, m.sender_id, m.message_type, m.body, m.media,
		       m.reply_to_message_id, m.forwarded_from_user_id, m.deleted_at, m.deleted_by_user_id, m.created_at
		FROM chat_messages m
		JOIN chat_conversation_members cm
			ON cm.conversation_id = m.conversation_id
		   AND cm.user_id = $2
		LEFT JOIN chat_message_deletions md
			ON md.message_id = m.id AND md.user_id = $2
		WHERE m.conversation_id = $1
		  AND ($3::timestamptz IS NULL OR m.created_at < $3)
		  AND (cm.cleared_at IS NULL OR m.created_at > cm.cleared_at)
		  AND md.message_id IS NULL
		ORDER BY m.created_at DESC, m.id DESC
		LIMIT $4
	`

	items := make([]Message, 0, limit)
	if err := r.db.SelectContext(ctx, &items, query, conversationID, userID, cursor, limit); err != nil {
		return nil, err
	}

	for i := range items {
		_ = decodeMessageMedia(&items[i])
	}

	// Return messages oldest->newest for predictable UI append behavior.
	for i, j := 0, len(items)-1; i < j; i, j = i+1, j-1 {
		items[i], items[j] = items[j], items[i]
	}

	return items, nil
}

func (r *PostgresRepository) CreateMessage(ctx context.Context, params CreateMessageParams) (*Message, bool, error) {
	params.IdempotencyKey = strings.TrimSpace(params.IdempotencyKey)

	mediaBytes, err := json.Marshal(params.Media)
	if err != nil {
		return nil, false, err
	}

	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return nil, false, err
	}
	defer tx.Rollback()

	if params.IdempotencyKey != "" && params.SenderID != nil {
		created, existing, existingFingerprint, err := r.reserveIdempotencyTx(ctx, tx, *params.SenderID, params.IdempotencyKey, params.RequestFingerprint)
		if err != nil {
			return nil, false, err
		}
		if !created {
			if existingFingerprint != "" && existingFingerprint != params.RequestFingerprint {
				return nil, false, ErrIdempotencyConflict
			}
			if existing != nil {
				message, err := r.getMessageByIDTx(ctx, tx, *existing)
				if err != nil {
					return nil, false, err
				}
				if err := tx.Commit(); err != nil {
					return nil, false, err
				}
				return message, false, nil
			}
			return nil, false, ErrIdempotencyInProgress
		}
	}

	messageID := uuid.NewString()
	var inserted Message
	const insertMessageSQL = `
		INSERT INTO chat_messages(id, conversation_id, sender_id, message_type, body, media, reply_to_message_id, forwarded_from_user_id, created_at)
		VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7, $8, NOW())
		RETURNING id, conversation_id, sender_id, message_type, body, media, reply_to_message_id, forwarded_from_user_id, deleted_at, deleted_by_user_id, created_at
	`
	if err := tx.GetContext(ctx, &inserted, insertMessageSQL,
		messageID, params.ConversationID, params.SenderID, params.MessageType, params.Body, string(mediaBytes), params.ReplyToMessageID, params.ForwardedFromUserID,
	); err != nil {
		return nil, false, err
	}
	_ = decodeMessageMedia(&inserted)

	preview := buildMessagePreview(params.MessageType, params.Body, params.Media)
	if _, err := tx.ExecContext(ctx, `
		UPDATE chat_conversations
		SET last_message_id = $2,
			last_message_at = $3,
			last_message_preview = $4,
			last_message_type = $5,
			last_message_sender_id = $6,
			updated_at = NOW()
		WHERE id = $1
	`, params.ConversationID, inserted.ID, inserted.CreatedAt, preview, params.MessageType, params.SenderID); err != nil {
		return nil, false, err
	}

	if params.SenderID != nil {
		if _, err := tx.ExecContext(ctx, `
			UPDATE chat_conversation_members
			SET unread_count = unread_count + 1
			WHERE conversation_id = $1 AND user_id <> $2
		`, params.ConversationID, *params.SenderID); err != nil {
			return nil, false, err
		}
	}

	if params.IdempotencyKey != "" && params.SenderID != nil {
		if _, err := tx.ExecContext(ctx, `
			UPDATE chat_message_idempotency_keys
			SET message_id = $3
			WHERE user_id = $1 AND idempotency_key = $2
		`, *params.SenderID, params.IdempotencyKey, inserted.ID); err != nil {
			return nil, false, err
		}
	}

	if err := tx.Commit(); err != nil {
		return nil, false, err
	}
	return &inserted, true, nil
}

func (r *PostgresRepository) reserveIdempotencyTx(
	ctx context.Context,
	tx *sqlx.Tx,
	userID, key, fingerprint string,
) (bool, *string, string, error) {
	res, err := tx.ExecContext(ctx, `
		INSERT INTO chat_message_idempotency_keys(user_id, idempotency_key, request_fingerprint, created_at)
		VALUES ($1, $2, $3, NOW())
		ON CONFLICT (user_id, idempotency_key) DO NOTHING
	`, userID, key, fingerprint)
	if err != nil {
		return false, nil, "", err
	}
	rows, err := res.RowsAffected()
	if err != nil {
		return false, nil, "", err
	}
	if rows > 0 {
		return true, nil, "", nil
	}

	var messageID sql.NullString
	var existingFingerprint string
	if err := tx.QueryRowContext(ctx, `
		SELECT message_id::text, request_fingerprint
		FROM chat_message_idempotency_keys
		WHERE user_id = $1 AND idempotency_key = $2
		FOR UPDATE
	`, userID, key).Scan(&messageID, &existingFingerprint); err != nil {
		return false, nil, "", err
	}

	if messageID.Valid && messageID.String != "" {
		existing := messageID.String
		return false, &existing, existingFingerprint, nil
	}
	return false, nil, existingFingerprint, nil
}

func (r *PostgresRepository) getMessageByIDTx(ctx context.Context, tx *sqlx.Tx, messageID string) (*Message, error) {
	var m Message
	if err := tx.GetContext(ctx, &m, `
		SELECT id, conversation_id, sender_id, message_type, body, media, reply_to_message_id, forwarded_from_user_id, deleted_at, deleted_by_user_id, created_at
		FROM chat_messages
		WHERE id = $1
	`, messageID); err != nil {
		return nil, err
	}
	_ = decodeMessageMedia(&m)
	return &m, nil
}

func (r *PostgresRepository) MarkConversationRead(ctx context.Context, conversationID, userID string, lastReadMessageID *string) (*time.Time, error) {
	if ok, err := r.IsMember(ctx, conversationID, userID); err != nil {
		return nil, err
	} else if !ok {
		return nil, ErrNotConversationMember
	}

	now := time.Now().UTC()
	var readMessageID interface{}
	if lastReadMessageID != nil && strings.TrimSpace(*lastReadMessageID) != "" {
		readMessageID = *lastReadMessageID
	} else {
		var latest sql.NullString
		if err := r.db.QueryRowContext(ctx, `
			SELECT id::text
			FROM chat_messages
			WHERE conversation_id = $1
			ORDER BY created_at DESC, id DESC
			LIMIT 1
		`, conversationID).Scan(&latest); err == nil && latest.Valid {
			readMessageID = latest.String
		}
	}

	if _, err := r.db.ExecContext(ctx, `
		UPDATE chat_conversation_members
		SET unread_count = 0,
			last_read_at = $3,
			last_read_message_id = COALESCE($4, last_read_message_id)
		WHERE conversation_id = $1 AND user_id = $2
	`, conversationID, userID, now, readMessageID); err != nil {
		return nil, err
	}
	return &now, nil
}

func (r *PostgresRepository) IsMember(ctx context.Context, conversationID, userID string) (bool, error) {
	var exists bool
	if err := r.db.GetContext(ctx, &exists, `
		SELECT EXISTS(
			SELECT 1
			FROM chat_conversation_members
			WHERE conversation_id = $1 AND user_id = $2
		)
	`, conversationID, userID); err != nil {
		return false, err
	}
	return exists, nil
}

func (r *PostgresRepository) ListConversationParticipants(ctx context.Context, conversationID string) ([]string, error) {
	items := make([]string, 0, 2)
	if err := r.db.SelectContext(ctx, &items, `
		SELECT user_id::text
		FROM chat_conversation_members
		WHERE conversation_id = $1
		ORDER BY joined_at ASC
	`, conversationID); err != nil {
		return nil, err
	}
	return items, nil
}

func (r *PostgresRepository) IsAlly(ctx context.Context, userID, targetID string) (bool, error) {
	var exists bool
	err := r.db.GetContext(ctx, &exists, `
		SELECT EXISTS(
			SELECT 1
			FROM user_relationships
			WHERE relationship_type = 'ally'
			  AND (
				  (user_id = $1 AND target_user_id = $2)
				  OR
				  (user_id = $2 AND target_user_id = $1)
			  )
		)
	`, userID, targetID)
	return exists, err
}

func (r *PostgresRepository) GetMessageKeywords(ctx context.Context, userID string) ([]string, error) {
	items := make([]string, 0)
	if err := r.db.SelectContext(ctx, &items, `
		SELECT keyword
		FROM message_keyword_filters
		WHERE user_id = $1
		ORDER BY created_at DESC
	`, userID); err != nil {
		// Keep chat readable even if settings tables are unavailable in older snapshots.
		if strings.Contains(strings.ToLower(err.Error()), "does not exist") {
			return items, nil
		}
		return nil, err
	}
	return items, nil
}

func (r *PostgresRepository) GetOtherParticipantReadAt(ctx context.Context, conversationID, viewerID string) (*time.Time, error) {
	var t sql.NullTime
	err := r.db.QueryRowContext(ctx, `
		SELECT m.last_read_at
		FROM chat_conversation_members m
		WHERE m.conversation_id = $1
		  AND m.user_id <> $2
		ORDER BY m.joined_at ASC
		LIMIT 1
	`, conversationID, viewerID).Scan(&t)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if !t.Valid {
		return nil, nil
	}
	readAt := t.Time
	return &readAt, nil
}

func decodeMessageMedia(message *Message) error {
	if len(message.MediaJSON) == 0 {
		message.Media = []MessageMedia{}
		return nil
	}
	var media []MessageMedia
	if err := json.Unmarshal(message.MediaJSON, &media); err != nil {
		return err
	}
	message.Media = media
	return nil
}

func buildMessagePreview(messageType, body string, media []MessageMedia) string {
	if messageType == MessageTypeSystem {
		return trimPreview(body, 120)
	}
	trimmedBody := strings.TrimSpace(body)
	if trimmedBody != "" {
		return trimPreview(trimmedBody, 120)
	}
	if len(media) == 0 {
		return ""
	}
	kindSet := map[string]struct{}{}
	for _, item := range media {
		kindSet[strings.ToLower(strings.TrimSpace(item.Type))] = struct{}{}
	}
	kinds := make([]string, 0, len(kindSet))
	for kind := range kindSet {
		if kind != "" {
			kinds = append(kinds, kind)
		}
	}
	sort.Strings(kinds)
	if len(kinds) == 0 {
		return "[attachment]"
	}
	return "[" + strings.Join(kinds, ", ") + "]"
}

func trimPreview(value string, maxLen int) string {
	if len(value) <= maxLen {
		return value
	}
	return value[:maxLen] + "..."
}

func directPairKey(userA, userB string) string {
	parts := []string{strings.ToLower(strings.TrimSpace(userA)), strings.ToLower(strings.TrimSpace(userB))}
	sort.Strings(parts)
	return fmt.Sprintf("%s:%s", parts[0], parts[1])
}

// ---------------------------------------------------------------------------
// Advanced chat feature repository methods
// ---------------------------------------------------------------------------

// DeleteMessageForBoth soft-deletes a message globally so neither participant sees it.
func (r *PostgresRepository) DeleteMessageForBoth(ctx context.Context, messageID, userID string) error {
	result, err := r.db.ExecContext(ctx, `
		UPDATE chat_messages
		SET deleted_at = NOW(), deleted_by_user_id = $2
		WHERE id = $1 AND deleted_at IS NULL
	`, messageID, userID)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrMessageNotFound
	}
	return nil
}

// DeleteMessageForMe hides a specific message only for the requesting user.
func (r *PostgresRepository) DeleteMessageForMe(ctx context.Context, messageID, userID string) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO chat_message_deletions(message_id, user_id, deleted_at)
		VALUES ($1, $2, NOW())
		ON CONFLICT (message_id, user_id) DO NOTHING
	`, messageID, userID)
	return err
}

// ClearConversationForMe sets cleared_at so the user no longer sees messages before this point.
func (r *PostgresRepository) ClearConversationForMe(ctx context.Context, conversationID, userID string) error {
	result, err := r.db.ExecContext(ctx, `
		UPDATE chat_conversation_members
		SET cleared_at = NOW(), unread_count = 0
		WHERE conversation_id = $1 AND user_id = $2
	`, conversationID, userID)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrNotConversationMember
	}
	return nil
}

// DeleteConversationForBoth sets cleared_at for ALL members, effectively wiping the conversation for everyone.
func (r *PostgresRepository) DeleteConversationForBoth(ctx context.Context, conversationID string) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE chat_conversation_members
		SET cleared_at = NOW(), unread_count = 0
		WHERE conversation_id = $1
	`, conversationID)
	return err
}

// UpdateConversationPin toggles the is_pinned flag for a specific user in a conversation.
func (r *PostgresRepository) UpdateConversationPin(ctx context.Context, conversationID, userID string, isPinned bool) error {
	var pinnedAt interface{}
	if isPinned {
		pinnedAt = time.Now().UTC()
	}
	result, err := r.db.ExecContext(ctx, `
		UPDATE chat_conversation_members
		SET is_pinned = $3, pinned_at = $4
		WHERE conversation_id = $1 AND user_id = $2
	`, conversationID, userID, isPinned, pinnedAt)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrNotConversationMember
	}
	return nil
}

// UpdateConversationMute toggles the is_muted flag for a specific user in a conversation.
func (r *PostgresRepository) UpdateConversationMute(ctx context.Context, conversationID, userID string, isMuted bool) error {
	result, err := r.db.ExecContext(ctx, `
		UPDATE chat_conversation_members
		SET is_muted = $3
		WHERE conversation_id = $1 AND user_id = $2
	`, conversationID, userID, isMuted)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrNotConversationMember
	}
	return nil
}

// PinMessageInConversation adds a pin to the conversation's pin list.
func (r *PostgresRepository) PinMessageInConversation(ctx context.Context, conversationID, messageID, pinnedByUserID string) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO chat_pinned_messages(conversation_id, message_id, pinned_by, pinned_at)
		VALUES ($1, $2, $3, NOW())
		ON CONFLICT (conversation_id, message_id) DO NOTHING
	`, conversationID, messageID, pinnedByUserID)
	return err
}

// UnpinMessageInConversation removes a specific pin from the conversation.
func (r *PostgresRepository) UnpinMessageInConversation(ctx context.Context, conversationID, messageID string) error {
	result, err := r.db.ExecContext(ctx, `
		DELETE FROM chat_pinned_messages
		WHERE conversation_id = $1 AND message_id = $2
	`, conversationID, messageID)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrMessageNotFound
	}
	return nil
}

// ListPinnedMessages returns all pinned messages for a conversation, newest pin first.
func (r *PostgresRepository) ListPinnedMessages(ctx context.Context, conversationID string) ([]PinnedMessage, error) {
	items := make([]PinnedMessage, 0)
	if err := r.db.SelectContext(ctx, &items, `
		SELECT pm.id, pm.conversation_id, pm.message_id, pm.pinned_by, pm.pinned_at,
		       COALESCE(m.body, '') AS message_body, m.sender_id
		FROM chat_pinned_messages pm
		JOIN chat_messages m ON m.id = pm.message_id
		WHERE pm.conversation_id = $1
		  AND m.deleted_at IS NULL
		ORDER BY pm.pinned_at DESC
	`, conversationID); err != nil {
		return nil, err
	}
	return items, nil
}

// CountPinnedMessages returns the number of active pins in a conversation.
func (r *PostgresRepository) CountPinnedMessages(ctx context.Context, conversationID string) (int, error) {
	var count int
	err := r.db.GetContext(ctx, &count, `
		SELECT COUNT(*)
		FROM chat_pinned_messages pm
		JOIN chat_messages m ON m.id = pm.message_id
		WHERE pm.conversation_id = $1
		  AND m.deleted_at IS NULL
	`, conversationID)
	return count, err
}

// AcceptChatRequest marks a pending request as accepted. Only the non-creator member can accept.
func (r *PostgresRepository) AcceptChatRequest(ctx context.Context, conversationID, userID string) error {
	result, err := r.db.ExecContext(ctx, `
		UPDATE chat_conversations
		SET request_status = 'accepted'
		WHERE id = $1
		  AND request_status = 'pending'
		  AND created_by <> $2
		  AND EXISTS (
		      SELECT 1 FROM chat_conversation_members
		      WHERE conversation_id = $1 AND user_id = $2
		  )
	`, conversationID, userID)
	if err != nil {
		return err
	}
	n, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		return ErrRequestAlreadyHandled
	}
	return nil
}

// DeclineChatRequest marks a pending request as declined. Only the non-creator member can decline.
func (r *PostgresRepository) DeclineChatRequest(ctx context.Context, conversationID, userID string) error {
	result, err := r.db.ExecContext(ctx, `
		UPDATE chat_conversations
		SET request_status = 'declined'
		WHERE id = $1
		  AND request_status = 'pending'
		  AND created_by <> $2
		  AND EXISTS (
		      SELECT 1 FROM chat_conversation_members
		      WHERE conversation_id = $1 AND user_id = $2
		  )
	`, conversationID, userID)
	if err != nil {
		return err
	}
	n, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		return ErrRequestAlreadyHandled
	}
	return nil
}

// GetMessagesWithSenderName batch-loads messages by ID and joins sender username for reply previews.
func (r *PostgresRepository) GetMessagesWithSenderName(ctx context.Context, ids []string) (map[string]ReplyPreview, error) {
	if len(ids) == 0 {
		return nil, nil
	}

	query, args, err := sqlx.In(`
		SELECT m.id, m.body, m.sender_id,
		       COALESCE(p.display_name, u.username, '') AS sender_name
		FROM chat_messages m
		LEFT JOIN users u ON u.id = m.sender_id
		LEFT JOIN profiles p ON p.user_id = m.sender_id
		WHERE m.id IN (?)
		  AND m.deleted_at IS NULL
	`, ids)
	if err != nil {
		return nil, err
	}
	query = r.db.Rebind(query)

	type row struct {
		ID         string  `db:"id"`
		Body       string  `db:"body"`
		SenderID   *string `db:"sender_id"`
		SenderName string  `db:"sender_name"`
	}
	var rows []row
	if err := r.db.SelectContext(ctx, &rows, query, args...); err != nil {
		return nil, err
	}

	result := make(map[string]ReplyPreview, len(rows))
	for _, row := range rows {
		result[row.ID] = ReplyPreview{
			ID:         row.ID,
			Body:       row.Body,
			SenderID:   row.SenderID,
			SenderName: row.SenderName,
		}
	}
	return result, nil
}

// GetUserBasicInfo batch-loads username and display_name for forwarded message attribution.
func (r *PostgresRepository) GetUserBasicInfo(ctx context.Context, userIDs []string) (map[string]ForwardedUser, error) {
	if len(userIDs) == 0 {
		return nil, nil
	}

	query, args, err := sqlx.In(`
		SELECT u.id, u.username, COALESCE(p.display_name, '') AS display_name
		FROM users u
		LEFT JOIN profiles p ON p.user_id = u.id
		WHERE u.id IN (?)
	`, userIDs)
	if err != nil {
		return nil, err
	}
	query = r.db.Rebind(query)

	type row struct {
		ID          string `db:"id"`
		Username    string `db:"username"`
		DisplayName string `db:"display_name"`
	}
	var rows []row
	if err := r.db.SelectContext(ctx, &rows, query, args...); err != nil {
		return nil, err
	}

	result := make(map[string]ForwardedUser, len(rows))
	for _, row := range rows {
		result[row.ID] = ForwardedUser{
			ID:          row.ID,
			Username:    row.Username,
			DisplayName: row.DisplayName,
		}
	}
	return result, nil
}
