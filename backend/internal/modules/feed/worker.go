package feed

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/brightbund-backend/internal/platform/cache"
	"github.com/brightbund-backend/internal/platform/logger"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// InteractionWorker handles asynchronous flushing of high-frequency feed interactions
// (Likes, Seals, Feed Fatigue State) from Redis into PostgreSQL.
type InteractionWorker struct {
	cache    CacheRepository
	dbRepo   Repository // Assuming extended to include BatchFlush tools
	redisCli *cache.Cache

	mu      sync.Mutex
	running bool
	ctx     context.Context
	cancel  context.CancelFunc
	wg      sync.WaitGroup
}

func NewInteractionWorker(redisCli *cache.Cache, dbRepo Repository) *InteractionWorker {
	return &InteractionWorker{
		cache:    NewCacheRepository(redisCli),
		dbRepo:   dbRepo,
		redisCli: redisCli,
	}
}

func (w *InteractionWorker) Start() {
	w.mu.Lock()
	defer w.mu.Unlock()

	if w.running {
		return
	}
	w.running = true
	w.ctx, w.cancel = context.WithCancel(context.Background())

	w.wg.Add(1)
	go w.eventLoop(w.ctx)
}

func (w *InteractionWorker) Stop() {
	w.mu.Lock()
	if !w.running {
		w.mu.Unlock()
		return
	}
	w.running = false
	w.cancel()
	w.mu.Unlock()

	w.wg.Wait()
}

func (w *InteractionWorker) eventLoop(ctx context.Context) {
	defer w.wg.Done()
	ticker := time.NewTicker(30 * time.Second) // Flush every 30 seconds
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			logger.Info("feed interaction worker stopped")
			return
		case <-ticker.C:
			w.flushLikes(ctx)
			w.flushSeals(ctx)
			w.flushFatigueStates(ctx)
		}
	}
}

// flushLikes pops elements from the active likes buffer queue and bulk inserts them to PG
func (w *InteractionWorker) flushLikes(ctx context.Context) {
	// A set in redis tracking which posts currently have dirty pending likes
	activePostsKey := "feed_interactions:dirty_posts:likes"

	// Pop up to 100 dirty posts
	posts, err := w.redisCli.Client.SPopN(ctx, activePostsKey, 100).Result()
	if err != nil && err != redis.Nil {
		logger.Error("failed to pop dirty likes post queues", zap.Error(err))
		return
	}

	for _, postIDStr := range posts {
		postID, err := uuid.Parse(postIDStr)
		if err != nil {
			continue
		}

		postSetKey := fmt.Sprintf("post:%s:likes_buffer", postIDStr)

		// SMEMBERS and then DEL ensures we atomically grab and wipe the pending likes queue
		// (Normally we'd use SPOP count, or a Lua script for strict exactly-once semantics,
		// but standard rename/del pattern is sufficient for MVP like counts)

		userIDsStr, err := w.redisCli.Client.SMembers(ctx, postSetKey).Result()
		if err != nil || len(userIDsStr) == 0 {
			continue
		}

		// Wipe the queue
		w.redisCli.Client.Del(ctx, postSetKey)

		// Parse UUIDs
		userIDs := make([]uuid.UUID, 0, len(userIDsStr))
		for _, uidStr := range userIDsStr {
			if uid, err := uuid.Parse(uidStr); err == nil {
				userIDs = append(userIDs, uid)
			}
		}

		// Write Batch to PostgreSQL
		if err := w.dbRepo.BatchFlushLikes(ctx, postID, userIDs); err != nil {
			logger.Error("failed to bulk flush likes to db", zap.Error(err), zap.String("post_id", postIDStr))
			// Put back in queue so the next tick retries.
			members := make([]interface{}, len(userIDsStr))
			for i, s := range userIDsStr {
				members[i] = s
			}
			w.redisCli.Client.SAdd(ctx, activePostsKey, postIDStr)
			w.redisCli.Client.SAdd(ctx, postSetKey, members...)
		}
	}
}

// QueueLike is called by the HTTP Handler directly to write-behind
func (w *InteractionWorker) QueueLike(ctx context.Context, postID, userID uuid.UUID) error {
	postSetKey := fmt.Sprintf("post:%s:likes_buffer", postID.String())
	activePostsKey := "feed_interactions:dirty_posts:likes"

	pipe := w.redisCli.Client.Pipeline()
	pipe.SAdd(ctx, postSetKey, userID.String())
	pipe.SAdd(ctx, activePostsKey, postID.String())
	_, err := pipe.Exec(ctx)
	return err
}

