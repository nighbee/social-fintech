package chat

import (
	"context"
	"testing"
	"time"

	"github.com/brightbund-backend/internal/modules/settings"
)

type stubRepo struct {
	conversation Conversation
	participants []string
	message      Message
}

func (s *stubRepo) EnsureDirectConversation(ctx context.Context, actorID, recipientID string, asRequest bool) (*Conversation, error) {
	c := s.conversation
	if c.ID == "" {
		status := RequestStatusAccepted
		if asRequest {
			status = RequestStatusPending
		}
		c = Conversation{ID: "conv-1", Kind: ConversationKindDirect, RequestStatus: status}
	}
	return &c, nil
}

func (s *stubRepo) EnsureTaskConversation(ctx context.Context, taskID, creatorID, helperID string) (*Conversation, error) {
	c := s.conversation
	if c.ID == "" {
		c = Conversation{ID: "conv-task", Kind: ConversationKindTask}
	}
	return &c, nil
}

func (s *stubRepo) GetConversation(ctx context.Context, conversationID, userID string) (*Conversation, error) {
	c := s.conversation
	if c.ID == "" {
		c = Conversation{ID: conversationID, Kind: ConversationKindDirect}
	}
	return &c, nil
}

func (s *stubRepo) ListConversations(ctx context.Context, userID string, cursor *time.Time, limit int) ([]Conversation, error) {
	return nil, nil
}

func (s *stubRepo) ListMessages(ctx context.Context, conversationID, userID string, cursor *time.Time, limit int) ([]Message, error) {
	return nil, nil
}

func (s *stubRepo) CreateMessage(ctx context.Context, params CreateMessageParams) (*Message, bool, error) {
	msg := s.message
	if msg.ID == "" {
		senderID := params.SenderID
		msg = Message{
			ID:             "msg-1",
			ConversationID: params.ConversationID,
			SenderID:       senderID,
			MessageType:    params.MessageType,
			Body:           params.Body,
		}
	}
	return &msg, true, nil
}

func (s *stubRepo) MarkConversationRead(ctx context.Context, conversationID, userID string, lastReadMessageID *string) (*time.Time, error) {
	now := time.Now().UTC()
	return &now, nil
}

func (s *stubRepo) IsMember(ctx context.Context, conversationID, userID string) (bool, error) {
	return true, nil
}

func (s *stubRepo) ListConversationParticipants(ctx context.Context, conversationID string) ([]string, error) {
	if len(s.participants) == 0 {
		return []string{"u1", "u2"}, nil
	}
	return s.participants, nil
}

func (s *stubRepo) IsAlly(ctx context.Context, userID, targetID string) (bool, error) {
	return false, nil
}

func (s *stubRepo) GetMessageKeywords(ctx context.Context, userID string) ([]string, error) {
	return nil, nil
}

func (s *stubRepo) GetOtherParticipantReadAt(ctx context.Context, conversationID, viewerID string) (*time.Time, error) {
	return nil, nil
}

func (s *stubRepo) DeleteMessageForBoth(ctx context.Context, messageID, userID string) error {
	return nil
}

func (s *stubRepo) DeleteMessageForMe(ctx context.Context, messageID, userID string) error {
	return nil
}

func (s *stubRepo) ClearConversationForMe(ctx context.Context, conversationID, userID string) error {
	return nil
}

func (s *stubRepo) DeleteConversationForBoth(ctx context.Context, conversationID string) error {
	return nil
}

func (s *stubRepo) UpdateConversationPin(ctx context.Context, conversationID, userID string, isPinned bool) error {
	return nil
}

func (s *stubRepo) UpdateConversationMute(ctx context.Context, conversationID, userID string, isMuted bool) error {
	return nil
}

func (s *stubRepo) PinMessageInConversation(ctx context.Context, conversationID, messageID, pinnedByUserID string) error {
	return nil
}

