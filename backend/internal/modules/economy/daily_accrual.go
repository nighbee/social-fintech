package economy

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

// RunDailyAccrual applies daily free silver to eligible wallets.
// It respects free balance cap and last_daily_accrual_at.
func RunDailyAccrual(ctx context.Context, db *sqlx.DB) (DailyAccrualResult, error) {
	type walletRow struct {
		ID          string     `db:"id"`
		UserID      string     `db:"user_id"`
		FreeBalance int64      `db:"free_balance"`
		LastAccrual *time.Time `db:"last_daily_accrual_at"`
	}

	var wallets []walletRow
	err := db.SelectContext(ctx, &wallets, `
		SELECT id, user_id, free_balance, last_daily_accrual_at
		FROM wallets
		WHERE currency = 'SILVER_SEAL'
		  AND free_balance < $1
		  AND (
		    last_daily_accrual_at IS NULL
		    OR last_daily_accrual_at < NOW() - INTERVAL '24 hours'
		  )
	`, MaxFreeSilverCents)
	if err != nil {
		return DailyAccrualResult{}, err
	}

	result := DailyAccrualResult{ProcessedUsers: len(wallets)}
	for _, w := range wallets {
		add := int64(DailyAccrualCents)
		remaining := int64(MaxFreeSilverCents) - w.FreeBalance
		if remaining < add {
			add = remaining
		}
		if add <= 0 {
			continue
		}

		if err := accrueToWallet(ctx, db, w.ID, w.UserID, add); err != nil {
			return result, err
		}
		result.AccruedUsers++
		result.TotalUnits += add
	}

	return result, nil
}

// accrueToWallet updates wallet and writes ledger entry in one transaction.
func accrueToWallet(ctx context.Context, db *sqlx.DB, walletID, userID string, amount int64) error {
	tx, err := db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	now := time.Now()
	referenceID := "accrual_" + userID + "_" + now.Format("2006-01-02")

	// Idempotency check
	var existingID string
	err = tx.GetContext(ctx, &existingID, `
		SELECT id FROM ledger_entries WHERE reference_id = $1
	`, referenceID)
	if err == nil && existingID != "" {
		return nil
	}

	// Update wallet balance + free balance + last_daily_accrual_at
	if _, err := tx.ExecContext(ctx, `
		UPDATE wallets
		SET balance = balance + $1,
		    free_balance = free_balance + $1,
		    last_daily_accrual_at = $2,
		    updated_at = $2
		WHERE id = $3
	`, amount, now, walletID); err != nil {
		return err
	}

	// Ledger entry (system mint -> user wallet)
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO ledger_entries (
			id, amount, currency, sender_wallet_id, receiver_wallet_id,
			category, reference_id, metadata, created_at
		) VALUES ($1, $2, 'SILVER_SEAL', NULL, $3, 'DAILY_ACCRUAL', $4, '{}'::jsonb, $5)
	`, uuid.NewString(), amount, walletID, referenceID, now); err != nil {
		return err
	}

	return tx.Commit()
}


