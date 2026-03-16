package feed

import (
	"context"
	"errors"
	"fmt"
	"testing"

	"github.com/alicebob/miniredis/v2"
	"github.com/brightbund-backend/internal/platform/cache"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

// newWorkerUnderTest builds an InteractionWorker wired to an in-process miniredis
// server so tests can run without an external Redis dependency.
// The miniredis instance is automatically stopped when the test completes.
func newWorkerUnderTest(t *testing.T, cacheRepo CacheRepository, dbRepo Repository) (*InteractionWorker, *miniredis.Miniredis) {
	t.Helper()
	mr := miniredis.RunT(t)
	redisCli := &cache.Cache{
		Client: redis.NewClient(&redis.Options{Addr: mr.Addr()}),
	}
	return &InteractionWorker{
		cache:    cacheRepo,
		dbRepo:   dbRepo,
		redisCli: redisCli,
	}, mr
}

// ─── flushLikes ──────────────────────────────────────────────────────────────

// TestFlushLikes_SuccessDrainsRedisKeys verifies that when BatchFlushLikes succeeds
// the dirty-posts entry and the per-post likes buffer are both removed from Redis.
func TestFlushLikes_SuccessDrainsRedisKeys(t *testing.T) {
	postID := uuid.New()
	user1, user2 := uuid.New(), uuid.New()

	var flushedPostID uuid.UUID
	var flushedUserCount int
	repo := &testRepo{
		batchFlushLikesFn: func(_ context.Context, p uuid.UUID, users []uuid.UUID) error {
			flushedPostID = p
			flushedUserCount = len(users)
			return nil
		},
	}

	w, mr := newWorkerUnderTest(t, &testCacheRepo{anyOnFeed: false}, repo)
	ctx := context.Background()

	activeKey := "feed_interactions:dirty_posts:likes"
	bufKey := fmt.Sprintf("post:%s:likes_buffer", postID)
	mr.SAdd(activeKey, postID.String())
	mr.SAdd(bufKey, user1.String(), user2.String())

	w.flushLikes(ctx)

	if flushedPostID != postID {
		t.Fatalf("expected post_id %s, got %s", postID, flushedPostID)
	}
	if flushedUserCount != 2 {
		t.Fatalf("expected 2 users flushed, got %d", flushedUserCount)
	}
	if mr.Exists(bufKey) {
		t.Fatal("expected likes_buffer key to be deleted after successful flush")
	}
	// SPopN consumed the post — dirty set should be empty.
	count, _ := mr.SCard(activeKey)
	if count != 0 {
		t.Fatalf("expected dirty_posts to be empty after flush, got %d entries", count)
	}
}

// TestFlushLikes_DBFailureRequeuesPostAndMembers verifies that when BatchFlushLikes
// returns an error the post ID is re-added to the dirty set and the user IDs are
// restored to the per-post buffer so the next tick can retry without data loss.
func TestFlushLikes_DBFailureRequeuesPostAndMembers(t *testing.T) {
	postID := uuid.New()
	user1, user2 := uuid.New(), uuid.New()

	repo := &testRepo{
		batchFlushLikesFn: func(_ context.Context, _ uuid.UUID, _ []uuid.UUID) error {
			return errors.New("pg: connection refused")
		},
	}

	w, mr := newWorkerUnderTest(t, &testCacheRepo{anyOnFeed: false}, repo)
	ctx := context.Background()

	activeKey := "feed_interactions:dirty_posts:likes"
	bufKey := fmt.Sprintf("post:%s:likes_buffer", postID)
	mr.SAdd(activeKey, postID.String())
	mr.SAdd(bufKey, user1.String(), user2.String())

	w.flushLikes(ctx)

	// Post must be back in the dirty set.
	isMember, _ := mr.SIsMember(activeKey, postID.String())
	if !isMember {
		t.Fatal("expected post_id to be re-added to dirty_posts after DB failure")
	}
	// Per-post buffer must contain both users.
	members, _ := mr.SMembers(bufKey)
	if len(members) != 2 {
		t.Fatalf("expected 2 members in likes_buffer after requeue, got %d", len(members))
	}
}

// ─── flushSeals ──────────────────────────────────────────────────────────────

// TestFlushSeals_SuccessDrainsRedisKeys verifies that when BatchFlushSeals succeeds
// the per-post seal counters and the dirty-posts entry are removed from Redis.
func TestFlushSeals_SuccessDrainsRedisKeys(t *testing.T) {
	postID := uuid.New()

	var flushedCount int
	var flushedAmount int64
	repo := &testRepo{
		batchFlushSealsFn: func(_ context.Context, p uuid.UUID, count int, amount int64) error {
			if p != postID {
				t.Errorf("unexpected post_id: %s", p)
			}
			flushedCount = count
			flushedAmount = amount
			return nil
		},
	}

	w, mr := newWorkerUnderTest(t, &testCacheRepo{anyOnFeed: false}, repo)
	ctx := context.Background()

	dirtyKey := "feed_interactions:dirty_posts:seals"
	countKey := fmt.Sprintf("post:%s:seals_count_pending", postID)
	amountKey := fmt.Sprintf("post:%s:seals_amount_pending", postID)
	mr.SAdd(dirtyKey, postID.String())
	mr.Set(countKey, "3")
	mr.Set(amountKey, "150")

	w.flushSeals(ctx)

	if flushedCount != 3 {
		t.Fatalf("expected flushed count=3, got %d", flushedCount)
	}
	if flushedAmount != 150 {
		t.Fatalf("expected flushed amount=150, got %d", flushedAmount)
	}
	if mr.Exists(countKey) {
		t.Fatal("expected seals_count_pending to be deleted after flush")
	}
	if mr.Exists(amountKey) {
		t.Fatal("expected seals_amount_pending to be deleted after flush")
	}
	count, _ := mr.SCard(dirtyKey)
	if count != 0 {
		t.Fatalf("expected dirty_posts:seals to be empty after flush, got %d entries", count)
	}
}

// TestFlushSeals_DBFailureRestoresCountsAndRequeues verifies that when BatchFlushSeals
// fails the seal counters are restored via IncrBy and the post is re-added to the dirty
// set so the next tick retries without losing accumulated seal data.
func TestFlushSeals_DBFailureRestoresCountsAndRequeues(t *testing.T) {
	postID := uuid.New()

	repo := &testRepo{
		batchFlushSealsFn: func(_ context.Context, _ uuid.UUID, _ int, _ int64) error {
			return errors.New("db unavailable")
		},
	}

	w, mr := newWorkerUnderTest(t, &testCacheRepo{anyOnFeed: false}, repo)
	ctx := context.Background()

	dirtyKey := "feed_interactions:dirty_posts:seals"
	countKey := fmt.Sprintf("post:%s:seals_count_pending", postID)
	amountKey := fmt.Sprintf("post:%s:seals_amount_pending", postID)
	mr.SAdd(dirtyKey, postID.String())
	mr.Set(countKey, "3")
	mr.Set(amountKey, "150")

	w.flushSeals(ctx)

	// GetDel consumed the originals; IncrBy on the now-absent key restores them.
	restoredCount, err := mr.Get(countKey)
	if err != nil {
		t.Fatalf("expected seals_count_pending to be restored, got error: %v", err)
	}
	if restoredCount != "3" {
		t.Fatalf("expected restored count=3, got %q", restoredCount)
	}
	restoredAmount, err := mr.Get(amountKey)
	if err != nil {
		t.Fatalf("expected seals_amount_pending to be restored, got error: %v", err)
	}
	if restoredAmount != "150" {
		t.Fatalf("expected restored amount=150, got %q", restoredAmount)
	}
	isMember, _ := mr.SIsMember(dirtyKey, postID.String())
	if !isMember {
		t.Fatal("expected post_id to be re-added to dirty_posts:seals after DB failure")
	}
}

// ─── flushFatigueStates ───────────────────────────────────────────────────────

// TestFlushFatigueStates_SuccessFlushesAndClearsUser verifies that a successful
// UpsertFatigueState call consumes the dirty-users entry from Redis without
// re-marking the user dirty.
func TestFlushFatigueStates_SuccessFlushesAndClearsUser(t *testing.T) {
	userID := uuid.New()
	state := &FeedFatigueState{UserID: userID, AccumulatedActiveSeconds: 500}

	var upsertedUserID uuid.UUID
	repo := &testRepo{
		upsertFatigueStateFn: func(_ context.Context, s *FeedFatigueState) error {
			upsertedUserID = s.UserID
			return nil
		},
	}
	cacheRepo := &testCacheRepo{fatigueState: state}

	w, mr := newWorkerUnderTest(t, cacheRepo, repo)
	ctx := context.Background()

	dirtyKey := "feed_state:dirty_users"
	mr.SAdd(dirtyKey, userID.String())

	w.flushFatigueStates(ctx)

	if upsertedUserID != userID {
		t.Fatalf("expected UpsertFatigueState called with userID %s, got %s", userID, upsertedUserID)
	}
	// Del was called before processing; the user must NOT be re-added on success.
	isMember, _ := mr.SIsMember(dirtyKey, userID.String())
	if isMember {
		t.Fatal("expected user to be removed from dirty_users after successful flush")
	}
}

// TestFlushFatigueStates_DBFailureRemarksUserDirty verifies that when UpsertFatigueState
// fails the user ID is re-added to the dirty set so the next tick retries.
func TestFlushFatigueStates_DBFailureRemarksUserDirty(t *testing.T) {
	userID := uuid.New()
	state := &FeedFatigueState{UserID: userID, AccumulatedActiveSeconds: 300}

	repo := &testRepo{
		upsertFatigueStateFn: func(_ context.Context, _ *FeedFatigueState) error {
			return errors.New("postgres: timeout")
		},
	}
	cacheRepo := &testCacheRepo{fatigueState: state}

	w, mr := newWorkerUnderTest(t, cacheRepo, repo)
	ctx := context.Background()

	dirtyKey := "feed_state:dirty_users"
	mr.SAdd(dirtyKey, userID.String())

	w.flushFatigueStates(ctx)

	isMember, _ := mr.SIsMember(dirtyKey, userID.String())
	if !isMember {
		t.Fatal("expected user_id to be re-added to dirty_users after DB failure")
	}
}

// TestFlushFatigueStates_CacheMissSkipsUpsert verifies that if the Redis fatigue-state
// key has expired (cache miss) UpsertFatigueState is NOT called — we must not upsert
// stale or absent state.
func TestFlushFatigueStates_CacheMissSkipsUpsert(t *testing.T) {
	userID := uuid.New()

	var upsertCalled bool
	repo := &testRepo{
		upsertFatigueStateFn: func(_ context.Context, _ *FeedFatigueState) error {
			upsertCalled = true
			return nil
		},
	}
	// fatigueState == nil → GetFatigueState returns (nil, error) simulating a TTL expiry.
	cacheRepo := &testCacheRepo{fatigueState: nil}

	w, mr := newWorkerUnderTest(t, cacheRepo, repo)
	ctx := context.Background()

	dirtyKey := "feed_state:dirty_users"
	mr.SAdd(dirtyKey, userID.String())

	w.flushFatigueStates(ctx)

	if upsertCalled {
		t.Fatal("expected UpsertFatigueState to be skipped when cache state is absent")
	}
}
