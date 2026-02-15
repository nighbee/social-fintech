package economy

import "context"

// StatsCacheInvalidator defines interface for invalidating profile stats cache
// This allows economy module to notify when wallet balances change without
// creating a circular dependency on the profiles module
type StatsCacheInvalidator interface {
	InvalidateStats(ctx context.Context, userID string) error
}

// NoopCacheInvalidator implements StatsCacheInvalidator with no-op behavior
// Used when caching is disabled or not configured
type NoopCacheInvalidator struct{}

func (n *NoopCacheInvalidator) InvalidateStats(ctx context.Context, userID string) error {
	return nil // No-op
}
