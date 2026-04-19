package settings

import (
	"context"
	"log"
	"sync"
	"time"
)

type Worker struct {
	service *Service

	mu      sync.Mutex
	running bool
	ctx     context.Context
	cancel  context.CancelFunc
	wg      sync.WaitGroup
}

func NewWorker(service *Service) *Worker {
	return &Worker{service: service}
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
		ticker := time.NewTicker(1 * time.Hour)
		defer ticker.Stop()

		if err := w.service.ApplyDueFeedLimits(ctx); err != nil {
			log.Printf("[Settings Worker] initial apply due feed limits failed: %v", err)
		}

		for {
			select {
			case <-ticker.C:
				if err := w.service.ApplyDueFeedLimits(ctx); err != nil {
					log.Printf("[Settings Worker] apply due feed limits failed: %v", err)
				}
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
