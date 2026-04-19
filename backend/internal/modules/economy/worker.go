package economy

import (
	"context"
	"log"
	"sync"
	"time"

	"github.com/brightbund-backend/internal/config"
)

type Worker struct {
	service Service
	repo    Repository
	cfg     config.EconomyConfig

	mu      sync.Mutex
	running bool
	ctx     context.Context
	cancel  context.CancelFunc
	wg      sync.WaitGroup
}

func NewWorker(service Service, repo Repository, cfg config.EconomyConfig) *Worker {
	return &Worker{
		service: service,
		repo:    repo,
		cfg:     cfg,
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

	ticker := time.NewTicker(1 * time.Hour)

	w.wg.Add(1)
	go func(ctx context.Context) {
		defer w.wg.Done()
		defer ticker.Stop()
		log.Println("[Economy Worker] Starting economy background worker")

		w.EnsureUserWallets(ctx)
		w.ProcessDailyAccruals(ctx)

		for {
			select {
			case <-ticker.C:
				w.EnsureUserWallets(ctx)
				w.ProcessDailyAccruals(ctx)
			case <-ctx.Done():
				log.Println("[Economy Worker] Stopped")
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

func (w *Worker) EnsureUserWallets(ctx context.Context) {
	log.Println("[Economy Worker] Checking for users without wallets...")

	query := `
		SELECT DISTINCT u.id 
		FROM users u
		WHERE NOT EXISTS (
			SELECT 1 FROM wallets w 
			WHERE w.user_id = u.id AND w.currency = 'SILVER_SEAL'
		)
	`

	var userIDs []string
	err := w.repo.GetDB().SelectContext(ctx, &userIDs, query)
	if err != nil {
		log.Printf("[Economy Worker] Failed to query users without wallets: %v", err)
		return
	}

	if len(userIDs) == 0 {
		log.Println("[Economy Worker] All users have wallets")
		return
	}

	log.Printf("[Economy Worker] Found %d users without wallets", len(userIDs))

	successCount := 0
	failCount := 0

	for _, userID := range userIDs {
		if err := w.service.GetOrCreateWallets(ctx, userID); err != nil {
			log.Printf("[Economy Worker] Failed to create wallets for user %s: %v", userID, err)
			failCount++
			continue
		}
		successCount++
	}

	log.Printf("[Economy Worker] Wallet creation: %d successful, %d failed", successCount, failCount)
}

func (w *Worker) ProcessDailyAccruals(ctx context.Context) {
	log.Println("[Economy Worker] Processing daily accruals...")

	query := `
		SELECT DISTINCT w.user_id
		FROM wallets w
		JOIN users u ON u.id = w.user_id
		WHERE currency = 'SILVER_SEAL'
		  AND free_balance < $1
		  AND (
		    last_daily_accrual_at IS NULL 
		    OR last_daily_accrual_at < NOW() - INTERVAL '48 hours'
		  )
	`

	var userIDs []string
	err := w.repo.GetDB().SelectContext(ctx, &userIDs, query, w.cfg.MaxFreeSilverBalance)
	if err != nil {
		log.Printf("[Economy Worker] Failed to get eligible users: %v", err)
		return
	}

	log.Printf("[Economy Worker] Found %d users eligible for daily accrual", len(userIDs))

	successCount := 0
	failCount := 0

	for _, userID := range userIDs {
		idempotencyKey := generateAccrualIdempotencyKey(userID)
		_, err := w.service.ClaimDailyAccrual(ctx, userID, idempotencyKey)
		if err != nil {
			if !IsDailyAccrualError(err) && !IsFreeSilverCapError(err) {
				log.Printf("[Economy Worker] Failed to process accrual for user %s: %v", userID, err)
				failCount++
			}
			continue
		}
		successCount++
	}

	log.Printf("[Economy Worker] Accruals processed: %d successful, %d failed", successCount, failCount)
}

func generateAccrualIdempotencyKey(userID string) string {
	now := time.Now().UTC()
	return "accrual_" + userID + "_" + now.Format("2006-01-02")
}
