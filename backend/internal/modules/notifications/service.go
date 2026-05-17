package notifications

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/brightbund-backend/internal/platform/cache"
	"github.com/brightbund-backend/internal/platform/eventbus"
	"github.com/brightbund-backend/internal/platform/logger"
	"go.uber.org/zap"
)

type Service struct {
	repo     Repository
	producer *eventbus.Producer
	cache    *cache.Cache
}

func NewService(repo Repository, producer *eventbus.Producer, cache *cache.Cache) *Service {
	return &Service{repo: repo, producer: producer, cache: cache}
}

// Enqueue persists a notification. Uses Upsert when GroupKey is set (grouped events),
// Insert otherwise. Other modules call this instead of poking the table directly.
func (s *Service) Enqueue(ctx context.Context, in Enqueue) (*Notification, error) {
	if in.UserID == uuid.Nil {
		return nil, fmt.Errorf("notifications: user_id is required")
	}
	if in.Kind == "" || in.Title == "" {
		return nil, fmt.Errorf("notifications: kind and title are required")
	}

	payload := json.RawMessage("{}")
	if in.Payload != nil {
		raw, err := json.Marshal(in.Payload)
		if err != nil {
			return nil, fmt.Errorf("notifications: marshal payload: %w", err)
		}
		payload = raw
	}

	actorIDs := json.RawMessage("[]")
	if len(in.ActorIDs) > 0 {
		raw, err := json.Marshal(in.ActorIDs)
		if err != nil {
			return nil, fmt.Errorf("notifications: marshal actor_ids: %w", err)
		}
		actorIDs = raw
	}

	tab := in.UITab
	if tab == "" {
		tab = UITabSystem
	}

	n := &Notification{
		ID:          uuid.New(),
		UserID:      in.UserID,
		Kind:        in.Kind,
		Title:       in.Title,
		Body:        in.Body,
		Payload:     payload,
		UITab:       tab,
		IsImportant: in.IsImportant,
		BadgeStatus: in.BadgeStatus,
		DeepLink:    in.DeepLink,
		GroupKey:    in.GroupKey,
		ActorIDs:    actorIDs,
		GroupCount:  1,
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}

	var repoErr error
	if in.GroupKey != nil {
		repoErr = s.repo.Upsert(ctx, n)
	} else {
		repoErr = s.repo.Insert(ctx, n)
	}
	if repoErr != nil {
		return nil, repoErr
	}

	if s.producer != nil {
		_ = s.producer.Publish(ctx, eventbus.TypePushDispatch, eventbus.PushNotificationEvent{
			UserID:  in.UserID.String(),
			Title:   in.Title,
			Body:    in.Body,
			Payload: in.Payload,
		})
	}

	return n, nil
}

func (s *Service) NotifyRankingUp(ctx context.Context, userID uuid.UUID, scope, region string, oldPos, newPos int) error {
	if newPos <= 0 || newPos >= oldPos {
		return nil
	}
	body := ""
	if region != "" {
		body = fmt.Sprintf("New position: %d in %s.", newPos, region)
	}
	payload := map[string]any{
		"new_position": newPos,
		"old_position": oldPos,
		"scope":        scope,
		"region":       region,
	}
	enq := Enqueue{
		UserID:  userID,
		Kind:    KindRankingUp,
		Title:   "You moved up in ranking.",
		Body:    body,
		Payload: payload,
	}
	applyMapping("leaderboard.rank_advanced", &enq, payload)
	_, err := s.Enqueue(ctx, enq)
	return err
}

func (s *Service) NotifyMovedUser(ctx context.Context, actorID, movedID uuid.UUID, movedUsername, scope, region string, position int) error {
	location := region
	if location == "" {
		location = scope
	}
	payload := map[string]any{
		"moved_user_id": movedID.String(),
		"username":      movedUsername,
		"position":      position,
		"region":        region,
		"scope":         scope,
	}
	enq := Enqueue{
		UserID:  actorID,
		Kind:    KindMovedUser,
		Title:   fmt.Sprintf("You moved %s to position %d in %s.", movedUsername, position, location),
		Payload: payload,
		UITab:   UITabRank,
	}
	_, err := s.Enqueue(ctx, enq)
	return err
}

