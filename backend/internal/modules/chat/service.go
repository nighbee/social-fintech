package chat

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"regexp"
	"strings"
	"time"

	"github.com/brightbund-backend/internal/modules/settings"
	"github.com/brightbund-backend/internal/platform/eventbus"
	"github.com/brightbund-backend/internal/platform/logger"
	"go.uber.org/zap"
)

type RealtimePublisher interface {
	EmitToUsers(ctx context.Context, userIDs []string, envelope RealtimeEnvelope) error
}

type PushNotifier interface {
	TriggerNewMessage(ctx context.Context, userID string, conversationID string, preview string) error
}

type noopPushNotifier struct{}

func (n *noopPushNotifier) TriggerNewMessage(ctx context.Context, userID string, conversationID string, preview string) error {
	return nil
}

type EventBusNotifier struct {
	producer *eventbus.Producer
}

func NewEventBusNotifier(producer *eventbus.Producer) *EventBusNotifier {
	return &EventBusNotifier{producer: producer}
}

func (n *EventBusNotifier) TriggerNewMessage(ctx context.Context, userID string, conversationID string, preview string) error {
	if n.producer == nil {
		return nil
	}
	// ActorID is not easily available in the TriggerNewMessage signature without refactoring callers.
	// For now we set it empty, but ideally the caller passes it.
	return n.producer.Publish(ctx, eventbus.TypeMessageReceived, eventbus.ChatEvent{
		BaseEvent: eventbus.BaseEvent{
			Type:      eventbus.TypeMessageReceived,
			Timestamp: time.Now(),
		},
		RecipientID:    userID,
		ConversationID: conversationID,
		Preview:        preview,
	})
}

type Service struct {
	repo        Repository
	settingsSvc settings.PublicService
	realtime    RealtimePublisher
	push        PushNotifier
}

func NewService(repo Repository, settingsSvc settings.PublicService, realtime RealtimePublisher, push PushNotifier) *Service {
	if push == nil {
		push = &noopPushNotifier{}
	}
	return &Service{
		repo:        repo,
		settingsSvc: settingsSvc,
		realtime:    realtime,
		push:        push,
	}
}

func (s *Service) SetRealtimePublisher(realtime RealtimePublisher) {
	s.realtime = realtime
}

func (s *Service) OpenDirectConversation(ctx context.Context, actorID, recipientID string) (*Conversation, error) {
	if strings.TrimSpace(actorID) == "" || strings.TrimSpace(recipientID) == "" || actorID == recipientID {
		return nil, ErrInvalidMessage
	}

	if err := s.guardMessagePermission(ctx, actorID, recipientID, false); err != nil {
		return nil, err
	}

	return s.repo.EnsureDirectConversation(ctx, actorID, recipientID)
}

func (s *Service) ListConversations(ctx context.Context, userID, cursor string, limit int) (*ListConversationsResponse, error) {
	var cursorTime *time.Time
	if cursor != "" {
		if t, err := time.Parse(time.RFC3339Nano, cursor); err == nil {
			cursorTime = &t
		}
	}

	items, err := s.repo.ListConversations(ctx, userID, cursorTime, limit+1)
	if err != nil {
		return nil, err
	}

	resp := &ListConversationsResponse{Items: items}
	if len(items) > limit && limit > 0 {
		lastVisible := items[limit-1]
		resp.Items = items[:limit]
		nextAnchor := lastVisible.CreatedAt
		if lastVisible.LastMessageAt != nil {
			nextAnchor = *lastVisible.LastMessageAt
		}
		resp.NextCursor = nextAnchor.UTC().Format(time.RFC3339Nano)
	}
	return resp, nil
}

