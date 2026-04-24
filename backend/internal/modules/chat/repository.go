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
	EnsureDirectConversation(ctx context.Context, actorID, recipientID string) (*Conversation, error)
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
	IdempotencyKey     string
	RequestFingerprint string
}

func (r *PostgresRepository) EnsureDirectConversation(ctx context.Context, actorID, recipientID string) (*Conversation, error) {
	dKey := directPairKey(actorID, recipientID)

	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	if _, err := tx.ExecContext(ctx, `
		INSERT INTO chat_conversations(kind, direct_key, created_by, created_at, updated_at)
		VALUES ($1, $2, $3, NOW(), NOW())
		ON CONFLICT (kind, direct_key) WHERE task_id IS NULL DO NOTHING
	`, ConversationKindDirect, dKey, actorID); err != nil {
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
			c.id, c.kind, c.task_id, c.last_message_id, c.last_message_at,
			c.last_message_preview, c.last_message_type, c.last_message_sender_id,
			c.created_at, c.updated_at,
			cm.unread_count, cm.last_read_at,
			op.user_id AS other_user_id,
			u.username AS other_username,
			COALESCE(p.display_name, '') AS other_display_name,
			COALESCE(p.avatar_url, '') AS other_avatar_url,
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
	return &item, nil
}

func (r *PostgresRepository) ListConversations(ctx context.Context, userID string, cursor *time.Time, limit int) ([]Conversation, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	const query = `
		SELECT
			c.id, c.kind, c.task_id, c.last_message_id, c.last_message_at,
			c.last_message_preview, c.last_message_type, c.last_message_sender_id,
			c.created_at, c.updated_at,
			cm.unread_count, cm.last_read_at,
			op.user_id AS other_user_id,
			u.username AS other_username,
			COALESCE(p.display_name, '') AS other_display_name,
			COALESCE(p.avatar_url, '') AS other_avatar_url,
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
		WHERE cm.user_id = $1
		  AND ($2::timestamptz IS NULL OR COALESCE(c.last_message_at, c.created_at) < $2)
		ORDER BY COALESCE(c.last_message_at, c.created_at) DESC, c.id DESC
		LIMIT $3
	`

	items := make([]Conversation, 0, limit)
	if err := r.db.SelectContext(ctx, &items, query, userID, cursor, limit); err != nil {
		return nil, err
	}
	return items, nil
}

func (r *PostgresRepository) ListMessages(ctx context.Context, conversationID, userID string, cursor *time.Time, limit int) ([]Message, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	const query = `
		SELECT m.id, m.conversation_id, m.sender_id, m.message_type, m.body, m.media, m.created_at
		FROM chat_messages m
		JOIN chat_conversation_members cm
			ON cm.conversation_id = m.conversation_id
		   AND cm.user_id = $2
		WHERE m.conversation_id = $1
		  AND ($3::timestamptz IS NULL OR m.created_at < $3)
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
		INSERT INTO chat_messages(id, conversation_id, sender_id, message_type, body, media, created_at)
		VALUES ($1, $2, $3, $4, $5, $6::jsonb, NOW())
		RETURNING id, conversation_id, sender_id, message_type, body, media, created_at
	`
	if err := tx.GetContext(ctx, &inserted, insertMessageSQL,
		messageID, params.ConversationID, params.SenderID, params.MessageType, params.Body, string(mediaBytes),
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
		SELECT id, conversation_id, sender_id, message_type, body, media, created_at
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
