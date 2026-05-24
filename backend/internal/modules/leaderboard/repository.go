package leaderboard

import (
	"context"

	"github.com/jmoiron/sqlx"
	"github.com/lib/pq"
)

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository {
	return &Repository{db: db}
}

type userRegion struct {
	H3Res5 *string `db:"h3_res5"`
	H3Res4 *string `db:"h3_res4"`
	H3Res2 *string `db:"h3_res2"`
}

func (r *Repository) getUserRegion(ctx context.Context, userID string) (*userRegion, error) {
	var reg userRegion
	err := r.db.GetContext(ctx, &reg, `
		SELECT h3_res5, h3_res4, h3_res2
		FROM users
		WHERE id = $1
	`, userID)
	if err != nil {
		return nil, err
	}
	return &reg, nil
}

func (r *Repository) getUserProfiles(ctx context.Context, userIDs []string) (map[string]userProfile, error) {
	if len(userIDs) == 0 {
		return map[string]userProfile{}, nil
	}

	var rows []userProfile
	err := r.db.SelectContext(ctx, &rows, `
		SELECT
			u.id                                            AS user_id,
			COALESCE(u.username, '')                        AS username,
			COALESCE(p.display_name, u.username, '')        AS display_name,
			COALESCE(p.avatar_url, '')                      AS avatar_url,
			COALESCE(w.total_received_amount / 100, 0)      AS gold_seals
		FROM users u
		LEFT JOIN profiles p ON p.user_id = u.id
		LEFT JOIN wallets  w ON w.user_id = u.id AND w.currency = 'GOLD_SEAL'
		WHERE u.id = ANY($1)
	`, pq.Array(userIDs))
	if err != nil {
		return nil, err
	}

	out := make(map[string]userProfile, len(rows))
	for _, row := range rows {
		out[row.UserID] = row
	}
	return out, nil
}
