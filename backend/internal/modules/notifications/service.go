package notifications

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/brightbund-backend/internal/platform/eventbus"
)

type Service struct {
	repo Repository
}

func NewService(repo Repository) *Service {
	return &Service{repo: repo}
}

// Enqueue persists a notification for the user. Other modules call this
// instead of poking the table directly so we have a single place to add
// future side-effects (push delivery, batching, dedupe) later.
func (s *Service) Enqueue(ctx context.Context, in Enqueue) (*Notification, error) {
	if in.UserID == uuid.Nil {
		return nil, fmt.Errorf("notifications: user_id is required")
	}
	if in.Kind == "" || in.Title == "" {
		return nil, fmt.Errorf("notifications: kind and title are required")
	}

	payload := []byte("{}")
	if in.Payload != nil {
		raw, err := json.Marshal(in.Payload)
		if err != nil {
			return nil, fmt.Errorf("notifications: marshal payload: %w", err)
		}
		payload = raw
	}

	n := &Notification{
		ID:        uuid.New(),
		UserID:    in.UserID,
		Kind:      in.Kind,
		Title:     in.Title,
		Body:      in.Body,
		Payload:   payload,
		CreatedAt: time.Now().UTC(),
	}
	if err := s.repo.Insert(ctx, n); err != nil {
		return nil, err
	}
	return n, nil
}

// NotifyRankingUp is a convenience wrapper for the most common event:
// the user climbed the leaderboard. Other producers (map worker, season
// rollover) call this instead of constructing the Enqueue payload by hand.
func (s *Service) NotifyRankingUp(ctx context.Context, userID uuid.UUID, scope, region string, oldPos, newPos int) error {
	if newPos <= 0 || newPos >= oldPos {
		return nil
	}

	title := "You moved up in ranking."
	body := ""
	if region != "" {
		body = fmt.Sprintf("New position: %d in %s.", newPos, region)
	}

	_, err := s.Enqueue(ctx, Enqueue{
		UserID: userID,
		Kind:   KindRankingUp,
		Title:  title,
		Body:   body,
		Payload: map[string]any{
			"new_position": newPos,
			"old_position": oldPos,
			"scope":        scope,
			"region":       region,
		},
	})
	return err
}

// NotifyMovedUser is fired when the *recipient*'s seal pushed someone
// else up the leaderboard. Mirrors the founder spec's
// "You moved [username] to position X in [city/country]." template.
func (s *Service) NotifyMovedUser(ctx context.Context, actorID, movedID uuid.UUID, movedUsername, scope, region string, position int) error {
	location := region
	if location == "" {
		location = scope
	}
	title := fmt.Sprintf("You moved %s to position %d in %s.", movedUsername, position, location)
	_, err := s.Enqueue(ctx, Enqueue{
		UserID: actorID,
		Kind:   KindMovedUser,
		Title:  title,
		Payload: map[string]any{
			"moved_user_id": movedID.String(),
			"username":      movedUsername,
			"position":      position,
			"region":        region,
			"scope":         scope,
		},
	})
	return err
}

func (s *Service) List(ctx context.Context, userID uuid.UUID, cursor *time.Time, limit int) (*ListResponse, error) {
	items, nextCursor, err := s.repo.List(ctx, userID, cursor, limit)
	if err != nil {
		return nil, err
	}
	unread, err := s.repo.UnreadCount(ctx, userID)
	if err != nil {
		return nil, err
	}
	resp := &ListResponse{
		Items:       items,
		UnreadCount: unread,
	}
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

// HandleSystemEvent takes a raw event from the bus and translates it into
// a durable notification for the appropriate user.
func (s *Service) HandleSystemEvent(ctx context.Context, envelope eventbus.Envelope) error {
	switch envelope.Type {
	case eventbus.TypePostLiked:
		var ev eventbus.SocialEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		// Don't notify if user liked their own post
		if ev.ActorID == ev.PostAuthorID {
			return nil
		}
		authorUUID, _ := uuid.Parse(ev.PostAuthorID)
		_, err := s.Enqueue(ctx, Enqueue{
			UserID: authorUUID,
			Kind:   KindPostLiked,
			Title:  "Someone liked your post",
			Payload: map[string]any{
				"post_id":  ev.PostID,
				"actor_id": ev.ActorID,
			},
		})
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
		_, err := s.Enqueue(ctx, Enqueue{
			UserID: authorUUID,
			Kind:   KindPostCommented,
			Title:  "Someone commented on your post",
			Body:   ev.CommentText,
			Payload: map[string]any{
				"post_id":    ev.PostID,
				"actor_id":   ev.ActorID,
				"comment_id": ev.CommentID,
			},
		})
		return err

	case eventbus.TypeSealReceived:
		var ev eventbus.EconomyEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		recipientUUID, _ := uuid.Parse(ev.RecipientID)
		_, err := s.Enqueue(ctx, Enqueue{
			UserID: recipientUUID,
			Kind:   KindSealReceived,
			Title:  fmt.Sprintf("You received %d seals!", ev.Amount),
			Payload: map[string]any{
				"actor_id": ev.ActorID,
				"amount":   ev.Amount,
				"post_id":  ev.PostID,
			},
		})
		return err

	case eventbus.TypeTaskAccepted:
		var ev eventbus.TaskEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		helperUUID, _ := uuid.Parse(ev.HelperID)
		_, err := s.Enqueue(ctx, Enqueue{
			UserID: helperUUID,
			Kind:   KindTaskAccepted,
			Title:  "Your task application was accepted!",
			Payload: map[string]any{
				"task_id":    ev.TaskID,
				"creator_id": ev.CreatorID,
			},
		})
		return err

	case eventbus.TypeTaskCompleted:
		var ev eventbus.TaskEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		helperUUID, _ := uuid.Parse(ev.HelperID)
		_, err := s.Enqueue(ctx, Enqueue{
			UserID: helperUUID,
			Kind:   KindTaskCompleted,
			Title:  "Task completed! Reward received.",
			Body:   fmt.Sprintf("You earned %d seals.", ev.Reward),
			Payload: map[string]any{
				"task_id": ev.TaskID,
				"reward":  ev.Reward,
			},
		})
		return err

	case eventbus.TypeMessageReceived:
		var ev eventbus.ChatEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		recipientUUID, _ := uuid.Parse(ev.RecipientID)
		_, err := s.Enqueue(ctx, Enqueue{
			UserID: recipientUUID,
			Kind:   KindMessageReceived,
			Title:  "New message",
			Body:   ev.Preview,
			Payload: map[string]any{
				"actor_id":        ev.ActorID,
				"conversation_id": ev.ConversationID,
			},
		})
		return err

	default:
		return nil // Ignore unknown events
	}
}
