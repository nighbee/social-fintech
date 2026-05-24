package seasons

import (
	"context"
	"sync"
	"time"

	"github.com/brightbund-backend/internal/platform/eventbus"
	"go.uber.org/zap"
)

type CloseWorker struct {
	service  *Service
	snap     SnapshotProvider
	interval time.Duration
	logger   *zap.Logger

	stopOnce sync.Once
	stopCh   chan struct{}
	doneCh   chan struct{}

	lastWarning map[string]bool
}

func NewCloseWorker(service *Service, snap SnapshotProvider, interval time.Duration, logger *zap.Logger) *CloseWorker {
	if interval <= 0 {
		interval = time.Hour
	}
	if logger == nil {
		logger = zap.NewNop()
	}
	return &CloseWorker{
		service:     service,
		snap:        snap,
		interval:    interval,
		logger:      logger,
		stopCh:      make(chan struct{}),
		doneCh:      make(chan struct{}),
		lastWarning: make(map[string]bool),
	}
}

func (w *CloseWorker) Start() {
	go w.run()
}

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

	current, err := w.service.GetCurrentSeason(ctx, now)
	if err != nil {
		w.logger.Warn("seasons worker: ensure current season failed", zap.Error(err))
	} else {
		daysLeft := current.SecondsRemaining / 86400
		if daysLeft <= 7 && w.service.eventBus != nil {
			seasonKey := current.Season.ID.String()
			if !w.lastWarning[seasonKey] {
				w.lastWarning[seasonKey] = true
				w.logger.Info("seasons worker: firing season warning",
					zap.String("season_id", current.Season.ID.String()),
					zap.Int64("days_left", daysLeft))
				_ = w.service.eventBus.Publish(ctx, eventbus.TypeSeasonWarning, eventbus.LeaderboardEvent{
					BaseEvent: eventbus.BaseEvent{
						Type:      eventbus.TypeSeasonWarning,
						Timestamp: time.Now(),
					},
					SeasonID: current.Season.ID.String(),
					DaysLeft: int(daysLeft),
				})
			}
		}
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

func previousSeason(now time.Time) (year, half int) {
	curYear, curHalf := SeasonForTime(now)
	if curHalf == 1 {
		return curYear - 1, 2
	}
	return curYear, 1
}
