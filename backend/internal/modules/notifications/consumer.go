package notifications

import (
	"context"
	"encoding/json"
	"time"

	"github.com/segmentio/kafka-go"
	"github.com/brightbund-backend/internal/platform/eventbus"
	"go.uber.org/zap"
)

type EventConsumer struct {
	reader *kafka.Reader
	svc    *Service
	logger *zap.Logger
}

func NewEventConsumer(brokers []string, topic, groupID string, svc *Service, logger *zap.Logger) *EventConsumer {
	return &EventConsumer{
		reader: kafka.NewReader(kafka.ReaderConfig{
			Brokers:  brokers,
			GroupID:  groupID,
			Topic:    topic,
			MinBytes: 10e3, // 10KB
			MaxBytes: 10e6, // 10MB
			MaxWait:  1 * time.Second,
		}),
		svc:    svc,
		logger: logger,
	}
}

func (c *EventConsumer) Start(ctx context.Context) error {
	c.logger.Info("starting notification event consumer", 
		zap.String("topic", c.reader.Config().Topic),
		zap.String("group_id", c.reader.Config().GroupID),
	)

	for {
		m, err := c.reader.ReadMessage(ctx)
		if err != nil {
			if ctx.Err() != nil {
				return ctx.Err()
			}
			c.logger.Error("failed to read message from kafka", zap.Error(err))
			time.Sleep(1 * time.Second)
			continue
		}

		var envelope eventbus.Envelope
		if err := json.Unmarshal(m.Value, &envelope); err != nil {
			c.logger.Error("failed to unmarshal event envelope", zap.Error(err))
			continue
		}

		if err := c.svc.HandleSystemEvent(ctx, envelope); err != nil {
			c.logger.Error("failed to handle system event", 
				zap.String("type", string(envelope.Type)),
				zap.Error(err),
			)
			// Depending on error type, we might want to Commit or Dead Letter.
			// For now, we continue to the next message.
		}
	}
}

func (c *EventConsumer) Close() error {
	return c.reader.Close()
}