func (s *stubRepo) UnpinMessageInConversation(ctx context.Context, conversationID, messageID string) error {
	return nil
}

func (s *stubRepo) ListPinnedMessages(ctx context.Context, conversationID string) ([]PinnedMessage, error) {
	return []PinnedMessage{}, nil
}

func (s *stubRepo) CountPinnedMessages(ctx context.Context, conversationID string) (int, error) {
	return 0, nil
}

func (s *stubRepo) AcceptChatRequest(ctx context.Context, conversationID, userID string) error {
	return nil
}

func (s *stubRepo) DeclineChatRequest(ctx context.Context, conversationID, userID string) error {
	return nil
}

func (s *stubRepo) GetMessagesWithSenderName(ctx context.Context, ids []string) (map[string]ReplyPreview, error) {
	return nil, nil
}

func (s *stubRepo) GetUserBasicInfo(ctx context.Context, userIDs []string) (map[string]ForwardedUser, error) {
	return nil, nil
}

type stubSettings struct {
	privacyByUser map[string]string
	blocked       bool
}

func (s *stubSettings) GetFeedTimeLimit(ctx context.Context, userID string) (int, error) {
	return 20, nil
}

func (s *stubSettings) GetCommentPrivacy(ctx context.Context, userID string) (string, bool, error) {
	return settings.MessagePrivacyEveryone, false, nil
}

func (s *stubSettings) GetMessagePrivacy(ctx context.Context, userID string) (string, bool, bool, error) {
	if v, ok := s.privacyByUser[userID]; ok {
		return v, true, false, nil
	}
	return settings.MessagePrivacyEveryone, true, false, nil
}

func (s *stubSettings) GetMentionsPrivacy(ctx context.Context, userID string) (string, error) {
	return settings.MessagePrivacyEveryone, nil
}

func (s *stubSettings) IsBlockedBetween(ctx context.Context, actorID, targetID string) (bool, error) {
	return s.blocked, nil
}

func (s *stubSettings) GetNotificationPreferences(ctx context.Context, userID string) (map[string]bool, error) {
	return map[string]bool{}, nil
}

func TestOpenDirectConversationHonorsNoOnePrivacy(t *testing.T) {
	repo := &stubRepo{}
	settingsStub := &stubSettings{
		privacyByUser: map[string]string{"u2": settings.MessagePrivacyNoOne},
	}
	service := NewService(repo, settingsStub, nil, nil)

	_, err := service.OpenDirectConversation(context.Background(), "u1", "u2", false)
	if err == nil || err != ErrMessageNotAllowed {
		t.Fatalf("expected ErrMessageNotAllowed, got %v", err)
	}
}

func TestSendMessageTaskConversationBypassesAlliesOnlyPrivacy(t *testing.T) {
	repo := &stubRepo{
		conversation: Conversation{ID: "task-conv", Kind: ConversationKindTask},
		participants: []string{"creator", "helper"},
	}
	settingsStub := &stubSettings{
		privacyByUser: map[string]string{"creator": settings.MessagePrivacyAlliesOnly},
	}
	service := NewService(repo, settingsStub, nil, nil)

	_, err := service.SendMessage(context.Background(), "helper", "task-conv", &SendMessageRequest{
		Body: "hello",
	})
	if err != nil {
		t.Fatalf("expected task-message send to pass privacy bypass, got %v", err)
	}
}

func TestSendMessageStillBlockedForTaskConversation(t *testing.T) {
	repo := &stubRepo{
		conversation: Conversation{ID: "task-conv", Kind: ConversationKindTask},
		participants: []string{"creator", "helper"},
	}
	settingsStub := &stubSettings{
		privacyByUser: map[string]string{"creator": settings.MessagePrivacyAlliesOnly},
		blocked:       true,
	}
	service := NewService(repo, settingsStub, nil, nil)

	_, err := service.SendMessage(context.Background(), "helper", "task-conv", &SendMessageRequest{
		Body: "hello",
	})
	if err == nil || err != ErrBlockedRelationship {
		t.Fatalf("expected ErrBlockedRelationship, got %v", err)
	}
}

