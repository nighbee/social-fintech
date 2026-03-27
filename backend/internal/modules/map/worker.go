package mapmodule

import (
	"context"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/brightbund-backend/internal/modules/economy"
	"github.com/brightbund-backend/internal/platform/cache"
	"github.com/brightbund-backend/internal/platform/logger"
	"github.com/google/uuid"
	"go.uber.org/zap"
)

// Worker runs two background loops:
//  1. Champions snapshot  — every 1 h, persists Redis leaderboard leaders to Postgres.
//  2. Auto-shutdown sweep — every 5 min, cancels expired tasks and refunds their creators.
type Worker struct {
	cache       *cache.Cache
	repo        Repository
	economyRepo economy.Repository
	service     *Service

	mu      sync.Mutex
	running bool
	ctx     context.Context
	cancel  context.CancelFunc
	wg      sync.WaitGroup
}

func NewWorker(cacheClient *cache.Cache, repo Repository, economyRepo economy.Repository, service *Service) *Worker {
	return &Worker{
		cache:       cacheClient,
		repo:        repo,
		economyRepo: economyRepo,
		service:     service,
	}
}

func (w *Worker) Start() {
	w.mu.Lock()
	defer w.mu.Unlock()

	if w.running {
		return
	}
	w.running = true
	w.ctx, w.cancel = context.WithCancel(context.Background())

	w.wg.Add(1)
	go func(ctx context.Context) {
		defer w.wg.Done()

		championTicker := time.NewTicker(1 * time.Hour)
		sweepTicker := time.NewTicker(5 * time.Minute)
		defer championTicker.Stop()
		defer sweepTicker.Stop()

		// Run sweep immediately on startup to catch any tasks that expired
		// while the service was down.
		w.sweepExpiredTasks(ctx)

		for {
			select {
			case <-championTicker.C:
				w.snapshotChampions(ctx)
			case <-sweepTicker.C:
				w.sweepExpiredTasks(ctx)
			case <-ctx.Done():
				return
			}
		}
	}(w.ctx)
}

