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

	return c.redis.Client.Set(ctx, key, bytes, 7*24*time.Hour).Err()
}

func (c *cacheRepo) MarkUserDirty(ctx context.Context, userID uuid.UUID) error {
	key := "feed_state:dirty_users"
	return c.redis.Client.SAdd(ctx, key, userID.String()).Err()
}

func (c *cacheRepo) MarkDeviceOnFeed(ctx context.Context, userID uuid.UUID, deviceID string, ttl time.Duration) error {
	key := fmt.Sprintf("feed_presence:%s", userID.String())
	expireAt := time.Now().Add(ttl).Unix()

	pipe := c.redis.Client.TxPipeline()
	pipe.ZAdd(ctx, key, redis.Z{Score: float64(expireAt), Member: deviceID})
	pipe.ZRemRangeByScore(ctx, key, "-inf", fmt.Sprintf("%d", time.Now().Unix()))
	pipe.Expire(ctx, key, 24*time.Hour)
	_, err := pipe.Exec(ctx)
	return err
}

func (c *cacheRepo) AnyDeviceOnFeed(ctx context.Context, userID uuid.UUID) (bool, error) {
	key := fmt.Sprintf("feed_presence:%s", userID.String())
	nowUnix := time.Now().Unix()

	pipe := c.redis.Client.TxPipeline()
	pipe.ZRemRangeByScore(ctx, key, "-inf", fmt.Sprintf("%d", nowUnix))
	countCmd := pipe.ZCard(ctx, key)
	_, err := pipe.Exec(ctx)
	if err != nil {
		return false, err
	}

	return countCmd.Val() > 0, nil
}

func (c *cacheRepo) GetAllyIDs(ctx context.Context, userID uuid.UUID) ([]uuid.UUID, bool, error) {
	key := fmt.Sprintf("feed_ally_list:%s", userID.String())

	val, err := c.redis.Client.Get(ctx, key).Result()
	if err == redis.Nil {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}

	var ids []uuid.UUID
	if err := json.Unmarshal([]byte(val), &ids); err != nil {
		return nil, false, err
	}
	return ids, true, nil
}

func (c *cacheRepo) SetAllyIDs(ctx context.Context, userID uuid.UUID, allyIDs []uuid.UUID) error {
	key := fmt.Sprintf("feed_ally_list:%s", userID.String())
	bytes, err := json.Marshal(allyIDs)
	if err != nil {
		return err
	}
	return c.redis.Client.Set(ctx, key, bytes, 60*time.Second).Err()
}
