package settings

import (
	"context"
	"sync"
	"testing"
	"time"
)

func TestHardDeleteWorker_StartAppliesDueHardDeletesImmediately(t *testing.T) {
	called := make(chan struct{}, 1)
	var once sync.Once

	repo := &testRepo{
		listDueHardDeleteUserIDs: func(ctx context.Context, now time.Time, limit int) ([]string, error) {
			once.Do(func() {
				called <- struct{}{}
			})
			return nil, nil
		},
	}

	service := NewService(repo, nil)
	worker := NewHardDeleteWorker(service)
	worker.Start()
	defer worker.Stop()

	select {
	case <-called:
	case <-time.After(500 * time.Millisecond):
		t.Fatal("expected ApplyDueHardDeletes to be called on worker start")
	}
}
