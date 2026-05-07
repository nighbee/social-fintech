package notifications

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"github.com/segmentio/kafka-go"
	"github.com/brightbund-backend/internal/platform/eventbus"
	"go.uber.org/zap"
	"google.golang.org/api/option"
)

type AndroidWorker struct {
	reader   *kafka.Reader
	producer *eventbus.Producer
	svc      *Service
	client   *messaging.Client
	logger   *zap.Logger
}

func NewAndroidWorker(brokers []string, topic, groupID string, credentialsPath string, producer *eventbus.Producer, svc *Service, logger *zap.Logger) (*AndroidWorker, error) {
	var client *messaging.Client
	if credentialsPath != "" {
		app, err := firebase.NewApp(context.Background(), nil, option.WithCredentialsFile(credentialsPath))
		if err != nil {
			return nil, err
		}
		c, err := app.Messaging(context.Background())
		if err != nil {
			return nil, err
		}
		client = c
		logger.Info("FCM client initialized successfully", zap.String("path", credentialsPath))
	}

	return &AndroidWorker{
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
		client:   client,
		logger:   logger,
	}, nil
}

func (w *AndroidWorker) Start(ctx context.Context) error {
	w.logger.Info("starting android push worker (FCM)", 
		zap.String("topic", w.reader.Config().Topic),
		zap.String("group_id", w.reader.Config().GroupID),
	)

	for {
		m, err := w.reader.ReadMessage(ctx)
		if err != nil {
			if ctx.Err() != nil {
				return ctx.Err()
			}
			w.logger.Error("failed to read android push message", zap.Error(err))
			time.Sleep(1 * time.Second)
			continue
		}

		var envelope eventbus.Envelope
		if err := json.Unmarshal(m.Value, &envelope); err != nil {
			w.logger.Error("failed to unmarshal android push envelope", zap.Error(err))
			continue
		}

		var event eventbus.PushNotificationEvent
		if err := json.Unmarshal(envelope.Payload, &event); err != nil {
			w.logger.Error("failed to unmarshal android push event", zap.Error(err))
			continue
		}

		if err := w.send(ctx, event); err != nil {
			w.logger.Error("failed to send android push", 
				zap.String("user_id", event.UserID),
				zap.Error(err),
			)
			// Move to retry chain on retriable failure
			_ = w.svc.PublishToRetry(ctx, "android", event)
		}
	}
}

func (w *AndroidWorker) send(ctx context.Context, event eventbus.PushNotificationEvent) error {
	token, ok := event.Payload["target_token"].(string)
	if !ok || token == "" {
		return nil // No token, nothing to do
	}

	// 1. Idempotency Check
	if event.IdempotencyKey != "" && w.svc.cache != nil {
		lockKey := fmt.Sprintf("idempotency:%s:%s", event.IdempotencyKey, token)
		ok, err := w.svc.cache.SetNX(ctx, lockKey, "1", 24*time.Hour)
		if err != nil {
			w.logger.Warn("idempotency check failed (cache error)", zap.Error(err))
		} else if !ok {
			w.logger.Info("duplicate push prevented by idempotency", 
				zap.String("key", event.IdempotencyKey),
				zap.String("token", token),
			)
			return nil
		}
	}

	if w.client == nil {
		w.logger.Warn("FCM client not initialized, skipping push", zap.String("token", token))
		return nil
	}

	msg := &messaging.Message{
		Token: token,
		Notification: &messaging.Notification{
			Title: event.Title,
			Body:  event.Body,
		},
		Data: make(map[string]string),
		Android: &messaging.AndroidConfig{
			CollapseKey: event.Payload["collapse_key"].(string),
			Notification: &messaging.AndroidNotification{
				Tag: event.Payload["collapse_key"].(string),
			},
		},
	}

	// Copy custom payload fields to Data (FCM Data must be string:string)
	for k, v := range event.Payload {
		if k == "target_token" || k == "collapse_key" {
			continue
		}
		msg.Data[k] = fmt.Sprintf("%v", v)
	}

	_, err := w.client.Send(ctx, msg)
	status := "sent"
	errMsg := ""

	if err != nil {
		// Handle token invalidation
		if messaging.IsRegistrationTokenNotRegistered(err) {
			w.logger.Info("token not registered, deactivating", zap.String("token", token))
			_ = w.svc.UnregisterDevice(ctx, token)
			return nil
		}
		status = "failed"
		errMsg = err.Error()
	}

	// 2. Audit Logging
	_ = w.svc.repo.LogSentNotification(ctx, &SentNotification{
		IdempotencyKey: event.IdempotencyKey,
		DeviceToken:    token,
		Platform:       "android",
		Status:         status,
		ErrorMessage:   errMsg,
	})

	return err
}

func (w *AndroidWorker) Close() error {
	return w.reader.Close()
}
