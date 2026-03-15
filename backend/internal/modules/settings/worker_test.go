package settings

import (
	"context"
	"sync"
	"testing"
	"time"
)

func TestWorker_StartAppliesDueFeedLimitsImmediately(t *testing.T) {
	called := make(chan struct{}, 1)
	var once sync.Once

	repo := &testRepo{
		applyDueFeedLimitsFn: func(ctx context.Context, now time.Time) error {
			once.Do(func() {
				called <- struct{}{}
			})
			return nil
		},
	}
	service := NewService(repo, nil)
	worker := NewWorker(service)
	worker.Start()
	defer worker.Stop()

	select {
	case <-called:
	case <-time.After(500 * time.Millisecond):
		t.Fatal("expected ApplyDueFeedLimits to be called on worker start")
	}
}
