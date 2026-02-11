package ranks

import (
	"context"
	"database/sql"

	"github.com/jmoiron/sqlx"
)

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) GetUserGoldSeals(ctx context.Context, userID string) (int, error) {
	var balance int64
	err := r.db.GetContext(ctx, &balance, `
		SELECT COALESCE(balance / 100, 0)
		FROM wallets
		WHERE user_id = $1 AND currency = 'GOLD_SEAL'
	`, userID)

	if err == sql.ErrNoRows {
		return 0, nil
	}
	if err != nil {
		return 0, err
	}

	return int(balance), nil
}
