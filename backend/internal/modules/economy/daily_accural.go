package economy

import (
	"context"
	"time"

	"github.com/jmoiron/sqlx"
	"github.com/google/uuid"
)

// gpt тут посотовал использовать такие консты

const (
	silverUnit int64 = 10
	dailyAccuralUnits = silverUnit / 2
	maxFreeBalanceUnits = silverUnit * 5
	systemAccountID = "00000000-0000-0000-0000-000000000000"
)

// один раз за день вызывать эту функцию, в роли батчера
func RunDailyAccural(ctx context.Context, db *sqlx.DB) (DailyAccrualResult, error) {
	type walletRow struct {
		UserID string `db:"user_id"`
		SilverBalance int64 `db:"silver_balance"`
	}

	var wallets []walletRow
	if err := db.SelectContext(ctx, &wallets, `
	SELECT user_id, silver_balance
	FROM wallets
	WHERE silver_balance < $1
	`, maxFreeBalanceUnits); err != nil {
		return DailyAccrualResult{}, err
	}

	result := DailyAccrualResult{ProcessedUsers: len(wallets)}
	for _, w := range wallets {
		add := dailyAccuralUnits
		remaining := maxFreeBalanceUnits- w.SilverBalance
		if remaining < add {
			add = remaining
		}
		if add <= 0 {
			continue
		}

		if err := accrueToUser(ctx, db, w.UserID, add); err != nil {
			return result, err
		}
		result.AccruedUsers++
		result.TotalUnits += add
	}

	return result, nil
}


// ledger entries пишет в одну транзакцию

func accrueToUser(ctx context.Context, db *sqlx.DB, userID string, amount int64) error {
	tx, err := db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	// Update wallet balance.
	if _, err := tx.ExecContext(ctx, `
		UPDATE wallets
		SET silver_balance = silver_balance + $1, updated_at = $2
		WHERE user_id = $3
	`, amount, time.Now(), userID); err != nil {
		return err
	}

	// Ledger double-entry (system -> user).
	txID := uuid.NewString()
	now := time.Now()

	// System account DEBIT
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO ledger_entries (id, transaction_id, account_id, amount, currency, type, reason, created_at)
		VALUES ($1, $2, $3, $4, 'SILVER', 'DEBIT', 'DAILY_ACCRUAL', $5)
	`, uuid.NewString(), txID, systemAccountID, amount, now); err != nil {
		return err
	}

	// User account CREDIT
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO ledger_entries (id, transaction_id, account_id, amount, currency, type, reason, created_at)
		VALUES ($1, $2, $3, $4, 'SILVER', 'CREDIT', 'DAILY_ACCRUAL', $5)
	`, uuid.NewString(), txID, userID, amount, now); err != nil {
		return err
	}

	if err := tx.Commit(); err != nil {
		return err
	}

	return nil
}