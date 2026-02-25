package mapmodule

import (
	"context"
	"strconv"
	"strings"
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
	stopCh      chan struct{}
	running     bool
}

func NewWorker(cacheClient *cache.Cache, repo Repository, economyRepo economy.Repository) *Worker {
	return &Worker{
		cache:       cacheClient,
		repo:        repo,
		economyRepo: economyRepo,
		stopCh:      make(chan struct{}),
	}
}

func (w *Worker) Start() {
	if w.running {
		return
	}
	w.running = true

	go func() {
		championTicker := time.NewTicker(1 * time.Hour)
		sweepTicker := time.NewTicker(5 * time.Minute)
		defer championTicker.Stop()
		defer sweepTicker.Stop()

		// Run sweep immediately on startup to catch any tasks that expired
		// while the service was down.
		w.sweepExpiredTasks(context.Background())

		for {
			select {
			case <-championTicker.C:
				w.snapshotChampions(context.Background())
			case <-sweepTicker.C:
				w.sweepExpiredTasks(context.Background())
			case <-w.stopCh:
				return
			}
		}
	}()
}

func (w *Worker) Stop() {
	if !w.running {
		return
	}
	close(w.stopCh)
	w.running = false
}

func (w *Worker) snapshotChampions(ctx context.Context) {
	w.snapshotByPattern(ctx, "leaderboard:arena:*:week:*:*", 5)
	w.snapshotByPattern(ctx, "leaderboard:city:*:week:*:*", 4)
	w.snapshotByPattern(ctx, "leaderboard:global:week:*:*", 0)
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

		champion := &RegionChampion{
			ID:         uuid.NewString(),
			H3Index:    h3Index,
			Resolution: resolution,
			UserID:     userID,
			Score:      int64(score),
			Week:       week,
			Year:       year,
			UpdatedAt:  time.Now(),
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

// ─── Auto-shutdown sweep ──────────────────────────────────────────────────────

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

// ─── Leaderboard key parsing ───────────────────────────────────────────────────

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