func (s *Service) ListMessages(ctx context.Context, userID, conversationID, cursor string, limit int) (*ListMessagesResponse, error) {
	var cursorTime *time.Time
	if cursor != "" {
		if t, err := time.Parse(time.RFC3339Nano, cursor); err == nil {
			cursorTime = &t
		}
	}

	conversation, err := s.repo.GetConversation(ctx, conversationID, userID)
	if err != nil {
		return nil, err
	}

	items, err := s.repo.ListMessages(ctx, conversationID, userID, cursorTime, limit+1)
	if err != nil {
		return nil, err
	}

	otherReadAt, err := s.repo.GetOtherParticipantReadAt(ctx, conversationID, userID)
	if err != nil {
		return nil, err
	}

	otherReadEnabled := false
	if conversation.OtherUserID != nil && s.settingsSvc != nil {
		_, readEnabled, _, privacyErr := s.settingsSvc.GetMessagePrivacy(ctx, *conversation.OtherUserID)
		if privacyErr == nil {
			otherReadEnabled = readEnabled
		}
	}

	for i := range items {
		item := &items[i]
		if item.SenderID != nil && *item.SenderID != userID {
			filteredBody, ferr := s.filterBodyForViewer(ctx, userID, item.Body)
			if ferr == nil {
				item.Body = filteredBody
			}
		}

		if item.SenderID != nil && *item.SenderID == userID {
			item.ViewerMessageRead = otherReadEnabled && otherReadAt != nil && !item.CreatedAt.After(*otherReadAt)
		} else {
			item.ViewerMessageRead = true
		}
	}

	resp := &ListMessagesResponse{Items: items}
	if len(items) > limit && limit > 0 {
		resp.Items = items[1:] // page is ordered asc; first item is the oldest anchor.
		resp.NextCursor = items[0].CreatedAt.UTC().Format(time.RFC3339Nano)
	}

	return resp, nil
}

func (s *Service) SendMessage(ctx context.Context, userID, conversationID string, req *SendMessageRequest) (*Message, error) {
	if req == nil {
		return nil, ErrInvalidMessage
	}
	trimmedBody := strings.TrimSpace(req.Body)
	if trimmedBody == "" && len(req.Media) == 0 {
		return nil, ErrInvalidMessage
	}

	idempotencyKey := strings.TrimSpace(req.IdempotencyKey)
	if idempotencyKey != "" && !isValidIdempotencyKey(idempotencyKey) {
		return nil, ErrInvalidIdempotencyKey
	}

	conversation, err := s.repo.GetConversation(ctx, conversationID, userID)
	if err != nil {
		return nil, err
	}

	participants, err := s.repo.ListConversationParticipants(ctx, conversationID)
	if err != nil {
		return nil, err
	}

	recipients := make([]string, 0, len(participants))
	for _, memberID := range participants {
		if memberID == userID {
			continue
		}
		recipients = append(recipients, memberID)

		allowTaskOptIn := conversation.Kind == ConversationKindTask
		if err := s.guardMessagePermission(ctx, userID, memberID, allowTaskOptIn); err != nil {
			return nil, err
		}
	}

	message, created, err := s.repo.CreateMessage(ctx, CreateMessageParams{
		ConversationID:      conversationID,
		SenderID:            &userID,
		MessageType:         MessageTypeUser,
		Body:                trimmedBody,
		Media:               req.Media,
		IdempotencyKey:      idempotencyKey,
		RequestFingerprint:  messageFingerprint(conversationID, trimmedBody, req.Media),
		ReplyToMessageID:    req.ReplyToMessageID,
		ForwardedFromUserID: req.ForwardedFromUserID,
	})
	if err != nil {
		return nil, err
	}

	// Idempotent replay returns stored payload; skip duplicate event emission.
	if created {
		if err := s.emitNewMessage(ctx, recipients, conversationID, message); err != nil {
			logger.Warn("failed to publish realtime chat message", zap.Error(err))
		}
		for _, recipientID := range recipients {
			filteredPreview := message.Body
			if preview, ferr := s.filterBodyForViewer(ctx, recipientID, filteredPreview); ferr == nil {
				filteredPreview = preview
			}
			if err := s.push.TriggerNewMessage(ctx, recipientID, conversationID, trimPreview(filteredPreview, 120)); err != nil {
				logger.Warn("failed to trigger push notification",
					zap.String("recipient_id", recipientID),
					zap.Error(err),
				)
			}
		}
	}

	return message, nil
}