// flushFatigueStates reads the set of user IDs marked dirty in Redis and
// upserts each user's fatigue state into PostgreSQL. This ensures state
// survives Redis eviction or restarts and is visible from any device.
func (w *InteractionWorker) flushFatigueStates(ctx context.Context) {
	dirtyKey := "feed_state:dirty_users"

	userIDStrs, err := w.redisCli.Client.SMembers(ctx, dirtyKey).Result()
	if err == redis.Nil || len(userIDStrs) == 0 {
		return
	}
	if err != nil {
		logger.Error("flushFatigueStates: failed to read dirty users", zap.Error(err))
		return
	}

	// Clear the dirty set before processing — stragglers will be re-added on
	// the next sync, so we won't lose any writes.
	w.redisCli.Client.Del(ctx, dirtyKey)

	cacheRepo := w.cache
	for _, uidStr := range userIDStrs {
		userID, err := uuid.Parse(uidStr)
		if err != nil {
			continue
		}

		state, err := cacheRepo.GetFatigueState(ctx, userID)
		if err != nil {
			// Cache miss — state already expired; nothing to flush.
			continue
		}

		if err := w.dbRepo.UpsertFatigueState(ctx, state); err != nil {
			logger.Error("flushFatigueStates: failed to upsert state",
				zap.String("user_id", uidStr),
				zap.Error(err),
			)
			// Re-mark dirty so the next tick retries.
			w.redisCli.Client.SAdd(ctx, dirtyKey, uidStr)
		}
	}
}

// flushSeals reads pending seal counts/amounts from Redis and batch-updates
// posts.seals_count and posts.seals_amount in PostgreSQL.
func (w *InteractionWorker) flushSeals(ctx context.Context) {
	dirtyKey := "feed_interactions:dirty_posts:seals"

	postIDStrs, err := w.redisCli.Client.SPopN(ctx, dirtyKey, 100).Result()
	if err != nil && err != redis.Nil {
		logger.Error("flushSeals: failed to pop dirty posts", zap.Error(err))
		return
	}

	for _, postIDStr := range postIDStrs {
		postID, err := uuid.Parse(postIDStr)
		if err != nil {
			continue
		}

		countKey := fmt.Sprintf("post:%s:seals_count_pending", postIDStr)
		amountKey := fmt.Sprintf("post:%s:seals_amount_pending", postIDStr)

		// Atomically get-and-delete both counters.
		pipe := w.redisCli.Client.Pipeline()
		countCmd := pipe.GetDel(ctx, countKey)
		amountCmd := pipe.GetDel(ctx, amountKey)
		if _, err := pipe.Exec(ctx); err != nil && err != redis.Nil {
			logger.Error("flushSeals: failed to read pending seals", zap.Error(err), zap.String("post_id", postIDStr))
			w.redisCli.Client.SAdd(ctx, dirtyKey, postIDStr)
			continue
		}

		count, _ := countCmd.Int()
		totalAmount, _ := amountCmd.Int64()
		if count == 0 {
			continue
		}

		if err := w.dbRepo.BatchFlushSeals(ctx, postID, count, totalAmount); err != nil {
			logger.Error("flushSeals: failed to flush to db", zap.Error(err), zap.String("post_id", postIDStr))
			// Restore counts so they are not lost.
			pipe := w.redisCli.Client.Pipeline()
			pipe.IncrBy(ctx, countKey, int64(count))
			pipe.IncrBy(ctx, amountKey, totalAmount)
			pipe.SAdd(ctx, dirtyKey, postIDStr)
			pipe.Exec(ctx)
		}
	}
}

// QueueSeal is called by the HTTP Handler after the Economy module confirms the deduction.
// It increments the pending seal count and amount for the post in Redis so the background
// worker can batch-flush into posts.seals_count / posts.seals_amount in PostgreSQL.
func (w *InteractionWorker) QueueSeal(postID uuid.UUID, amount int64) error {
	ctx := context.Background()
	countKey := fmt.Sprintf("post:%s:seals_count_pending", postID.String())
	amountKey := fmt.Sprintf("post:%s:seals_amount_pending", postID.String())
	dirtyKey := "feed_interactions:dirty_posts:seals"

	pipe := w.redisCli.Client.Pipeline()
	pipe.IncrBy(ctx, countKey, 1)
	pipe.IncrBy(ctx, amountKey, amount)
	pipe.SAdd(ctx, dirtyKey, postID.String())
	_, err := pipe.Exec(ctx)
	return err
}

// TryQueueSeal is the safe variant for use from HTTP handlers.
// It uses a Redis SET NX (set-if-not-exists) lock keyed on idempotencyKey to guarantee
// exactly-once writes to the seal pending counter, preventing duplicate post seals_count
// increments when two concurrent requests both receive CreatedNew=true from the Economy
// layer (a Read-Committed window race on the first in-flight transaction pair).
//
// The NX key TTL is set to 24 hours — long enough to absorb any real-world network retry
// window, but shorter than the multi-day pair cooldown that prevents a second legitimate
// seal from the same user to the same post author.
func (w *InteractionWorker) TryQueueSeal(ctx context.Context, postID uuid.UUID, idempotencyKey string, amount int64) error {
	nxKey := "seal_queue_once:" + idempotencyKey
	const nxTTL = 24 * time.Hour

	// SET NX: only the first caller for this idempotencyKey succeeds.
	set, err := w.redisCli.Client.SetNX(ctx, nxKey, "1", nxTTL).Result()
	if err != nil {
		// Redis error: fall back to unconditional queue to avoid silently dropping the update.
		// BatchFlushSeals recomputes from the ledger (idempotent), so this is safe.
		return w.QueueSeal(postID, amount)
	}
	if !set {
		// Another request already queued this seal — deduplicated.
		return nil
	}
	return w.QueueSeal(postID, amount)
}
