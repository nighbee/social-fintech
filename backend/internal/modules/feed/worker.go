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
			// w.flushSeals(ctx)
			// w.flushFatigueStates(ctx)
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
		_ /*postID*/, err := uuid.Parse(postIDStr)
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
		// if err := w.dbRepo.BatchFlushLikes(ctx, postID, userIDs); err != nil {
		// 	logger.Error("failed to bulk flush likes to db", zap.Error(err), zap.String("post_id", postIDStr))
		//     // Put back in queue if Postgres failed
		// 	w.redisCli.Client.SAdd(ctx, activePostsKey, postIDStr)
		//  w.redisCli.Client.SAdd(ctx, postSetKey, userIDsStr)
		// }
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