func (s *Service) MarkConversationRead(ctx context.Context, userID, conversationID string, req *MarkReadRequest) (*time.Time, error) {
	var lastReadMessageID *string
	if req != nil {
		lastReadMessageID = req.LastReadMessageID
	}
	readAt, err := s.repo.MarkConversationRead(ctx, conversationID, userID, lastReadMessageID)
	if err != nil {
		return nil, err
	}

	if s.settingsSvc != nil {
		_, readStatusEnabled, _, privacyErr := s.settingsSvc.GetMessagePrivacy(ctx, userID)
		if privacyErr == nil && readStatusEnabled {
			participants, lerr := s.repo.ListConversationParticipants(ctx, conversationID)
			if lerr == nil {
				targets := make([]string, 0, len(participants))
				for _, memberID := range participants {
					if memberID != userID {
						targets = append(targets, memberID)
					}
				}
				if len(targets) > 0 && s.realtime != nil {
					_ = s.realtime.EmitToUsers(ctx, targets, RealtimeEnvelope{
						Type:           "conversation.read",
						ConversationID: conversationID,
						ReadByUserID:   userID,
						ReadAt:         readAt,
					})
				}
			}
		}
	}

	return readAt, nil
}

// OnTaskApplicationAccepted is called from the map domain when creator accepts helper.
func (s *Service) OnTaskApplicationAccepted(ctx context.Context, taskID, creatorID, helperID string) error {
	if strings.TrimSpace(taskID) == "" || strings.TrimSpace(creatorID) == "" || strings.TrimSpace(helperID) == "" {
		return ErrInvalidMessage
	}
	// Block list still has precedence even for acceptance opt-in conversations.
	if err := s.guardBlockedOnly(ctx, creatorID, helperID); err != nil {
		return err
	}

	conversation, err := s.repo.EnsureTaskConversation(ctx, taskID, creatorID, helperID)
	if err != nil {
		return err
	}

	systemBody := "Task application accepted. Coordinate the next steps here."
	message, created, err := s.repo.CreateMessage(ctx, CreateMessageParams{
		ConversationID: conversation.ID,
		SenderID:       nil,
		MessageType:    MessageTypeSystem,
		Body:           systemBody,
		Media:          nil,
	})
	if err != nil {
		return err
	}
	if created {
		recipients, lerr := s.repo.ListConversationParticipants(ctx, conversation.ID)
		if lerr == nil {
			_ = s.emitNewMessage(ctx, recipients, conversation.ID, message)
		}
	}

	return nil
}

// ---------------------------------------------------------------------------
// Advanced chat feature service methods
// ---------------------------------------------------------------------------

// PinMessage adds a message to the conversation's pin list (visible to both users).
// Multiple messages can be pinned; the frontend shows the latest pin at the top
// and cycles through all pins when tapped.
func (s *Service) PinMessage(ctx context.Context, userID, conversationID, messageID string) error {
	if _, err := s.repo.GetConversation(ctx, conversationID, userID); err != nil {
		return err
	}

	if err := s.repo.PinMessageInConversation(ctx, conversationID, messageID, userID); err != nil {
		return err
	}

	participants, err := s.repo.ListConversationParticipants(ctx, conversationID)
	if err == nil && s.realtime != nil {
		_ = s.realtime.EmitToUsers(ctx, participants, RealtimeEnvelope{
			Type:           "message.pinned",
			ConversationID: conversationID,
			MessageID:      messageID,
		})
	}
	return nil
}

// UnpinMessage removes a specific pinned message from the conversation's pin list.
func (s *Service) UnpinMessage(ctx context.Context, userID, conversationID, messageID string) error {
	if _, err := s.repo.GetConversation(ctx, conversationID, userID); err != nil {
		return err
	}

	if err := s.repo.UnpinMessageInConversation(ctx, conversationID, messageID); err != nil {
		return err
	}

	participants, err := s.repo.ListConversationParticipants(ctx, conversationID)
	if err == nil && s.realtime != nil {
		_ = s.realtime.EmitToUsers(ctx, participants, RealtimeEnvelope{
			Type:           "message.unpinned",
			ConversationID: conversationID,
			MessageID:      messageID,
		})
	}
	return nil
}

