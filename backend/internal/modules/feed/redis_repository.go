package feed

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/brightbund-backend/internal/platform/cache"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

type cacheRepo struct {
	redis *cache.Cache
}

func NewCacheRepository(redisClient *cache.Cache) CacheRepository {
	return &cacheRepo{redis: redisClient}
}

func (c *cacheRepo) GetFatigueState(ctx context.Context, userID uuid.UUID) (*FeedFatigueState, error) {
	key := fmt.Sprintf("feed_state:%s", userID.String())

	val, err := c.redis.Client.Get(ctx, key).Result()
	if err == redis.Nil {
		return nil, fmt.Errorf("cache miss")
	} else if err != nil {
		return nil, err
	}

	var state FeedFatigueState
	if err := json.Unmarshal([]byte(val), &state); err != nil {
		return nil, err
	}

	return &state, nil
}

func (c *cacheRepo) SetFatigueState(ctx context.Context, state *FeedFatigueState) error {
	key := fmt.Sprintf("feed_state:%s", state.UserID.String())

	bytes, err := json.Marshal(state)
	if err != nil {
		return err
	}

	// State expires in Redis after 7 days (well beyond the 2 hours decay limit)
	return c.redis.Client.Set(ctx, key, bytes, 7*24*time.Hour).Err()
}

func (c *cacheRepo) MarkUserDirty(ctx context.Context, userID uuid.UUID) error {
	key := "feed_state:dirty_users"
	return c.redis.Client.SAdd(ctx, key, userID.String()).Err()
}
