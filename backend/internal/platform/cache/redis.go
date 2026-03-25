package cache

import (
	"context"
	"fmt"
	"strconv"
	"time"

	"github.com/redis/go-redis/v9"
)

type Config struct {
	Address      string
	Password     string
	DB           int
	PoolSize     int
	MinIdleConns int
}

type Cache struct {
	Client *redis.Client
}

func New(cfg Config) (*Cache, error) {
	client := redis.NewClient(&redis.Options{
		Addr:         cfg.Address,
		Password:     cfg.Password,
		DB:           cfg.DB,
		DialTimeout:  5 * time.Second,
		ReadTimeout:  3 * time.Second,
		WriteTimeout: 3 * time.Second,
		PoolSize:     cfg.PoolSize,
		MinIdleConns: cfg.MinIdleConns,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("failed to connect to redis: %w", err)
	}

	return &Cache{Client: client}, nil
}

func (c *Cache) Get(ctx context.Context, key string) (string, error) {
	return c.Client.Get(ctx, key).Result()
}

func (c *Cache) Set(ctx context.Context, key string, value interface{}, ttl time.Duration) error {
	return c.Client.Set(ctx, key, value, ttl).Err()
}

func (c *Cache) Delete(ctx context.Context, key string) error {
	return c.Client.Del(ctx, key).Err()
}

func (c *Cache) Exists(ctx context.Context, key string) (bool, error) {
	result, err := c.Client.Exists(ctx, key).Result()
	return result > 0, err
}

// ZSET operations для Leaderboards
func (c *Cache) ZAdd(ctx context.Context, key string, score float64, member string) error {
	return c.Client.ZAdd(ctx, key, redis.Z{Score: score, Member: member}).Err()
}

func (c *Cache) ZRange(ctx context.Context, key string, start, stop int64) ([]string, error) {
	return c.Client.ZRange(ctx, key, start, stop).Result()
}

func (c *Cache) ZRevRange(ctx context.Context, key string, start, stop int64) ([]string, error) {
	return c.Client.ZRevRange(ctx, key, start, stop).Result()
}

func (c *Cache) ZRank(ctx context.Context, key, member string) (int64, error) {
	return c.Client.ZRank(ctx, key, member).Result()
}

func (c *Cache) ZRevRank(ctx context.Context, key, member string) (int64, error) {
	return c.Client.ZRevRank(ctx, key, member).Result()
}

func (c *Cache) ZScore(ctx context.Context, key, member string) (float64, error) {
	return c.Client.ZScore(ctx, key, member).Result()
}

func (c *Cache) ZRangeByExactScore(ctx context.Context, key string, score float64) ([]string, error) {
	scoreStr := strconv.FormatFloat(score, 'f', -1, 64)
	return c.Client.ZRangeByScore(ctx, key, &redis.ZRangeBy{
		Min: scoreStr,
		Max: scoreStr,
	}).Result()
}

func (c *Cache) ZIncrBy(ctx context.Context, key string, increment float64, member string) (float64, error) {
	return c.Client.ZIncrBy(ctx, key, increment, member).Result()
}

func (c *Cache) ScanKeys(ctx context.Context, pattern string, count int64) ([]string, error) {
	iter := c.Client.Scan(ctx, 0, pattern, count).Iterator()
	var keys []string
	for iter.Next(ctx) {
		keys = append(keys, iter.Val())
	}
	if err := iter.Err(); err != nil {
		return nil, err
	}
	return keys, nil
}

func (c *Cache) HealthCheck(ctx context.Context) error {
	return c.Client.Ping(ctx).Err()
}

func (c *Cache) Close() error {
	return c.Client.Close()
}
