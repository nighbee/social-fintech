package profiles

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"
)

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) GetProfile(ctx context.Context, userID string) (*Profile, error) {
	var p Profile
	err := r.db.GetContext(ctx, &p, `SELECT * FROM profiles WHERE user_id = $1`, userID)
	if err == sql.ErrNoRows {
		return nil, ErrProfileNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("get profile failed: %w", err)
	}
	return &p, nil
}

func (r *Repository) CreateDefaultProfile(ctx context.Context, userID string) (*Profile, error) {
	now := time.Now()
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO profiles (user_id, is_public, created_at, updated_at)
		VALUES ($1, true, $2, $2)
	`, userID, now)
	if err != nil {
		return nil, fmt.Errorf("create profile failed: %w", err)
	}
	return r.GetProfile(ctx, userID)
}

func (r *Repository) UpdateProfile(ctx context.Context, userID string, req *UpdateProfileRequest) (*Profile, error) {
	query := `
		UPDATE profiles
		SET first_name = $1,
		    last_name = $2,
		    bio = $3,
		    avatar_url = $4,
		    country = $5,
		    region = $6,
		    city = $7,
		    is_public = COALESCE($8, is_public),
		    updated_at = NOW()
		WHERE user_id = $9
	`
	_, err := r.db.ExecContext(ctx, query,
		req.FirstName, req.LastName, req.Bio, req.AvatarURL,
		req.Country, req.Region, req.City, req.IsPublic, userID,
	)
	if err != nil {
		return nil, fmt.Errorf("update profile failed: %w", err)
	}
	return r.GetProfile(ctx, userID)
}

func (r *Repository) UpdateAvatarURL(ctx context.Context, userID, avatarURL string) (*Profile, error) {
	_, err := r.db.ExecContext(ctx, `
		UPDATE profiles
		SET avatar_url = $1,
		    updated_at = NOW()
		WHERE user_id = $2
	`, avatarURL, userID)
	if err != nil {
		return nil, fmt.Errorf("update avatar failed: %w", err)
	}
	return r.GetProfile(ctx, userID)
}

func (r *Repository) DeleteProfile(ctx context.Context, userID string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM profiles WHERE user_id = $1`, userID)
	if err != nil {
		return fmt.Errorf("delete profile failed: %w", err)
	}
	return nil
}

func (r *Repository) GetProfileStats(ctx context.Context, userID string) (*ProfileStats, error) {
	type balanceRow struct {
		Silver int64 `db:"silver_balance"`
		Gold   int64 `db:"gold_balance"`
	}
	var b balanceRow
	err := r.db.GetContext(ctx, &b, `
		SELECT
			COALESCE(SUM(CASE WHEN currency = 'SILVER_SEAL' THEN balance ELSE 0 END), 0) AS silver_balance,
			COALESCE(SUM(CASE WHEN currency = 'GOLD_SEAL' THEN balance ELSE 0 END), 0) AS gold_balance
		FROM wallets
		WHERE user_id = $1
	`, userID)
	if err != nil {
		return nil, fmt.Errorf("get balances failed: %w", err)
	}

	type totalsRow struct {
		Sent     int64 `db:"total_sent"`
		Received int64 `db:"total_received"`
	}
	var t totalsRow
	err = r.db.GetContext(ctx, &t, `
		WITH uw AS (SELECT id FROM wallets WHERE user_id = $1)
		SELECT
			COALESCE((SELECT SUM(amount) FROM ledger_entries WHERE sender_wallet_id IN (SELECT id FROM uw)), 0) AS total_sent,
			COALESCE((SELECT SUM(amount) FROM ledger_entries WHERE receiver_wallet_id IN (SELECT id FROM uw)), 0) AS total_received
	`, userID)
	if err != nil {
		return nil, fmt.Errorf("get totals failed: %w", err)
	}

	return &ProfileStats{
		UserID:        userID,
		SilverBalance: b.Silver,
		GoldBalance:   b.Gold,
		TotalSent:     t.Sent,
		TotalReceived: t.Received,
	}, nil
}
