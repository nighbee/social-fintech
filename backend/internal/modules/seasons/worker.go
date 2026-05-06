package seasons

import (
	"context"
	"sync"
	"time"

	"go.uber.org/zap"
)

// CloseWorker periodically materializes the current and previous season
// rows (so close-out has something to close), then runs the idempotent
// CloseDueSeasons pass. It is safe to start exactly one of these per
// API process; the close pass uses ON CONFLICT upserts so concurrent
// runs across replicas converge on the same archive state.
type CloseWorker struct {
	service  *Service
	snap     SnapshotProvider
	interval time.Duration
	logger   *zap.Logger

	stopOnce sync.Once
	stopCh   chan struct{}
	doneCh   chan struct{}
}

// NewCloseWorker wires the worker. Interval ≤ 0 falls back to one hour
// — frequent ticks are cheap because there is nothing to do until the
// season actually ends.
func NewCloseWorker(service *Service, snap SnapshotProvider, interval time.Duration, logger *zap.Logger) *CloseWorker {
	if interval <= 0 {
		interval = time.Hour
	}
	if logger == nil {
		logger = zap.NewNop()
	}
	return &CloseWorker{
		service:  service,
		snap:     snap,
		interval: interval,
		logger:   logger,
		stopCh:   make(chan struct{}),
		doneCh:   make(chan struct{}),
	}
}

// Start runs the worker in a background goroutine. The first tick runs
// immediately so a freshly-deployed binary closes overdue seasons
// without waiting `interval`.
func (w *CloseWorker) Start() {
	go w.run()
}

// Stop signals the worker to exit and waits for the active tick to
// finish. Safe to call multiple times.
func (w *CloseWorker) Stop() {
	w.stopOnce.Do(func() { close(w.stopCh) })
	<-w.doneCh
}

func (w *CloseWorker) run() {
	defer close(w.doneCh)

	ticker := time.NewTicker(w.interval)
	defer ticker.Stop()

	w.tick()

	for {
		select {
		case <-w.stopCh:
			return
		case <-ticker.C:
			w.tick()
		}
	}
}

func (w *CloseWorker) tick() {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()

	now := time.Now().UTC()

	// Make sure both the current and the immediately-previous season
	// have rows. Without this, a season that was never observed by
	// /seasons/current (e.g. low-traffic period) would have nothing for
	// the close pass to find.
	if _, err := w.service.GetCurrentSeason(ctx, now); err != nil {
		w.logger.Warn("seasons worker: ensure current season failed", zap.Error(err))
	}
	prevYear, prevHalf := previousSeason(now)
	if _, err := w.service.repo.GetOrCreateSeason(ctx, prevYear, prevHalf); err != nil {
		w.logger.Warn("seasons worker: ensure previous season failed",
			zap.Int("year", prevYear), zap.Int("half", prevHalf), zap.Error(err))
	}

	if err := w.service.CloseDueSeasons(ctx, now, w.snap); err != nil {
		w.logger.Error("seasons worker: close pass failed", zap.Error(err))
		return
	}
}

// previousSeason returns the (year, half) immediately before the season
// containing `now`. Half=1 wraps back to the prior year's half=2.
func previousSeason(now time.Time) (year, half int) {
	curYear, curHalf := SeasonForTime(now)
	if curHalf == 1 {
		return curYear - 1, 2
	}
	return curYear, 1
}