func (s *Service) List(ctx context.Context, userID uuid.UUID, tab *UITab, cursor *time.Time, limit int) (*ListResponse, error) {
	items, nextCursor, err := s.repo.List(ctx, userID, tab, cursor, limit)
	if err != nil {
		return nil, err
	}
	unread, err := s.repo.UnreadCount(ctx, userID)
	if err != nil {
		return nil, err
	}
	resp := &ListResponse{Items: items, UnreadCount: unread}
	if nextCursor != nil {
		resp.NextCursor = nextCursor.UTC().Format(time.RFC3339Nano)
	}
	return resp, nil
}

func (s *Service) UnreadCount(ctx context.Context, userID uuid.UUID) (int, error) {
	return s.repo.UnreadCount(ctx, userID)
}

func (s *Service) MarkRead(ctx context.Context, userID, notificationID uuid.UUID) error {
	return s.repo.MarkRead(ctx, userID, notificationID, time.Now().UTC())
}

func (s *Service) MarkAllRead(ctx context.Context, userID uuid.UUID) error {
	return s.repo.MarkAllRead(ctx, userID, time.Now().UTC())
}

// HandleSystemEvent translates a Kafka envelope into a durable inbox row.
// UI metadata (tab, importance, badge, deep link) comes from TopicMappings.
func (s *Service) HandleSystemEvent(ctx context.Context, envelope eventbus.Envelope) error {
	topic := string(envelope.Type)

	switch envelope.Type {
	case eventbus.TypePostLiked:
		var ev eventbus.SocialEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		if ev.ActorID == ev.PostAuthorID {
			return nil
		}
		authorUUID, _ := uuid.Parse(ev.PostAuthorID)
		payload := map[string]any{"post_id": ev.PostID, "actor_id": ev.ActorID}
		enq := Enqueue{
			UserID:   authorUUID,
			Kind:     KindPostLiked,
			Title:    "Someone liked your post",
			Payload:  payload,
			ActorIDs: []string{ev.ActorID},
		}
		applyMapping(topic, &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypePostCommented:
		var ev eventbus.SocialEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		if ev.ActorID == ev.PostAuthorID {
			return nil
		}
		authorUUID, _ := uuid.Parse(ev.PostAuthorID)
		payload := map[string]any{"post_id": ev.PostID, "actor_id": ev.ActorID, "comment_id": ev.CommentID}
		enq := Enqueue{
			UserID:   authorUUID,
			Kind:     KindPostCommented,
			Title:    "Someone commented on your post",
			Body:     ev.CommentText,
			Payload:  payload,
			ActorIDs: []string{ev.ActorID},
		}
		applyMapping(topic, &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypeSealReceived:
		var ev eventbus.EconomyEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		recipientUUID, _ := uuid.Parse(ev.RecipientID)
		payload := map[string]any{"actor_id": ev.ActorID, "amount": ev.Amount, "post_id": ev.PostID}
		enq := Enqueue{
			UserID:   recipientUUID,
			Kind:     KindSealReceived,
			Title:    fmt.Sprintf("You received %d seals!", ev.Amount),
			Payload:  payload,
			ActorIDs: []string{ev.ActorID},
		}
		applyMapping(topic, &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypeTaskAccepted:
		var ev eventbus.TaskEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		helperUUID, _ := uuid.Parse(ev.HelperID)
		payload := map[string]any{"task_id": ev.TaskID, "creator_id": ev.CreatorID}
		enq := Enqueue{
			UserID:  helperUUID,
			Kind:    KindTaskAccepted,
			Title:   "Your task application was accepted!",
			Payload: payload,
		}
		applyMapping(topic, &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypeTaskCompleted:
		var ev eventbus.TaskEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		helperUUID, _ := uuid.Parse(ev.HelperID)
		payload := map[string]any{"task_id": ev.TaskID, "reward": ev.Reward}
		enq := Enqueue{
			UserID:  helperUUID,
			Kind:    KindTaskCompleted,
			Title:   "Task completed! Reward received.",
			Body:    fmt.Sprintf("You earned %d seals.", ev.Reward),
			Payload: payload,
		}
		applyMapping(topic, &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypeMessageReceived:
		var ev eventbus.ChatEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		recipientUUID, _ := uuid.Parse(ev.RecipientID)
		payload := map[string]any{"actor_id": ev.ActorID, "conversation_id": ev.ConversationID}
		enq := Enqueue{
			UserID:  recipientUUID,
			Kind:    KindMessageReceived,
			Title:   "New message",
			Body:    ev.Preview,
			Payload: payload,
			UITab:   UITabActivity,
			DeepLink: fmt.Sprintf("app://chat/%s", ev.ConversationID),
		}
		_, err := s.Enqueue(ctx, enq)
		return err

	default:
		return nil
	}
}

func (s *Service) RegisterDevice(ctx context.Context, userID uuid.UUID, req RegisterDeviceRequest) error {
	token := &DeviceToken{
		UserID:     userID,
		Token:      req.Token,
		Platform:   req.Platform,
		DeviceID:   req.DeviceID,
		AppVersion: req.AppVersion,
		Locale:     req.Locale,
	}
	if err := s.repo.UpsertDeviceToken(ctx, token); err != nil {
		return err
	}
	_ = s.InvalidateTokenCache(ctx, userID)
	return nil
}

func (s *Service) UnregisterDevice(ctx context.Context, token string) error {
	if err := s.repo.DeactivateDeviceToken(ctx, token); err != nil {
		return err
	}
	return nil
}

func (s *Service) GetUserDevices(ctx context.Context, userID uuid.UUID) ([]DeviceToken, error) {
	if s.cache != nil {
		key := fmt.Sprintf("device_tokens:%s", userID.String())
		if cached, err := s.cache.Get(ctx, key); err == nil {
			var tokens []DeviceToken
			if err := json.Unmarshal([]byte(cached), &tokens); err == nil {
				logger.Debug("device token cache hit", zap.String("user_id", userID.String()))
				return tokens, nil
			}
		}
		logger.Debug("device token cache miss", zap.String("user_id", userID.String()))
	}

	tokens, err := s.repo.GetActiveTokensByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}

	if s.cache != nil && len(tokens) > 0 {
		key := fmt.Sprintf("device_tokens:%s", userID.String())
		data, _ := json.Marshal(tokens)
		_ = s.cache.Set(ctx, key, data, 5*time.Minute)
	}

	return tokens, nil
}

func (s *Service) InvalidateTokenCache(ctx context.Context, userID uuid.UUID) error {
	if s.cache == nil {
		return nil
	}
	key := fmt.Sprintf("device_tokens:%s", userID.String())
	return s.cache.Delete(ctx, key)
}

func (s *Service) PublishToRetry(ctx context.Context, platform string, event eventbus.PushNotificationEvent) error {
	event.RetryCount++
	if event.RetryCount > 3 {
		return s.producer.PublishToTopic(ctx, "push.dlq", eventbus.TypePushDispatch, event)
	}

	delay := 30 * time.Second
	if event.RetryCount == 2 {
		delay = 5 * time.Minute
	} else if event.RetryCount == 3 {
		delay = 1 * time.Hour
	}

	deliverAfter := time.Now().Add(delay)
	event.DeliverAfter = &deliverAfter

	topic := fmt.Sprintf("push.%s.retry.%d", platform, event.RetryCount)
	return s.producer.PublishToTopic(ctx, topic, eventbus.TypePushDispatch, event)
}
