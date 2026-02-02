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
