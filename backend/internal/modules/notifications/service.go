package notifications

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
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
