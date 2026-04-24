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

func (s *stubRepo) EnsureDirectConversation(ctx context.Context, actorID, recipientID string) (*Conversation, error) {
	c := s.conversation
	if c.ID == "" {
		c = Conversation{ID: "conv-1", Kind: ConversationKindDirect}
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

func TestOpenDirectConversationHonorsNoOnePrivacy(t *testing.T) {
	repo := &stubRepo{}
	settingsStub := &stubSettings{
		privacyByUser: map[string]string{"u2": settings.MessagePrivacyNoOne},
	}
	service := NewService(repo, settingsStub, nil, nil)

	_, err := service.OpenDirectConversation(context.Background(), "u1", "u2")
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
