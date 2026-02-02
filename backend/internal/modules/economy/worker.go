package economy

import (
	"context"
	"log"
	"time"
)

type Worker struct {
	service Service
	repo    Repository
	ticker  *time.Ticker
	done    chan bool
}

func NewWorker(service Service, repo Repository) *Worker {
	return &Worker{
		service: service,
		repo:    repo,
		done:    make(chan bool),
	}
}

func (w *Worker) Start() {
	w.ticker = time.NewTicker(1 * time.Hour)

	go func() {
		log.Println("[Economy Worker] Starting economy background worker")

		w.EnsureUserWallets()
		w.ProcessDailyAccruals()

		for {
			select {
			case <-w.ticker.C:
				w.EnsureUserWallets()
				w.ProcessDailyAccruals()
			case <-w.done:
				w.ticker.Stop()
				log.Println("[Economy Worker] Stopped")
				return
			}
		}
	}()
}

func (w *Worker) Stop() {
	w.done <- true
}

func (w *Worker) EnsureUserWallets() {
	ctx := context.Background()
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

func (w *Worker) ProcessDailyAccruals() {
	ctx := context.Background()
	log.Println("[Economy Worker] Processing daily accruals...")

	query := `
		SELECT DISTINCT user_id 
		FROM wallets 
		WHERE currency = 'SILVER_SEAL'
		  AND free_balance < $1
		  AND (
		    last_daily_accrual_at IS NULL 
		    OR last_daily_accrual_at < NOW() - INTERVAL '48 hours'
		  )
	`

	var userIDs []string
	err := w.repo.GetDB().SelectContext(ctx, &userIDs, query, MaxFreeSilverCents)
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