func (w *Worker) Stop() {
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

func (w *Worker) snapshotChampions(ctx context.Context) {
	w.snapshotByPattern(ctx, "leaderboard:arena:*:week:*:*", 5)
	w.snapshotByPattern(ctx, "leaderboard:city:*:week:*:*", 4)
	w.snapshotGlobalGoldChampion(ctx)
}

func (w *Worker) snapshotByPattern(ctx context.Context, pattern string, resolution int) {
	keys, err := w.cache.ScanKeys(ctx, pattern, 500)
	if err != nil {
		logger.Warn("map worker scan failed", zap.String("pattern", pattern), zap.Error(err))
		return
	}

	for _, key := range keys {
		h3Index, year, week, ok := parseLeaderboardKey(key, resolution)
		if !ok {
			continue
		}

		members, err := w.cache.ZRevRange(ctx, key, 0, 0)
		if err != nil || len(members) == 0 {
			continue
		}

		userID := members[0]
		score, err := w.cache.ZScore(ctx, key, userID)
		if err != nil {
			continue
		}

		// Deterministic tie-break for equal scores.
		if tiedMembers, tieErr := w.cache.ZRangeByExactScore(ctx, key, score); tieErr == nil {
			firstSeen := w.getLeaderboardFirstSeen(ctx, key, tiedMembers)
			createdAtByUser, _ := w.repo.GetUsersCreatedAt(ctx, tiedMembers)
			userID = pickChampionUserID(userID, tiedMembers, firstSeen, createdAtByUser)
		}

		champion := &RegionChampion{
			ID:         uuid.MustParse(uuid.NewString()),
			H3Index:    h3Index,
			Resolution: resolution,
			UserID:     uuid.MustParse(userID),
			Score:      int64(score),
			Week:       week,
			Year:       year,
			UpdatedAt:  time.Now(),
		}

		// Try to resolve location names for the champion
		if meta, err := w.service.ResolveH3ToLocation(ctx, h3Index); err == nil && meta != nil {
			champion.CityName = meta.CityName
			champion.RegionName = meta.RegionName
			champion.CountryName = meta.CountryName
		}

		if err := w.repo.UpsertRegionChampion(ctx, champion); err != nil {
			logger.Warn("failed to upsert region champion",
				zap.String("h3_index", h3Index),
				zap.Int("resolution", resolution),
				zap.Int("year", year),
				zap.Int("week", week),
				zap.Error(err),
			)
		}
	}
}

func (w *Worker) snapshotGlobalGoldChampion(ctx context.Context) {
	year, week := time.Now().ISOWeek()
	userID, score, err := w.economyRepo.GetTopGoldUserForWeek(ctx, year, week)
	if err != nil {
		logger.Warn("failed to fetch global gold champion", zap.Int("year", year), zap.Int("week", week), zap.Error(err))
		return
	}
	if userID == "" {
		return
	}

	champion := &RegionChampion{
		ID:          uuid.MustParse(uuid.NewString()),
		H3Index:     "global",
		Resolution:  0,
		UserID:      uuid.MustParse(userID),
		Score:       score,
		Week:        week,
		Year:        year,
		CountryName: "Global",
		UpdatedAt:   time.Now(),
	}

	if err := w.repo.UpsertRegionChampion(ctx, champion); err != nil {
		logger.Warn("failed to upsert global gold champion", zap.Int("year", year), zap.Int("week", week), zap.Error(err))
	}
}

// sweepExpiredTasks finds all open tasks whose auto_shutdown_at has passed,
// cancels each one, and refunds the creator's upfront charge.
func (w *Worker) sweepExpiredTasks(ctx context.Context) {
	tasks, err := w.repo.GetOpenTasksForShutdown(ctx)
	if err != nil {
		logger.Warn("auto-shutdown sweep: failed to fetch tasks", zap.Error(err))
		return
	}
	if len(tasks) == 0 {
		return
	}
	logger.Info("auto-shutdown sweep: processing expired tasks", zap.Int("count", len(tasks)))
	for _, task := range tasks {
		w.autoShutdownTask(ctx, task)
	}
}

// autoShutdownTask cancels a single expired task and refunds the creator atomically.
func (w *Worker) autoShutdownTask(ctx context.Context, task Task) {
	tx, err := w.repo.BeginTx(ctx)
	if err != nil {
		logger.Warn("auto-shutdown: failed to begin tx",
			zap.String("task_id", task.ID), zap.Error(err))
		return
	}
	defer tx.Rollback()

	txRepo := w.repo.WithTx(tx)
	econTxRepo := w.economyRepo.WithTx(tx)

	cancelled, err := txRepo.CancelTask(ctx, task.ID, task.CreatorID)
	if err != nil {
		logger.Warn("auto-shutdown: failed to cancel task",
			zap.String("task_id", task.ID), zap.Error(err))
		return
	}
	if !cancelled {
		// Another goroutine or worker already handled this task (workers confirmed,
		// or it was manually cancelled). Nothing to do.
		return
	}

	if err := economy.RefundTaskCreationTx(ctx, econTxRepo, task.CreatorID, task.ID, task.Reward); err != nil {
		logger.Warn("auto-shutdown: refund failed",
			zap.String("task_id", task.ID),
			zap.String("creator_id", task.CreatorID),
			zap.Error(err))
		return
	}

	if err := tx.Commit(); err != nil {
		logger.Warn("auto-shutdown: failed to commit tx",
			zap.String("task_id", task.ID), zap.Error(err))
		return
	}

	logger.Info("auto-shutdown: task cancelled and refunded",
		zap.String("task_id", task.ID),
		zap.String("creator_id", task.CreatorID),
		zap.Int64("reward_cents", task.Reward),
	)
}

func parseLeaderboardKey(key string, resolution int) (string, int, int, bool) {
	parts := strings.Split(key, ":")
	// arena: leaderboard:arena:{h3}:week:{year}:{week}
	// city:  leaderboard:city:{h3}:week:{year}:{week}
	// global: leaderboard:global:week:{year}:{week}
	if resolution == 0 {
		if len(parts) != 5 {
			return "", 0, 0, false
		}
		year, err := strconv.Atoi(parts[3])
		if err != nil {
			return "", 0, 0, false
		}
		week, err := strconv.Atoi(parts[4])
		if err != nil {
			return "", 0, 0, false
		}
		return "global", year, week, true
	}

	if len(parts) != 6 {
		return "", 0, 0, false
	}

	h3Index := parts[2]
	year, err := strconv.Atoi(parts[4])
	if err != nil {
		return "", 0, 0, false
	}
	week, err := strconv.Atoi(parts[5])
	if err != nil {
		return "", 0, 0, false
	}

	return h3Index, year, week, true
}

func (w *Worker) getLeaderboardFirstSeen(ctx context.Context, leaderboardKey string, members []string) map[string]int64 {
	out := make(map[string]int64, len(members))
	firstSeenKey := leaderboardKey + ":first_seen"

	for _, member := range members {
		raw, err := w.cache.HGet(ctx, firstSeenKey, member)
		if err != nil || raw == "" {
			continue
		}
		ts, convErr := strconv.ParseInt(raw, 10, 64)
		if convErr != nil {
			continue
		}
		out[member] = ts
	}

	return out
}

func pickChampionUserID(fallback string, tiedMembers []string, firstSeen map[string]int64, createdAt map[string]time.Time) string {
	if len(tiedMembers) == 0 {
		return fallback
	}

	// Business tie-break rule for equal score:
	// 1) earliest first contribution in the current weekly leaderboard
	// 2) if equal/missing timestamps -> earliest account created_at
	// 3) final deterministic fallback -> lexicographically smallest user_id
	best := fallback
	bestTS := int64(0)
	bestHasTS := false

	for _, member := range tiedMembers {
		ts, hasTS := firstSeen[member]
		switch {
		case !bestHasTS && hasTS:
			best = member
			bestTS = ts
			bestHasTS = true
		case bestHasTS && hasTS && ts < bestTS:
			best = member
			bestTS = ts
		case bestHasTS && hasTS && ts == bestTS && member < best:
			best = member
		case !bestHasTS && !hasTS && member < best:
			best = member
		}
	}

	if !bestHasTS {
		// Choose the oldest account among tied users for a human-readable deterministic rule.
		best = ""
		var bestCreatedAt time.Time
		hasCreatedAt := false
		for _, member := range tiedMembers {
			cAt, ok := createdAt[member]
			switch {
			case !hasCreatedAt && ok:
				best = member
				bestCreatedAt = cAt
				hasCreatedAt = true
			case hasCreatedAt && ok && cAt.Before(bestCreatedAt):
				best = member
				bestCreatedAt = cAt
			case hasCreatedAt && ok && cAt.Equal(bestCreatedAt) && member < best:
				best = member
			case !hasCreatedAt && !ok:
				if best == "" || member < best {
					best = member
				}
			}
		}
		if best != "" {
			return best
		}
		sort.Strings(tiedMembers)
		return tiedMembers[0]
	}
	return best
}
