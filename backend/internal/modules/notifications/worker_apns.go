package notifications

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/segmentio/kafka-go"
	"github.com/brightbund-backend/internal/platform/eventbus"
	"go.uber.org/zap"
	"golang.org/x/net/http2"
)

type IOSWorker struct {
	reader   *kafka.Reader
	producer *eventbus.Producer
	svc      *Service
	logger   *zap.Logger
	client   *http.Client
	
	// APNs Config
	keyID  string
	teamID string
	bundle string
	isProd bool
	// key *ecdsa.PrivateKey // Injected for JWT signing
}

func NewIOSWorker(brokers []string, topic, groupID string, producer *eventbus.Producer, svc *Service, logger *zap.Logger) *IOSWorker {
	// APNs requires HTTP/2. Go's http.Transport supports it by default if configured.
	tr := &http.Transport{}
	_ = http2.ConfigureTransport(tr)

	return &IOSWorker{
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
		client: &http.Client{
			Transport: tr,
			Timeout:   10 * time.Second,
		},
	}
}

func (w *IOSWorker) Start(ctx context.Context) error {
	w.logger.Info("starting ios push worker (APNs)", 
		zap.String("topic", w.reader.Config().Topic),
		zap.String("group_id", w.reader.Config().GroupID),
	)

	for {
		m, err := w.reader.ReadMessage(ctx)
		if err != nil {
			if ctx.Err() != nil {
				return ctx.Err()
			}
			w.logger.Error("failed to read ios push message", zap.Error(err))
			time.Sleep(1 * time.Second)
			continue
		}

		var envelope eventbus.Envelope
		if err := json.Unmarshal(m.Value, &envelope); err != nil {
			w.logger.Error("failed to unmarshal ios push envelope", zap.Error(err))
			continue
		}

		var event eventbus.PushNotificationEvent
		if err := json.Unmarshal(envelope.Payload, &event); err != nil {
			w.logger.Error("failed to unmarshal ios push event", zap.Error(err))
			continue
		}

		if err := w.send(ctx, event); err != nil {
			w.logger.Error("failed to send ios push", 
				zap.String("user_id", event.UserID),
				zap.Error(err),
			)
			// Move to retry chain on retriable failure
			_ = w.svc.PublishToRetry(ctx, "ios", event)
		}
	}
}

func (w *IOSWorker) send(ctx context.Context, event eventbus.PushNotificationEvent) error {
	token, ok := event.Payload["target_token"].(string)
	if !ok || token == "" {
		return nil
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

	host := "api.development.push.apple.com"
	if w.isProd {
		host = "api.push.apple.com"
	}

	url := fmt.Sprintf("https://%s/3/device/%s", host, token)

	// APNs Payload
	aps := map[string]any{
		"aps": map[string]any{
			"alert": map[string]any{
				"title": event.Title,
				"body":  event.Body,
			},
			"sound":             "default",
			"thread-id":        event.Payload["collapse_key"], // Equivalent to collapse-id
		},
	}
	
	// Add custom fields
	for k, v := range event.Payload {
		if k == "target_token" || k == "collapse_key" {
			continue
		}
		aps[k] = v
	}

	body, _ := json.Marshal(aps)
	req, _ := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(body))
	
	// Headers
	req.Header.Set("apns-topic", w.bundle)
	req.Header.Set("apns-priority", "10")
	req.Header.Set("apns-push-type", "alert")
	if collapseID, ok := event.Payload["collapse_key"].(string); ok && collapseID != "" {
		req.Header.Set("apns-collapse-id", collapseID)
	}

	// TODO: Add Authorization header (Bearer JWT signed with .p8 key)
	// req.Header.Set("authorization", "bearer " + token)

	resp, err := w.client.Do(req)
	status := "sent"
	errMsg := ""

	if err != nil {
		status = "failed"
		errMsg = err.Error()
	} else {
		defer resp.Body.Close()
		if resp.StatusCode == http.StatusGone {
			w.logger.Info("ios token gone, deactivating", zap.String("token", token))
			_ = w.svc.UnregisterDevice(ctx, token)
			return nil
		}
		if resp.StatusCode != http.StatusOK {
			status = "failed"
			errMsg = fmt.Sprintf("apns status: %d", resp.StatusCode)
			err = fmt.Errorf(errMsg)
		}
	}

	// 2. Audit Logging
	_ = w.svc.repo.LogSentNotification(ctx, &SentNotification{
		IdempotencyKey: event.IdempotencyKey,
		DeviceToken:    token,
		Platform:       "ios",
		Status:         status,
		ErrorMessage:   errMsg,
	})

	return err
}

func (w *IOSWorker) Close() error {
	return w.reader.Close()
}