// ListPinnedMessages returns all pinned messages for a conversation, newest first.
func (s *Service) ListPinnedMessages(ctx context.Context, userID, conversationID string) ([]PinnedMessage, error) {
	if _, err := s.repo.GetConversation(ctx, conversationID, userID); err != nil {
		return nil, err
	}
	return s.repo.ListPinnedMessages(ctx, conversationID)
}

// DeleteMessage deletes a message either for the acting user only or for both participants.
func (s *Service) DeleteMessage(ctx context.Context, userID, conversationID, messageID string, forBoth bool) error {
	if _, err := s.repo.GetConversation(ctx, conversationID, userID); err != nil {
		return err
	}

	if forBoth {
		if err := s.repo.DeleteMessageForBoth(ctx, messageID, userID); err != nil {
			return err
		}
		// Notify both participants so the message disappears in real time.
		participants, err := s.repo.ListConversationParticipants(ctx, conversationID)
		if err == nil && s.realtime != nil {
			_ = s.realtime.EmitToUsers(ctx, participants, RealtimeEnvelope{
				Type:           "message.deleted",
				ConversationID: conversationID,
				MessageID:      messageID,
			})
		}
	} else {
		if err := s.repo.DeleteMessageForMe(ctx, messageID, userID); err != nil {
			return err
		}
		// Only the acting user needs the event (e.g. for multi-device sync).
		if s.realtime != nil {
			_ = s.realtime.EmitToUsers(ctx, []string{userID}, RealtimeEnvelope{
				Type:           "message.deleted",
				ConversationID: conversationID,
				MessageID:      messageID,
			})
		}
	}
	return nil
}

// SetConversationPin toggles the pinned status of a conversation for the acting user.
func (s *Service) SetConversationPin(ctx context.Context, userID, conversationID string, pinned bool) error {
	return s.repo.UpdateConversationPin(ctx, conversationID, userID, pinned)
}

// SetConversationMute toggles the muted status of a conversation for the acting user.
func (s *Service) SetConversationMute(ctx context.Context, userID, conversationID string, muted bool) error {
	return s.repo.UpdateConversationMute(ctx, conversationID, userID, muted)
}

// DeleteConversation clears or deletes a conversation.
// forBoth=false: sets cleared_at for the acting user only ("delete for me").
// forBoth=true: sets cleared_at for all members ("delete for both").
func (s *Service) DeleteConversation(ctx context.Context, userID, conversationID string, forBoth bool) error {
	if _, err := s.repo.GetConversation(ctx, conversationID, userID); err != nil {
		return err
	}

	if forBoth {
		if err := s.repo.DeleteConversationForBoth(ctx, conversationID); err != nil {
			return err
		}
		participants, err := s.repo.ListConversationParticipants(ctx, conversationID)
		if err == nil && s.realtime != nil {
			_ = s.realtime.EmitToUsers(ctx, participants, RealtimeEnvelope{
				Type:           "conversation.deleted",
				ConversationID: conversationID,
			})
		}
	} else {
		if err := s.repo.ClearConversationForMe(ctx, conversationID, userID); err != nil {
			return err
		}
		if s.realtime != nil {
			_ = s.realtime.EmitToUsers(ctx, []string{userID}, RealtimeEnvelope{
				Type:           "conversation.cleared",
				ConversationID: conversationID,
			})
		}
	}
	return nil
}

func (s *Service) emitNewMessage(ctx context.Context, recipients []string, conversationID string, message *Message) error {
	if s.realtime == nil || len(recipients) == 0 || message == nil {
		return nil
	}

	for _, recipientID := range recipients {
		payload := *message
		filteredBody, ferr := s.filterBodyForViewer(ctx, recipientID, payload.Body)
		if ferr == nil {
			payload.Body = filteredBody
		}
		if err := s.realtime.EmitToUsers(ctx, []string{recipientID}, RealtimeEnvelope{
			Type:           "message.new",
			ConversationID: conversationID,
			Message:        &payload,
		}); err != nil {
			return err
		}
	}

	// Sender echoes are important for multi-device sync.
	if message.SenderID != nil {
		if err := s.realtime.EmitToUsers(ctx, []string{*message.SenderID}, RealtimeEnvelope{
			Type:           "message.new",
			ConversationID: conversationID,
			Message:        message,
		}); err != nil {
			return err
		}
	}

	return nil
}

