package eventbus

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/segmentio/kafka-go"
	"go.uber.org/zap"
)

type Producer struct {
	writer *kafka.Writer
	logger *zap.Logger
	topic  string
}

func NewProducer(brokers []string, topic string, logger *zap.Logger) *Producer {
	return &Producer{
		writer: &kafka.Writer{
			Addr:     kafka.TCP(brokers...),
			Balancer: &kafka.LeastBytes{},
			// Async by default for performance, but we can configure batching
			BatchSize: 10,
			BatchTimeout: 10 * time.Millisecond,
		},
		logger: logger,
		topic:  topic,
	}
}

func (p *Producer) Close() error {
	return p.writer.Close()
}

// Publish sends a structured event to the default Kafka topic.
func (p *Producer) Publish(ctx context.Context, eventType EventType, payload interface{}) error {
	return p.PublishToTopic(ctx, p.topic, eventType, payload)
}

// PublishToTopic sends a structured event to a specific Kafka topic.
func (p *Producer) PublishToTopic(ctx context.Context, topic string, eventType EventType, payload interface{}) error {
	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal event payload: %w", err)
	}

	envelope := Envelope{
		Type:      eventType,
		Payload:   payloadBytes,
		Version:   "1.0",
		CreatedAt: time.Now().UTC(),
	}

	envelopeBytes, err := json.Marshal(envelope)
	if err != nil {
		return fmt.Errorf("failed to marshal event envelope: %w", err)
	}

	err = p.writer.WriteMessages(ctx, kafka.Message{
		Topic: topic,
		Key:   []byte(eventType),
		Value: envelopeBytes,
	})

	if err != nil {
		p.logger.Error("failed to publish event to kafka",
			zap.String("topic", topic),
			zap.String("type", string(eventType)),
			zap.Error(err),
		)
		return err
	}

	p.logger.Debug("event published to kafka",
		zap.String("topic", topic),
		zap.String("type", string(eventType)),
	)

	return nil
}