func TestPinMessageSuccess(t *testing.T) {
	repo := &stubRepo{}
	service := NewService(repo, &stubSettings{}, nil, nil)

	err := service.PinMessage(context.Background(), "u1", "conv-1", "msg-1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
}

func TestUnpinMessageSuccess(t *testing.T) {
	repo := &stubRepo{}
	service := NewService(repo, &stubSettings{}, nil, nil)

	err := service.UnpinMessage(context.Background(), "u1", "conv-1", "msg-1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
}

func TestListPinnedMessages(t *testing.T) {
	repo := &stubRepo{}
	service := NewService(repo, &stubSettings{}, nil, nil)

	pins, err := service.ListPinnedMessages(context.Background(), "u1", "conv-1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if pins == nil {
		t.Fatal("expected non-nil slice, got nil")
	}
}

func TestDeleteMessageForMe(t *testing.T) {
	repo := &stubRepo{}
	service := NewService(repo, &stubSettings{}, nil, nil)

	err := service.DeleteMessage(context.Background(), "u1", "conv-1", "msg-1", false)
	if err != nil {
		t.Fatalf("expected no error for delete-for-me, got %v", err)
	}
}

func TestDeleteMessageForBoth(t *testing.T) {
	repo := &stubRepo{}
	service := NewService(repo, &stubSettings{}, nil, nil)

	err := service.DeleteMessage(context.Background(), "u1", "conv-1", "msg-1", true)
	if err != nil {
		t.Fatalf("expected no error for delete-for-both, got %v", err)
	}
}

func TestSetConversationMute(t *testing.T) {
	repo := &stubRepo{}
	service := NewService(repo, &stubSettings{}, nil, nil)

	err := service.SetConversationMute(context.Background(), "u1", "conv-1", true)
	if err != nil {
		t.Fatalf("expected no error for mute, got %v", err)
	}

	err = service.SetConversationMute(context.Background(), "u1", "conv-1", false)
	if err != nil {
		t.Fatalf("expected no error for unmute, got %v", err)
	}
}

func TestSetConversationPin(t *testing.T) {
	repo := &stubRepo{}
	service := NewService(repo, &stubSettings{}, nil, nil)

	err := service.SetConversationPin(context.Background(), "u1", "conv-1", true)
	if err != nil {
		t.Fatalf("expected no error for pin, got %v", err)
	}

	err = service.SetConversationPin(context.Background(), "u1", "conv-1", false)
	if err != nil {
		t.Fatalf("expected no error for unpin, got %v", err)
	}
}

func TestDeleteConversationForMe(t *testing.T) {
	repo := &stubRepo{}
	service := NewService(repo, &stubSettings{}, nil, nil)

	err := service.DeleteConversation(context.Background(), "u1", "conv-1", false)
	if err != nil {
		t.Fatalf("expected no error for delete-conversation-for-me, got %v", err)
	}
}

func TestDeleteConversationForBoth(t *testing.T) {
	repo := &stubRepo{}
	service := NewService(repo, &stubSettings{}, nil, nil)

	err := service.DeleteConversation(context.Background(), "u1", "conv-1", true)
	if err != nil {
		t.Fatalf("expected no error for delete-conversation-for-both, got %v", err)
	}
}

func TestSendMessageWithReplyAndForward(t *testing.T) {
	repo := &stubRepo{}
	service := NewService(repo, &stubSettings{}, nil, nil)

	replyID := "msg-original"
	forwardUserID := "u-original-sender"

	msg, err := service.SendMessage(context.Background(), "u1", "conv-1", &SendMessageRequest{
		Body:                "forwarded text",
		ReplyToMessageID:    &replyID,
		ForwardedFromUserID: &forwardUserID,
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if msg == nil {
		t.Fatal("expected message, got nil")
	}
}
