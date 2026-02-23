package mapmodule

import (
	"context"
	"strconv"
	"strings"
	"time"

	"github.com/brightbund-backend/internal/platform/cache"
	"github.com/brightbund-backend/internal/platform/logger"
	"github.com/google/uuid"
	"go.uber.org/zap"
)

// Worker snapshots weekly champions from Redis ZSETs into Postgres.
type Worker struct {
	cache   *cache.Cache
	repo    Repository
	stopCh  chan struct{}
	running bool
}

func NewWorker(cacheClient *cache.Cache, repo Repository) *Worker {
	return &Worker{
		cache:  cacheClient,
		repo:   repo,
		stopCh: make(chan struct{}),
	}
}

func (w *Worker) Start() {
	if w.running {
		return
	}
	w.running = true

	go func() {
		ticker := time.NewTicker(1 * time.Hour)
		defer ticker.Stop()

		for {
			select {
			case <-ticker.C:
				w.snapshotChampions(context.Background())
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
