package profiles

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/brightbund-backend/internal/platform/cache"
	"github.com/redis/go-redis/v9"
)

type StatsCache interface {
	GetStats(ctx context.Context, userID string) (*ProfileStats, error)
	SetStats(ctx context.Context, userID string, stats *ProfileStats, ttl time.Duration) error
	InvalidateStats(ctx context.Context, userID string) error
}

// RedisStatsCache implements StatsCache using Redis
type RedisStatsCache struct {
	client *redis.Client
}

// CacheWrapperStatsCache implements StatsCache using the platform cache.Cache wrapper
type CacheWrapperStatsCache struct {
	cache *cache.Cache
}

// NewRedisStatsCache creates a new Redis-backed stats cache
// Accepts a redis.Client directly for flexibility
func NewRedisStatsCache(client *redis.Client) *RedisStatsCache {
	return &RedisStatsCache{client: client}
}

// NewCacheWrapperStatsCache creates a stats cache using the platform cache wrapper
func NewCacheWrapperStatsCache(c *cache.Cache) *CacheWrapperStatsCache {
	return &CacheWrapperStatsCache{cache: c}
}

// cacheKey generates a consistent cache key for user stats
func cacheKey(userID string) string {
	return fmt.Sprintf("profile:stats:%s", userID)
}

// GetStats retrieves cached profile stats for a user
// Returns redis.Nil error if key doesn't exist (cache miss)
func (c *RedisStatsCache) GetStats(ctx context.Context, userID string) (*ProfileStats, error) {
	key := cacheKey(userID)
	data, err := c.client.Get(ctx, key).Result()
	if err != nil {
		return nil, err // redis.Nil on cache miss
	}

	var stats ProfileStats
	if err := json.Unmarshal([]byte(data), &stats); err != nil {
		// If unmarshal fails, invalidate the corrupted cache entry
		_ = c.InvalidateStats(ctx, userID)
		return nil, fmt.Errorf("failed to unmarshal cached stats: %w", err)
	}

	return &stats, nil
}

// SetStats stores profile stats in cache with TTL
// Use fire-and-forget pattern - don't fail the request if cache write fails
func (c *RedisStatsCache) SetStats(ctx context.Context, userID string, stats *ProfileStats, ttl time.Duration) error {
	key := cacheKey(userID)
	data, err := json.Marshal(stats)
	if err != nil {
		return fmt.Errorf("failed to marshal stats: %w", err)
	}

	return c.client.Set(ctx, key, data, ttl).Err()
}

// InvalidateStats removes cached stats for a user
// Call this when wallet balance changes to ensure cache consistency
func (c *RedisStatsCache) InvalidateStats(ctx context.Context, userID string) error {
	key := cacheKey(userID)
	return c.client.Del(ctx, key).Err()
}

// GetStats retrieves cached profile stats using the cache wrapper
func (c *CacheWrapperStatsCache) GetStats(ctx context.Context, userID string) (*ProfileStats, error) {
	key := cacheKey(userID)
	data, err := c.cache.Get(ctx, key)
	if err != nil {
		return nil, err // cache miss or error
	}

	var stats ProfileStats
	if err := json.Unmarshal([]byte(data), &stats); err != nil {
		// If unmarshal fails, invalidate the corrupted cache entry
		_ = c.InvalidateStats(ctx, userID)
		return nil, fmt.Errorf("failed to unmarshal cached stats: %w", err)
	}

	return &stats, nil
}

// SetStats stores profile stats in cache with TTL using the cache wrapper
func (c *CacheWrapperStatsCache) SetStats(ctx context.Context, userID string, stats *ProfileStats, ttl time.Duration) error {
	key := cacheKey(userID)
	data, err := json.Marshal(stats)
	if err != nil {
		return fmt.Errorf("failed to marshal stats: %w", err)
	}

	return c.cache.Set(ctx, key, string(data), ttl)
}

// InvalidateStats removes cached stats using the cache wrapper
func (c *CacheWrapperStatsCache) InvalidateStats(ctx context.Context, userID string) error {
	key := cacheKey(userID)
	return c.cache.Delete(ctx, key)
}
