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

// GetUserGoldSeals returns the total Gold Seals the user has *received*
// (lifetime, divided into whole seals). Per the ranks spec the rank is
// driven by received seals only — purchases or transfers out must not
// affect rank. Sourced from wallets.total_received_amount, which is
// incremented atomically alongside balance on every credit.
func (r *Repository) GetUserGoldSeals(ctx context.Context, userID string) (int, error) {
	var received int64
	err := r.db.GetContext(ctx, &received, `
		SELECT COALESCE(total_received_amount / 100, 0)
		FROM wallets
		WHERE user_id = $1 AND currency = 'GOLD_SEAL'
	`, userID)

	if err == sql.ErrNoRows {
		return 0, nil
	}
	if err != nil {
		return 0, err
	}

	return int(received), nil
}
