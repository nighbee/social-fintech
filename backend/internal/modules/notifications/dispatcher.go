package notifications

import (
	"context"
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/segmentio/kafka-go"
	"github.com/brightbund-backend/internal/platform/eventbus"
	"go.uber.org/zap"
	"fmt"
)

type PushDispatcher struct {
	reader   *kafka.Reader
	producer *eventbus.Producer
	svc      *Service
	logger   *zap.Logger
}

func NewPushDispatcher(brokers []string, topic, groupID string, producer *eventbus.Producer, svc *Service, logger *zap.Logger) *PushDispatcher {
	return &PushDispatcher{
		reader: kafka.NewReader(kafka.ReaderConfig{
			Brokers:  brokers,
			GroupID:  groupID,
			Topic:    topic,
			MinBytes: 10e3,
			MaxBytes: 10e6,
			MaxWait:  1 * time.Second,
		}),
		producer: producer,
		svc:      svc,
		logger:   logger,
	}
}

func (d *PushDispatcher) Start(ctx context.Context) error {
	d.logger.Info("starting push notification dispatcher", 
		zap.String("topic", d.reader.Config().Topic),
		zap.String("group_id", d.reader.Config().GroupID),
	)

	for {
		m, err := d.reader.ReadMessage(ctx)
		if err != nil {
			if ctx.Err() != nil {
				return ctx.Err()
			}
			d.logger.Error("failed to read push dispatch message", zap.Error(err))
			time.Sleep(1 * time.Second)
			continue
		}

		var envelope eventbus.Envelope
		if err := json.Unmarshal(m.Value, &envelope); err != nil {
			d.logger.Error("failed to unmarshal push dispatch envelope", zap.Error(err))
			continue
		}

		if envelope.Type != eventbus.TypePushDispatch {
			d.logger.Warn("received unexpected event type in push dispatcher", zap.String("type", string(envelope.Type)))
			continue
		}

		var event eventbus.PushNotificationEvent
		if err := json.Unmarshal(envelope.Payload, &event); err != nil {
			d.logger.Error("failed to unmarshal push notification event", zap.Error(err))
			continue
		}

		if err := d.dispatch(ctx, event); err != nil {
			d.logger.Error("failed to dispatch push notification", 
				zap.String("user_id", event.UserID),
				zap.Error(err),
			)
		}
	}
}

func (d *PushDispatcher) dispatch(ctx context.Context, event eventbus.PushNotificationEvent) error {
	userID, err := uuid.Parse(event.UserID)
	if err != nil {
		return err
	}

	// 1. Fetch user devices
	tokens, err := d.svc.GetUserDevices(ctx, userID)
	if err != nil {
		return err
	}

	if len(tokens) == 0 {
		d.logger.Debug("no active devices found for user push", zap.String("user_id", event.UserID))
		return nil
	}

	// 2. Fan-out to platform topics
	for _, t := range tokens {
		topic := ""
		switch t.Platform {
		case PlatformIOS:
			topic = "push.ios"
		case PlatformAndroid:
			topic = "push.android"
		case PlatformHuawei:
			topic = "push.huawei"
		default:
			continue
		}

		// Inject the token into the payload for the worker
		payload := event
		if payload.Payload == nil {
			payload.Payload = make(map[string]any)
		}
		payload.Payload["target_token"] = t.Token
		payload.Payload["device_id"] = t.DeviceID

		// Generate or use existing idempotency key
		if payload.IdempotencyKey == "" {
			payload.IdempotencyKey = d.generateIdempotencyKey(payload)
		}

		err := d.producer.PublishToTopic(ctx, topic, eventbus.TypePushDispatch, payload)
		if err != nil {
			d.logger.Error("failed to publish to platform topic", 
				zap.String("topic", topic), 
				zap.String("user_id", event.UserID),
				zap.Error(err),
			)
			// Move to DLQ on failure
			_ = d.producer.PublishToTopic(ctx, "push.dlq", eventbus.TypePushDispatch, payload)
		}
	}

	return nil
}

func (d *PushDispatcher) generateIdempotencyKey(event eventbus.PushNotificationEvent) string {
	// Try to find a unique entity ID in the payload (post_id, comment_id, etc.)
	entityID := ""
	for _, k := range []string{"post_id", "comment_id", "message_id", "task_id", "event_id"} {
		if val, ok := event.Payload[k].(string); ok && val != "" {
			entityID = val
			break
		}
	}

	if entityID == "" {
		// Fallback to a timestamp-based or random-ish key if no entity ID found
		// though usually our events have them.
		entityID = uuid.New().String()
	}

	category := event.Category
	if category == "" {
		category = "push"
	}

	return fmt.Sprintf("%s:%s:%s", category, entityID, event.UserID)
}

func (d *PushDispatcher) Close() error {
	return d.reader.Close()
}
