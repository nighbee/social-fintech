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
)

type HuaweiWorker struct {
	reader   *kafka.Reader
	producer *eventbus.Producer
	svc      *Service
	logger   *zap.Logger
	client   *http.Client
	
	// HMS Config
	appID     string
	appSecret string
	accessToken string
	tokenExpiry time.Time
}

func NewHuaweiWorker(brokers []string, topic, groupID string, appID, appSecret string, producer *eventbus.Producer, svc *Service, logger *zap.Logger) *HuaweiWorker {
	return &HuaweiWorker{
		reader: kafka.NewReader(kafka.ReaderConfig{
			Brokers:  brokers,
			GroupID:  groupID,
			Topic:    topic,
			MinBytes: 10e3,
			MaxBytes: 10e6,
			MaxWait:  1 * time.Second,
		}),
		producer:    producer,
		svc:         svc,
		logger:      logger,
		appID:       appID,
		appSecret:   appSecret,
		client:      &http.Client{Timeout: 10 * time.Second},
	}
}

func (w *HuaweiWorker) Start(ctx context.Context) error {
	w.logger.Info("starting huawei push worker (HMS)", 
		zap.String("topic", w.reader.Config().Topic),
		zap.String("group_id", w.reader.Config().GroupID),
	)

	for {
		m, err := w.reader.ReadMessage(ctx)
		if err != nil {
			if ctx.Err() != nil {
				return ctx.Err()
			}
			w.logger.Error("failed to read huawei push message", zap.Error(err))
			time.Sleep(1 * time.Second)
			continue
		}

		var envelope eventbus.Envelope
		if err := json.Unmarshal(m.Value, &envelope); err != nil {
			w.logger.Error("failed to unmarshal huawei push envelope", zap.Error(err))
			continue
		}

		var event eventbus.PushNotificationEvent
		if err := json.Unmarshal(envelope.Payload, &event); err != nil {
			w.logger.Error("failed to unmarshal huawei push event", zap.Error(err))
			continue
		}

		if err := w.send(ctx, event); err != nil {
			w.logger.Error("failed to send huawei push", 
				zap.String("user_id", event.UserID),
				zap.Error(err),
			)
			// Move to retry chain on retriable failure
			_ = w.svc.PublishToRetry(ctx, "huawei", event)
		}
	}
}

func (w *HuaweiWorker) send(ctx context.Context, event eventbus.PushNotificationEvent) error {
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

	// HMS Payload
	payload := map[string]any{
		"validate_only": false,
		"message": map[string]any{
			"notification": map[string]any{
				"title": event.Title,
				"body":  event.Body,
			},
			"android": map[string]any{
				"notification": map[string]any{
					"click_action": map[string]any{
						"type": 1, // Open app
					},
				},
			},
			"token": []string{token},
		},
	}

	body, _ := json.Marshal(payload)
	url := fmt.Sprintf("https://push-api.cloud.huawei.com/v1/%s/messages:send", w.appID)
	
	req, _ := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(body))
	// TODO: HMS Requires OAuth Access Token in Authorization header
	// req.Header.Set("Authorization", "Bearer " + w.accessToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := w.client.Do(req)
	status := "sent"
	errMsg := ""

	if err != nil {
		status = "failed"
		errMsg = err.Error()
	} else {
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			status = "failed"
			errMsg = fmt.Sprintf("hms status: %d", resp.StatusCode)
			err = fmt.Errorf(errMsg)
		}
	}

	// 2. Audit Logging
	_ = w.svc.repo.LogSentNotification(ctx, &SentNotification{
		IdempotencyKey: event.IdempotencyKey,
		DeviceToken:    token,
		Platform:       "huawei",
		Status:         status,
		ErrorMessage:   errMsg,
	})

	return err
}

func (w *HuaweiWorker) Close() error {
	return w.reader.Close()
}
