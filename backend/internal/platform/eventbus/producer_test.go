package eventbus

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"go.uber.org/zap"
)

func TestProducerCompilation(t *testing.T) {
	// This test just ensures the producer can be instantiated and the types are correct.
	// We don't run a real Kafka broker in this unit test.
	logger := zap.NewNop()
	brokers := []string{"localhost:9092"}
	topic := "test.topic"

	producer := NewProducer(brokers, topic, logger)
	assert.NotNil(t, producer)

	// Test marshaling logic indirectly
	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()

	event := SocialEvent{
		BaseEvent: BaseEvent{
			Type:      TypePostLiked,
			ActorID:   "user123",
			Timestamp: time.Now(),
		},
		PostID: "post456",
	}

	// This will fail because no broker is running, but it validates the code path.
	err := producer.Publish(ctx, TypePostLiked, event)
	assert.Error(t, err) // Expecting dial error
}
