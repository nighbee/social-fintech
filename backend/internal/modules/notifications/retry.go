package notifications

import (
	"context"
	"encoding/json"
	"time"

	"github.com/segmentio/kafka-go"
	"github.com/brightbund-backend/internal/platform/eventbus"
	"go.uber.org/zap"
)

type RetryWorker struct {
	brokers  []string
	topics   []string
	groupID  string
	producer *eventbus.Producer
	logger   *zap.Logger
}

func NewRetryWorker(brokers []string, topics []string, groupID string, producer *eventbus.Producer, logger *zap.Logger) *RetryWorker {
	return &RetryWorker{
		brokers:  brokers,
		topics:   topics,
		groupID:  groupID,
		producer: producer,
		logger:   logger,
	}
}

func (w *RetryWorker) Start(ctx context.Context) error {
	w.logger.Info("starting notification retry orchestration",
		zap.Strings("topics", w.topics),
	)

	for _, topic := range w.topics {
		go w.consume(ctx, topic)
	}

	<-ctx.Done()
	return ctx.Err()
}

func (w *RetryWorker) consume(ctx context.Context, topic string) {
	reader := kafka.NewReader(kafka.ReaderConfig{
		Brokers:  w.brokers,
		GroupID:  w.groupID,
		Topic:    topic,
		MinBytes: 10e3,
		MaxBytes: 10e6,
		MaxWait:  1 * time.Second,
	})
	defer reader.Close()

	for {
		m, err := reader.ReadMessage(ctx)
		if err != nil {
			if ctx.Err() != nil {
				return
			}
			w.logger.Error("failed to read retry message", zap.String("topic", topic), zap.Error(err))
			time.Sleep(1 * time.Second)
			continue
		}

		var envelope eventbus.Envelope
		if err := json.Unmarshal(m.Value, &envelope); err != nil {
			w.logger.Error("failed to unmarshal retry envelope", zap.Error(err))
			continue
		}

		var event eventbus.PushNotificationEvent
		if err := json.Unmarshal(envelope.Payload, &event); err != nil {
			w.logger.Error("failed to unmarshal retry event", zap.Error(err))
			continue
		}

		// Wait until delivery time
		if event.DeliverAfter != nil {
			wait := time.Until(*event.DeliverAfter)
			if wait > 0 {
				w.logger.Debug("delaying delivery", 
					zap.String("user_id", event.UserID), 
					zap.Duration("wait", wait),
				)
				select {
				case <-ctx.Done():
					return
				case <-time.After(wait):
				}
			}
		}

		w.logger.Info("re-dispatching notification after retry delay",
			zap.String("user_id", event.UserID),
			zap.Int("retry_count", event.RetryCount),
		)

		// Re-dispatch to the main dispatcher
		err = w.producer.PublishToTopic(ctx, "push.dispatch", eventbus.TypePushDispatch, event)
		if err != nil {
			w.logger.Error("failed to re-dispatch notification", zap.Error(err))
		}
	}
}

func (w *RetryWorker) Close() error {
	return nil // Readers are closed in goroutines via defer
}
