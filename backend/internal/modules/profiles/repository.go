package profiles

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
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
	err := r.db.GetContext(ctx, &p, `
		SELECT 
			p.user_id, 
			COALESCE(p.display_name, '') as display_name, 
			COALESCE(u.first_name, '') as first_name,
			COALESCE(u.last_name, '') as last_name,
			COALESCE(TO_CHAR(u.date_of_birth, 'YYYY-MM-DD'), '') as date_of_birth,
			COALESCE(p.bio, '') as bio, 
			COALESCE(p.avatar_url, '') as avatar_url, 
			COALESCE(p.location_city, '') as location_city, 
			p.is_profile_public, 
			COALESCE(w.balance / 100, 0) as reputation_score,
			p.created_at, p.updated_at 
		FROM profiles p
		JOIN users u ON p.user_id = u.id
		LEFT JOIN wallets w ON p.user_id = w.user_id AND w.currency = 'GOLD_SEAL'
		WHERE p.user_id = $1`, userID)
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
		INSERT INTO profiles (user_id, is_profile_public, created_at, updated_at)
		VALUES ($1, true, $2, $2)
		ON CONFLICT (user_id) DO NOTHING
	`, userID, now)
	if err != nil {
		return nil, fmt.Errorf("create profile failed: %w", err)
	}
	return r.GetProfile(ctx, userID)
}

func (r *Repository) UpdateProfile(ctx context.Context, userID string, req *UpdateProfileRequest) (*Profile, error) {
	// Ensure profile exists first
	_, err := r.GetProfile(ctx, userID)
	if err == ErrProfileNotFound {
		if _, err := r.CreateDefaultProfile(ctx, userID); err != nil {
			return nil, err
		}
	} else if err != nil {
		return nil, err
	}

	// Construct display_name from FirstName + LastName if provided
	displayName := req.DisplayName
	if displayName == "" && (req.FirstName != "" || req.LastName != "") {
		displayName = strings.TrimSpace(req.FirstName + " " + req.LastName)
	}

	query := `
		UPDATE profiles
		SET display_name = COALESCE(NULLIF($1, ''), display_name),
		    bio = COALESCE(NULLIF($2, ''), bio),
		    avatar_url = COALESCE(NULLIF($3, ''), avatar_url),
		    location_country = COALESCE(NULLIF($4, ''), location_country),
		    location_city = COALESCE(NULLIF($5, ''), location_city),
		    is_profile_public = COALESCE($6, is_profile_public),
		    updated_at = NOW()
		WHERE user_id = $7
	`
	_, err = r.db.ExecContext(ctx, query,
		displayName, req.Bio, req.AvatarURL,
		req.Country, req.City, req.IsPublic, userID,
	)
	if err != nil {
		return nil, fmt.Errorf("update profile failed: %w", err)
	}
	return r.GetProfile(ctx, userID)
}

func (r *Repository) UpdateAvatarURL(ctx context.Context, userID, avatarURL string) (*Profile, error) {
	// Ensure profile exists first
	_, err := r.GetProfile(ctx, userID)
	if err == ErrProfileNotFound {
		if _, err := r.CreateDefaultProfile(ctx, userID); err != nil {
			return nil, err
		}
	} else if err != nil {
		return nil, err
	}

	_, err = r.db.ExecContext(ctx, `
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

func (r *Repository) AddAlly(ctx context.Context, userID, targetID string) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO user_relationships (user_id, target_user_id, relationship_type, created_at)
		VALUES ($1, $2, 'ally', NOW())
		ON CONFLICT (user_id, target_user_id, relationship_type) DO NOTHING
	`, userID, targetID)
	if err != nil {
		return fmt.Errorf("add ally failed: %w", err)
	}
	return nil
}

func (r *Repository) RemoveAlly(ctx context.Context, userID, targetID string) error {
	_, err := r.db.ExecContext(ctx, `
		DELETE FROM user_relationships 
		WHERE user_id = $1 AND target_user_id = $2 AND relationship_type = 'ally'
	`, userID, targetID)
	if err != nil {
		return fmt.Errorf("remove ally failed: %w", err)
	}
	return nil
}

func (r *Repository) GetAllies(ctx context.Context, userID string) ([]AllyProfile, error) {
	// Returns users who have 'ally' relationship WITH the target userID independent of direction?
	// User said "subscribers but named allies".
	// Subscriber = Someone who follows ME.
	// So we want: SELECT * FROM users WHERE id IN (SELECT user_id FROM relationships WHERE target_id = ME)
	var allies []AllyProfile
	err := r.db.SelectContext(ctx, &allies, `
		SELECT 
			p.user_id,
			COALESCE(p.display_name, '') as display_name,
			COALESCE(p.avatar_url, '') as avatar_url,
			COALESCE(w.balance / 100, 0) as reputation_score
		FROM user_relationships r
		JOIN profiles p ON r.user_id = p.user_id
		LEFT JOIN wallets w ON p.user_id = w.user_id AND w.currency = 'GOLD_SEAL'
		WHERE r.target_user_id = $1 AND r.relationship_type = 'ally'
		ORDER BY r.created_at DESC
	`, userID)
	if err != nil {
		return nil, fmt.Errorf("get allies failed: %w", err)
	}
	return allies, nil
}

func (r *Repository) BlockUser(ctx context.Context, userID, targetID string) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO user_relationships (user_id, target_user_id, relationship_type, created_at)
		VALUES ($1, $2, 'block', NOW())
		ON CONFLICT (user_id, target_user_id, relationship_type) DO NOTHING
	`, userID, targetID)
	if err != nil {
		return fmt.Errorf("block user failed: %w", err)
	}
	return nil
}

func (r *Repository) UnblockUser(ctx context.Context, userID, targetID string) error {
	_, err := r.db.ExecContext(ctx, `
		DELETE FROM user_relationships 
		WHERE user_id = $1 AND target_user_id = $2 AND relationship_type = 'block'
	`, userID, targetID)
	if err != nil {
		return fmt.Errorf("unblock user failed: %w", err)
	}
	return nil
}

func (r *Repository) RestrictUser(ctx context.Context, userID, targetID string) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO user_relationships (user_id, target_user_id, relationship_type, created_at)
		VALUES ($1, $2, 'restrict', NOW())
		ON CONFLICT (user_id, target_user_id, relationship_type) DO NOTHING
	`, userID, targetID)
	if err != nil {
		return fmt.Errorf("restrict user failed: %w", err)
	}
	return nil
}

func (r *Repository) UnrestrictUser(ctx context.Context, userID, targetID string) error {
	_, err := r.db.ExecContext(ctx, `
		DELETE FROM user_relationships 
		WHERE user_id = $1 AND target_user_id = $2 AND relationship_type = 'restrict'
	`, userID, targetID)
	if err != nil {
		return fmt.Errorf("unrestrict user failed: %w", err)
	}
	return nil
}

func (r *Repository) ReportUser(ctx context.Context, userID, targetID string, req *ReportRequest) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO user_reports (reporter_id, reported_user_id, reason, description, status, created_at)
		VALUES ($1, $2, $3, $4, 'pending', NOW())
	`, userID, targetID, req.Reason, req.Description)
	if err != nil {
		return fmt.Errorf("report user failed: %w", err)
	}
	return nil
}