func (s *Service) guardMessagePermission(ctx context.Context, senderID, recipientID string, allowPrivacyBypass bool) error {
	if err := s.guardBlockedOnly(ctx, senderID, recipientID); err != nil {
		return err
	}

	if allowPrivacyBypass || s.settingsSvc == nil {
		return nil
	}

	privacy, _, _, err := s.settingsSvc.GetMessagePrivacy(ctx, recipientID)
	if err != nil {
		return err
	}

	switch privacy {
	case "", settings.MessagePrivacyEveryone:
		return nil
	case settings.MessagePrivacyNoOne:
		return ErrMessageNotAllowed
	case settings.MessagePrivacyAlliesOnly:
		isAlly, allyErr := s.repo.IsAlly(ctx, senderID, recipientID)
		if allyErr != nil {
			return allyErr
		}
		if !isAlly {
			return ErrMessageNotAllowed
		}
		return nil
	default:
		return ErrMessageNotAllowed
	}
}

func (s *Service) guardBlockedOnly(ctx context.Context, senderID, recipientID string) error {
	if s.settingsSvc == nil {
		return nil
	}
	blocked, err := s.settingsSvc.IsBlockedBetween(ctx, senderID, recipientID)
	if err != nil {
		return err
	}
	if blocked {
		return ErrBlockedRelationship
	}
	return nil
}

func (s *Service) filterBodyForViewer(ctx context.Context, viewerID, body string) (string, error) {
	if s.settingsSvc == nil {
		return body, nil
	}
	_, _, safeModeEnabled, err := s.settingsSvc.GetMessagePrivacy(ctx, viewerID)
	if err != nil || !safeModeEnabled {
		return body, err
	}

	keywords, err := s.repo.GetMessageKeywords(ctx, viewerID)
	if err != nil {
		return body, err
	}
	filtered := body
	for _, keyword := range keywords {
		keyword = strings.TrimSpace(keyword)
		if keyword == "" {
			continue
		}
		re := regexp.MustCompile("(?i)" + regexp.QuoteMeta(keyword))
		filtered = re.ReplaceAllStringFunc(filtered, func(matched string) string {
			return strings.Repeat("*", len([]rune(matched)))
		})
	}
	return filtered, nil
}

func isValidIdempotencyKey(key string) bool {
	if len(key) < 8 || len(key) > 128 {
		return false
	}
	for i := 0; i < len(key); i++ {
		ch := key[i]
		isAlphaNum := (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9')
		if isAlphaNum || ch == '-' || ch == '_' || ch == ':' || ch == '.' {
			continue
		}
		return false
	}
	return true
}

func messageFingerprint(conversationID, body string, media []MessageMedia) string {
	payload := struct {
		ConversationID string         `json:"conversation_id"`
		Body           string         `json:"body"`
		Media          []MessageMedia `json:"media"`
	}{
		ConversationID: conversationID,
		Body:           strings.TrimSpace(body),
		Media:          media,
	}
	raw, _ := json.Marshal(payload)
	sum := sha256.Sum256(raw)
	return hex.EncodeToString(sum[:])
}

func mapChatErrToHTTPStatus(err error) int {
	switch {
	case errors.Is(err, ErrConversationNotFound):
		return 404
	case errors.Is(err, ErrMessageNotFound):
		return 404
	case errors.Is(err, ErrNotConversationMember):
		return 403
	case errors.Is(err, ErrMessageNotAllowed), errors.Is(err, ErrBlockedRelationship):
		return 403
	case errors.Is(err, ErrDeletePermissionDenied):
		return 403
	case errors.Is(err, ErrIdempotencyConflict), errors.Is(err, ErrIdempotencyInProgress):
		return 409
	case errors.Is(err, ErrInvalidMessage), errors.Is(err, ErrInvalidIdempotencyKey):
		return 400
	default:
		return 500
	}
}
