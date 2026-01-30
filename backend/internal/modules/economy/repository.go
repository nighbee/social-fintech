package economy

import (
	"context"
	"database/sql"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

type Repository struct {
	db *sqlx.DB
}

func NewRepository (db *sqlx.DB) *Repository {
	return &Repository{db: db}
}

//returns wallet by user id
func (r *Repository) GetWallet(ctx context.Context, userID string) (*Wallet, error) {
	var w Wallet

	if err := r.db.GetContext(ctx, &w, `SELECT * FROM wallets WHERE user_id = $1`, userID); err != nil {
		return nil, err
	}

	return &w, nil
}

func (r *Repository) CreateWallet(ctx context.Context, userID string) (*Wallet, error) {
	now := time.Now()

	_, err := r.db.ExecContext(ctx, `
	INSERT INTO wallets (user_id, silver_balance, gold_balance, created_at, updated_at)
	VALUES ($1, 0, 0, $2, $2)
	`, userID, now)

	if err != nil {
		return nil, err
	}

	return r.GetWallet(ctx, userID)
}

//returns ledger hisotry for user
func (r *Repository) ListLedgerEntries(ctx context.Context, userID string, limit int) ([]LedgerEntry, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	} 

	var items []LedgerEntry
	err := r.db.SelectContext(ctx, &items, `
	SELECT * FROM ledger_entries
	WHERE account_id = $1
	ORDER BY created_at DESC
	LIMIT $2
	`, userID, limit)
	return items, err
}

func (r *Repository) SumMonthlyDebit(ctx context.Context, userID string, currency Currency, reason string, from time.Time) (int64, error) {
	var sum sql.NullInt64
	
	err := r.db.GetContext(ctx, &sum, `
	SELECT COALESCE(SUM(amount), 0) AS total
	FROM ledger_entries
	WHERE account_id = $1
		AND currency = $2
		AND type = 'DEBIT'
		AND reason = $3
		AND created_at >= $4
	`, userID, currency, reason, from)

	if err != nil {
		return 0, nil
	}

	if sum.Valid {
		return sum.Int64, err
	}

	return 0, nil
}


//return existing inteacrtions
func (r *Repository) GetInteraction(ctx context.Context, senderID, receiverID string) (*UserInteraction, error) {
	var ui UserInteraction
	err := r.db.GetContext(ctx, &ui, `
	SELECT * FROM user_interactions
	WHERE sender_id = $1 AND receiver_id = $2
	`, senderID, receiverID)

	if err != nil {
		return nil, err
	}

	return &ui, err
}

func (r *Repository) TransferTx(ctx context.Context, fromUserID, toUserID string, amount int64, currency Currency, reason string) (*TransferResponse, error) {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return nil, err
	}

	defer func() {_ = tx.Rollback() }()

	//load wallets but updt

	var fromW Wallet
	if err := tx.GetContext(ctx, &fromW, `SELECT * FROM wallets WHERE user_id = $1 FOR UPDATE`, fromUserID); err != nil {
		return nil, err
	}

	var toW Wallet
	if err := tx.GetContext(ctx, &toW, `SELECT * FROM wallets WHERE user_id = $1 FOR UPDATE`, toUserID); err != nil {
		return nil, err
	}

	//balance check
	switch currency {
	case CurrencySilver:
		if fromW.SilverBalance < amount {
			return nil, ErrInsufficientFunds
		}
	case CurrencyGold:
		if fromW.GoldBalance < amount {
			return nil, ErrInsufficientFunds
		}
	default:
		return nil, ErrInvalidCurrency
	}

	now := time.Now()
	txID := uuid.NewString()

	//update wallets
	if currency == CurrencySilver {
		_, err := tx.ExecContext(ctx, `
		UPDATE wallets SET silver_balance = silver_balance - $1, updated_at = $2 WHERE user_id = $3
		`, amount, now, fromUserID)
		if err != nil {
			return nil, err
		}
	}

	_, err = tx.ExecContext(ctx, `
	UPDATE wallets SET silver_balance = silver_balance + $1, updated_at = $2 WHERE user_id = $3
	`, amount, now, toUserID)

	if err != nil {
		return nil, err
	} else {
		_, err := tx.ExecContext(ctx, `
		UPDATE wallets SET gold_balance = gold_balace - $1, updated_at = $2 WHERE user_id = $3
		`, amount, now, fromUserID)
		if err != nil {
			return nil, err
		}

		_, err = tx.ExecContext(ctx, `
		UPDATE wallets SET gold_balance = gold_balance + $1, updated_at = $2 WHERE user_id = $3
		`, amount, now, toUserID)
		if err != nil {
			return nil, err
		}
	}

	//ledger entries (double entry 
	_, err = tx.ExecContext(ctx, `
	INSERT INTO ledger_entries (id, transaction_id, account_id, amount, currency, type, reason, created_at)
	VALUES ($1, $2, $3, $4, $5, 'DEBIT', $6, $7)
	`, uuid.NewString(), txID, fromUserID, amount, currency, reason, now)
	if err != nil {
		return nil, err
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO ledger_entries (id, transaction_id, account_id, amount, currency, type, reason, created_at)
		VALUES ($1, $2, $3, $4, $5, 'CREDIT', $6, $7)
	`, uuid.NewString(), txID, toUserID, amount, currency, reason, now)
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(); err != nil {
		return nil, err
	}

	return &TransferResponse{
		TransactionID: txID,
		FromUserID: fromUserID,
		ToUserID: toUserID,
		Amount: amount,
		Currency: currency,
		Reason: reason,
		CreatedAt: now,
	}, nil
}