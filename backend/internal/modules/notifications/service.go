package notifications

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/brightbund-backend/internal/modules/settings"
	"github.com/brightbund-backend/internal/platform/cache"
	"github.com/brightbund-backend/internal/platform/eventbus"
	"github.com/brightbund-backend/internal/platform/logger"
	"go.uber.org/zap"
)

type Service struct {
	repo            Repository
	producer        *eventbus.Producer
	cache           *cache.Cache
	settingsService settings.PublicService
}

func NewService(repo Repository, producer *eventbus.Producer, cache *cache.Cache) *Service {
	return &Service{repo: repo, producer: producer, cache: cache}
}

func (s *Service) SetSettingsService(svc settings.PublicService) {
	s.settingsService = svc
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

func (s *Service) shouldSendNotification(ctx context.Context, userID uuid.UUID, kind Kind) bool {
	if s.settingsService == nil {
		return true
	}
	prefs, err := s.settingsService.GetNotificationPreferences(ctx, userID.String())
	if err != nil {
		logger.Warn("failed to check notification preferences, defaulting to send", zap.String("user_id", userID.String()), zap.Error(err))
		return true
	}
	enabled, ok := prefs[prefKeyForKind(kind)]
	if !ok {
		return true
	}
	return enabled
}

func prefKeyForKind(k Kind) string {
	switch k {
	case KindSealReceived, KindSilverReceived:
		return "notify_gold_honor"
	case KindMedalIssued:
		return "notify_medal_unlocked"
	case KindRankingUp, KindRankAdvanced, KindDistrictLeader, KindTop50:
		return "notify_rank_increased"
	case KindTaskApplied, KindTaskAccepted, KindTaskCompleted, KindTaskProofSubmitted, KindTaskExpired, KindTaskVerificationNeeded, KindTaskRewardDelivered:
		return "notify_task_updates"
	case KindPostCommented, KindPostReplied:
		return "notify_comments_replies"
	case KindPostLiked:
		return "notify_likes_reactions"
	default:
		return ""
	}
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
	if items == nil {
		items = make([]Notification, 0)
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
		if !s.shouldSendNotification(ctx, authorUUID, KindPostLiked) {
			return nil
		}
		actorName := s.resolveUsername(ctx, ev.ActorID)
		title := "Someone liked your post"
		if actorName != "" {
			title = fmt.Sprintf("%s liked your post", actorName)
		}
		payload := map[string]any{"post_id": ev.PostID, "actor_id": ev.ActorID}
		enq := Enqueue{
			UserID:   authorUUID,
			Kind:     KindPostLiked,
			Title:    title,
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
		if !s.shouldSendNotification(ctx, authorUUID, KindPostCommented) {
			return nil
		}
		actorName := s.resolveUsername(ctx, ev.ActorID)
		title := "Someone commented on your post"
		if actorName != "" {
			title = fmt.Sprintf("%s commented on your post", actorName)
		}
		payload := map[string]any{"post_id": ev.PostID, "actor_id": ev.ActorID, "comment_id": ev.CommentID}
		enq := Enqueue{
			UserID:   authorUUID,
			Kind:     KindPostCommented,
			Title:    title,
			Body:     ev.CommentText,
			Payload:  payload,
			ActorIDs: []string{ev.ActorID},
		}
		applyMapping(topic, &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypePostReplied:
		var ev eventbus.SocialEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		if ev.ActorID == ev.PostAuthorID {
			return nil
		}
		authorUUID, _ := uuid.Parse(ev.PostAuthorID)
		if !s.shouldSendNotification(ctx, authorUUID, KindPostReplied) {
			return nil
		}
		actorName := s.resolveUsername(ctx, ev.ActorID)
		title := "Someone replied to your comment"
		if actorName != "" {
			title = fmt.Sprintf("%s replied to your comment", actorName)
		}
		payload := map[string]any{"post_id": ev.PostID, "actor_id": ev.ActorID, "comment_id": ev.CommentID}
		enq := Enqueue{
			UserID:   authorUUID,
			Kind:     KindPostReplied,
			Title:    title,
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
		if !s.shouldSendNotification(ctx, recipientUUID, KindSealReceived) {
			return nil
		}
		actorName := s.resolveUsername(ctx, ev.ActorID)
		title := fmt.Sprintf("You received %d seals!", ev.Amount)
		if actorName != "" {
			title = fmt.Sprintf("%s recognized your post", actorName)
		}
		payload := map[string]any{"actor_id": ev.ActorID, "amount": ev.Amount, "post_id": ev.PostID}
		enq := Enqueue{
			UserID:   recipientUUID,
			Kind:     KindSealReceived,
			Title:    title,
			Payload:  payload,
			ActorIDs: []string{ev.ActorID},
		}
		applyMapping(topic, &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypeSilverReceived:
		var ev eventbus.EconomyEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		recipientUUID, _ := uuid.Parse(ev.RecipientID)
		if !s.shouldSendNotification(ctx, recipientUUID, KindSilverReceived) {
			return nil
		}
		actorName := s.resolveUsername(ctx, ev.ActorID)
		title := fmt.Sprintf("You received %d silver seals!", ev.Amount)
		if actorName != "" {
			title = fmt.Sprintf("%s sent you silver", actorName)
		}
		payload := map[string]any{"actor_id": ev.ActorID, "amount": ev.Amount, "post_id": ev.PostID}
		enq := Enqueue{
			UserID:   recipientUUID,
			Kind:     KindSilverReceived,
			Title:    title,
			Payload:  payload,
			ActorIDs: []string{ev.ActorID},
		}
		applyMapping(topic, &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypeTaskApplied:
		var ev eventbus.TaskEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		creatorUUID, _ := uuid.Parse(ev.CreatorID)
		if !s.shouldSendNotification(ctx, creatorUUID, KindTaskApplied) {
			return nil
		}
		actorName := s.resolveUsername(ctx, ev.ActorID)
		taskTitle := s.resolveTaskTitle(ctx, ev.TaskID)
		title := "Someone applied to your task"
		if actorName != "" {
			title = fmt.Sprintf("%s applied to your task", actorName)
		}
		body := "You have a new application."
		if taskTitle != "" {
			body = fmt.Sprintf("Task: %s", taskTitle)
		}
		payload := map[string]any{"task_id": ev.TaskID, "actor_id": ev.ActorID}
		enq := Enqueue{
			UserID:  creatorUUID,
			Kind:    KindTaskApplied,
			Title:   title,
			Body:    body,
			Payload: payload,
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
		if !s.shouldSendNotification(ctx, helperUUID, KindTaskAccepted) {
			return nil
		}
		taskTitle := s.resolveTaskTitle(ctx, ev.TaskID)
		title := "Your task application was accepted!"
		body := "You earned reward seals."
		if taskTitle != "" {
			body = fmt.Sprintf("\"%s\" — someone is on the way.", taskTitle)
		}
		payload := map[string]any{"task_id": ev.TaskID, "creator_id": ev.CreatorID}
		enq := Enqueue{
			UserID:  helperUUID,
			Kind:    KindTaskAccepted,
			Title:   title,
			Body:    body,
			Payload: payload,
		}
		applyMapping("task.accepted", &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypeTaskCompleted:
		var ev eventbus.TaskEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		helperUUID, _ := uuid.Parse(ev.HelperID)
		if !s.shouldSendNotification(ctx, helperUUID, KindTaskCompleted) {
			return nil
		}
		payload := map[string]any{"task_id": ev.TaskID, "reward": ev.Reward}
		enq := Enqueue{
			UserID:  helperUUID,
			Kind:    KindTaskCompleted,
			Title:   "Task approved! Reward received.",
			Body:    fmt.Sprintf("You earned %d seals.", ev.Reward),
			Payload: payload,
		}
		applyMapping("task.completed", &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypeProofSubmitted:
		var ev eventbus.TaskEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		creatorUUID, _ := uuid.Parse(ev.CreatorID)
		if !s.shouldSendNotification(ctx, creatorUUID, KindTaskProofSubmitted) {
			return nil
		}
		actorName := s.resolveUsername(ctx, ev.HelperID)
		taskTitle := s.resolveTaskTitle(ctx, ev.TaskID)
		title := "Proof submitted for review"
		if actorName != "" && taskTitle != "" {
			title = fmt.Sprintf("%s submitted proof for \"%s\"", actorName, taskTitle)
		} else if actorName != "" {
			title = fmt.Sprintf("%s submitted proof for review", actorName)
		}
		payload := map[string]any{"task_id": ev.TaskID, "helper_id": ev.HelperID}
		enq := Enqueue{
			UserID:  creatorUUID,
			Kind:    KindTaskProofSubmitted,
			Title:   title,
			Payload: payload,
		}
		applyMapping("task.proof_submitted", &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypeTaskExpired:
		var ev eventbus.TaskEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		creatorUUID, _ := uuid.Parse(ev.CreatorID)
		if !s.shouldSendNotification(ctx, creatorUUID, KindTaskExpired) {
			return nil
		}
		taskTitle := s.resolveTaskTitle(ctx, ev.TaskID)
		title := "This request expired without a response"
		body := ""
		if taskTitle != "" {
			body = fmt.Sprintf("\"%s\" expired.", taskTitle)
		}
		payload := map[string]any{"task_id": ev.TaskID}
		enq := Enqueue{
			UserID:  creatorUUID,
			Kind:    KindTaskExpired,
			Title:   title,
			Body:    body,
			Payload: payload,
		}
		applyMapping("task.expired", &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypeVerificationRequired:
		var ev eventbus.TaskEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		helperUUID, _ := uuid.Parse(ev.HelperID)
		if !s.shouldSendNotification(ctx, helperUUID, KindTaskVerificationNeeded) {
			return nil
		}
		taskTitle := s.resolveTaskTitle(ctx, ev.TaskID)
		title := "Additional verification required"
		body := ""
		if taskTitle != "" {
			body = fmt.Sprintf("Your proof for \"%s\" needs verification.", taskTitle)
		}
		payload := map[string]any{"task_id": ev.TaskID}
		enq := Enqueue{
			UserID:  helperUUID,
			Kind:    KindTaskVerificationNeeded,
			Title:   title,
			Body:    body,
			Payload: payload,
		}
		applyMapping("task.verification_required", &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypeRewardDelivered:
		var ev eventbus.TaskEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		helperUUID, _ := uuid.Parse(ev.HelperID)
		if !s.shouldSendNotification(ctx, helperUUID, KindTaskRewardDelivered) {
			return nil
		}
		payload := map[string]any{"task_id": ev.TaskID, "reward": ev.Reward}
		enq := Enqueue{
			UserID:  helperUUID,
			Kind:    KindTaskRewardDelivered,
			Title:   "Reward delivered",
			Body:    fmt.Sprintf("Your task reward of %d seals has been sent.", ev.Reward),
			Payload: payload,
		}
		applyMapping("task.reward_delivered", &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypeMedalIssued:
		var ev eventbus.MedalEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		recipientUUID, _ := uuid.Parse(ev.RecipientID)
		if !s.shouldSendNotification(ctx, recipientUUID, KindMedalIssued) {
			return nil
		}
		body := ev.MedalDesc
		if body == "" {
			body = "Issued to the first 3,000 members."
		}
		payload := map[string]any{"medal_name": ev.MedalName}
		enq := Enqueue{
			UserID:  recipientUUID,
			Kind:    KindMedalIssued,
			Title:   fmt.Sprintf("You received the %s", ev.MedalName),
			Body:    body,
			Payload: payload,
		}
		applyMapping("achievement.medal_issued", &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypeRankAdvanced:
		var ev eventbus.LeaderboardEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		userUUID, _ := uuid.Parse(ev.ActorID)
		if !s.shouldSendNotification(ctx, userUUID, KindRankAdvanced) {
			return nil
		}
		title := "You moved up in ranking."
		body := ""
		if ev.Tier != "" {
			title = fmt.Sprintf("You advanced to %s rank", ev.Tier)
			body = "Your actions are making a difference."
		}
		if ev.Region != "" && ev.NewPos > 0 {
			body = fmt.Sprintf("New position: %d in %s.", ev.NewPos, ev.Region)
		}
		payload := map[string]any{
			"new_position": ev.NewPos,
			"old_position": ev.OldPos,
			"tier":         ev.Tier,
			"region":       ev.Region,
			"scope":        ev.Scope,
		}
		enq := Enqueue{
			UserID:  userUUID,
			Kind:    KindRankAdvanced,
			Title:   title,
			Body:    body,
			Payload: payload,
		}
		applyMapping(topic, &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypeDistrictLeader:
		var ev eventbus.LeaderboardEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		userUUID, _ := uuid.Parse(ev.ActorID)
		if !s.shouldSendNotification(ctx, userUUID, KindDistrictLeader) {
			return nil
		}
		payload := map[string]any{"region": ev.Region, "position": ev.Position}
		enq := Enqueue{
			UserID:  userUUID,
			Kind:    KindDistrictLeader,
			Title:   "You became the leader of your district",
			Body:    "People in your area recognize you.",
			Payload: payload,
		}
		applyMapping(topic, &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypeTop50:
		var ev eventbus.LeaderboardEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		userUUID, _ := uuid.Parse(ev.ActorID)
		if !s.shouldSendNotification(ctx, userUUID, KindTop50) {
			return nil
		}
		payload := map[string]any{"region": ev.Region, "position": ev.Position}
		enq := Enqueue{
			UserID:  userUUID,
			Kind:    KindTop50,
			Title:   "You entered the top 50 in your area",
			Body:    "Keep going — the top is closer than you think.",
			Payload: payload,
		}
		applyMapping(topic, &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypeSeasonWarning:
		var ev eventbus.LeaderboardEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		userUUID, _ := uuid.Parse(ev.ActorID)
		if !s.shouldSendNotification(ctx, userUUID, KindSeasonWarning) {
			return nil
		}
		daysLeft := ev.DaysLeft
		if daysLeft <= 0 {
			daysLeft = 3
		}
		payload := map[string]any{"days_left": daysLeft, "season_id": ev.SeasonID}
		enq := Enqueue{
			UserID:  userUUID,
			Kind:    KindSeasonWarning,
			Title:   fmt.Sprintf("Season ends in %d days", daysLeft),
			Body:    "Your current rank will be locked in.",
			Payload: payload,
		}
		applyMapping(topic, &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypeSeasonResult:
		var ev eventbus.LeaderboardEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		userUUID, _ := uuid.Parse(ev.ActorID)
		if !s.shouldSendNotification(ctx, userUUID, KindSeasonResult) {
			return nil
		}
		payload := map[string]any{
			"season_id":   ev.SeasonID,
			"position":    ev.Position,
			"seals":       ev.Seals,
			"tier":        ev.Tier,
			"gold_honors": ev.GoldHonors,
			"silver_sent": ev.SilverSent,
		}
		enq := Enqueue{
			UserID:  userUUID,
			Kind:    KindSeasonResult,
			Title:   "Your season results are ready",
			Body:    "See how you ranked this season.",
			Payload: payload,
		}
		applyMapping(topic, &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypePaymentConfirmed:
		var ev eventbus.SystemEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		userUUID, _ := uuid.Parse(ev.UserID)
		payload := map[string]any{"details": ev.Details}
		enq := Enqueue{
			UserID:  userUUID,
			Kind:    KindPaymentConfirmed,
			Title:   "Payment confirmed. Reward delivered.",
			Body:    "Your transaction was processed successfully.",
			Payload: payload,
		}
		applyMapping(topic, &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypeSecuritySignin:
		var ev eventbus.SystemEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		userUUID, _ := uuid.Parse(ev.UserID)
		payload := map[string]any{"details": ev.Details}
		enq := Enqueue{
			UserID:  userUUID,
			Kind:    KindSecuritySignin,
			Title:   "New sign-in detected",
			Body:    "If this wasn't you, secure your account.",
			Payload: payload,
		}
		applyMapping(topic, &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypeProfileVerified:
		var ev eventbus.SystemEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		userUUID, _ := uuid.Parse(ev.UserID)
		payload := map[string]any{"details": ev.Details}
		enq := Enqueue{
			UserID:  userUUID,
			Kind:    KindProfileVerified,
			Title:   "Your profile has been verified",
			Payload: payload,
		}
		applyMapping(topic, &enq, payload)
		_, err := s.Enqueue(ctx, enq)
		return err

	case eventbus.TypePostRejected:
		var ev eventbus.SystemEvent
		if err := json.Unmarshal(envelope.Payload, &ev); err != nil {
			return err
		}
		userUUID, _ := uuid.Parse(ev.UserID)
		payload := map[string]any{"post_id": ev.PostID, "details": ev.Details}
		enq := Enqueue{
			UserID:  userUUID,
			Kind:    KindPostRejected,
			Title:   "This post could not be published",
			Body:    ev.Details,
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

func (s *Service) resolveUsername(ctx context.Context, rawID string) string {
	if rawID == "" || s.settingsService == nil {
		return ""
	}
	userID, err := uuid.Parse(rawID)
	if err != nil {
		return ""
	}
	username, err := s.repo.GetUsernameByID(ctx, userID)
	if err != nil {
		return ""
	}
	return username
}

func (s *Service) resolveTaskTitle(ctx context.Context, rawID string) string {
	if rawID == "" {
		return ""
	}
	taskID, err := uuid.Parse(rawID)
	if err != nil {
		return ""
	}
	title, err := s.repo.GetTaskTitleByID(ctx, taskID)
	if err != nil {
		return ""
	}
	return title
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
