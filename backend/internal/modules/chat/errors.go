package chat

import "errors"

var (
	ErrConversationNotFound    = errors.New("conversation_not_found")
	ErrMessageNotAllowed       = errors.New("message_not_allowed")
	ErrBlockedRelationship     = errors.New("blocked_relationship")
	ErrInvalidMessage          = errors.New("invalid_message")
	ErrInvalidConversationKind = errors.New("invalid_conversation_kind")
	ErrInvalidIdempotencyKey   = errors.New("invalid_idempotency_key")
	ErrIdempotencyConflict     = errors.New("idempotency_conflict")
	ErrIdempotencyInProgress   = errors.New("idempotency_in_progress")
	ErrNotConversationMember   = errors.New("not_conversation_member")
)
