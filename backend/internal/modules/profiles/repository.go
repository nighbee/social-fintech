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
			COALESCE(p.location_country, '') as location_country,
			COALESCE(p.location_city, '') as location_city, 
			p.is_profile_public, 
			COALESCE(w.balance / 100, 0) as reputation_score,
			COALESCE(u.feed_time_limit_mins, 20) as feed_time_limit_mins,
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

	// Start transaction for atomic updates
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin transaction failed: %w", err)
	}
	defer tx.Rollback()

	// Update users table (first_name, last_name) if provided
	if req.FirstName != nil || req.LastName != nil {
		userUpdates := []string{}
		userArgs := []interface{}{}
		argPos := 1

		if req.FirstName != nil {
			userUpdates = append(userUpdates, fmt.Sprintf("first_name = $%d", argPos))
			userArgs = append(userArgs, *req.FirstName)
			argPos++
		}
		if req.LastName != nil {
			userUpdates = append(userUpdates, fmt.Sprintf("last_name = $%d", argPos))
			userArgs = append(userArgs, *req.LastName)
			argPos++
		}

		if len(userUpdates) > 0 {
			userUpdates = append(userUpdates, "updated_at = NOW()")
			userArgs = append(userArgs, userID)
			userQuery := fmt.Sprintf("UPDATE users SET %s WHERE id = $%d",
				strings.Join(userUpdates, ", "), argPos)

			_, err = tx.ExecContext(ctx, userQuery, userArgs...)
			if err != nil {
				return nil, fmt.Errorf("update user info failed: %w", err)
			}
		}
	}

	// Handle feed_time_limit_mins being stored in the users table
	if req.FeedTimeLimitMins != nil {
		validLimits := map[int]bool{0: true, 20: true, 30: true, 40: true}
		if !validLimits[*req.FeedTimeLimitMins] {
			return nil, fmt.Errorf("invalid feed_time_limit_mins: must be 0, 20, 30, or 40")
		}
		_, err = tx.ExecContext(ctx,
			"UPDATE users SET feed_time_limit_mins = $1, updated_at = NOW() WHERE id = $2",
			*req.FeedTimeLimitMins, userID)
		if err != nil {
			return nil, fmt.Errorf("update feed time limit failed: %w", err)
		}
	}

	// Build profile updates dynamically based on provided fields
	profileUpdates := []string{}
	profileArgs := []interface{}{}
	argPos := 1

	// Handle display_name logic:
	// If first_name or last_name updated, auto-sync display_name
	// Otherwise, use provided display_name if present
	if req.FirstName != nil || req.LastName != nil {
		// Get the updated first_name and last_name from users table
		var firstName, lastName string
		err = tx.QueryRowContext(ctx, `
			SELECT COALESCE(first_name, ''), COALESCE(last_name, '')
			FROM users
			WHERE id = $1
		`, userID).Scan(&firstName, &lastName)
		if err != nil {
			return nil, fmt.Errorf("failed to get updated user names: %w", err)
		}

		// Auto-generate display_name from the updated names
		displayName := strings.TrimSpace(firstName + " " + lastName)
		profileUpdates = append(profileUpdates, fmt.Sprintf("display_name = $%d", argPos))
		profileArgs = append(profileArgs, displayName)
		argPos++
	} else if req.DisplayName != nil {
		// Only use provided display_name if first_name/last_name are not being updated
		profileUpdates = append(profileUpdates, fmt.Sprintf("display_name = $%d", argPos))
		profileArgs = append(profileArgs, *req.DisplayName)
		argPos++
	}

	// Update other profile fields if provided
	if req.Bio != nil {
		profileUpdates = append(profileUpdates, fmt.Sprintf("bio = $%d", argPos))
		profileArgs = append(profileArgs, *req.Bio)
		argPos++
	}
	if req.AvatarURL != nil {
		profileUpdates = append(profileUpdates, fmt.Sprintf("avatar_url = $%d", argPos))
		profileArgs = append(profileArgs, *req.AvatarURL)
		argPos++
	}
	if req.Country != nil {
		profileUpdates = append(profileUpdates, fmt.Sprintf("location_country = $%d", argPos))
		profileArgs = append(profileArgs, *req.Country)
		argPos++
	}
	if req.City != nil {
		profileUpdates = append(profileUpdates, fmt.Sprintf("location_city = $%d", argPos))
		profileArgs = append(profileArgs, *req.City)
		argPos++
	}
	if req.IsPublic != nil {
		profileUpdates = append(profileUpdates, fmt.Sprintf("is_profile_public = $%d", argPos))
		profileArgs = append(profileArgs, *req.IsPublic)
		argPos++
	}

	// Execute profile update if there are fields to update
	if len(profileUpdates) > 0 {
		profileUpdates = append(profileUpdates, "updated_at = NOW()")
		profileArgs = append(profileArgs, userID)
		profileQuery := fmt.Sprintf("UPDATE profiles SET %s WHERE user_id = $%d",
			strings.Join(profileUpdates, ", "), argPos)

		_, err = tx.ExecContext(ctx, profileQuery, profileArgs...)
		if err != nil {
			return nil, fmt.Errorf("update profile failed: %w", err)
		}
	}

	// Commit transaction
	if err = tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit transaction failed: %w", err)
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
		SELECT 
			COALESCE(SUM(total_sent_amount), 0) AS total_sent,
			COALESCE(SUM(total_received_amount), 0) AS total_received
		FROM wallets 
		WHERE user_id = $1
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

func (r *Repository) GetAllies(ctx context.Context, userID, searchQuery string, limit, offset int) ([]AllyProfile, error) {
	// Initialize as empty slice so JSON returns [] instead of null when empty
	allies := []AllyProfile{}
	searchPattern := "%"
	if searchQuery != "" {
		searchPattern = "%" + strings.ToLower(strings.TrimSpace(searchQuery)) + "%"
	}

	err := r.db.SelectContext(ctx, &allies, `
		SELECT 
			p.user_id,
			COALESCE(p.display_name, '') as display_name,
			COALESCE(p.avatar_url, '') as avatar_url,
			COALESCE(w.balance / 100, 0) as reputation_score
		FROM user_relationships r
		JOIN profiles p ON r.user_id = p.user_id
		JOIN users u ON u.id = p.user_id
		LEFT JOIN wallets w ON p.user_id = w.user_id AND w.currency = 'GOLD_SEAL'
		WHERE r.target_user_id = $1 AND r.relationship_type = 'ally'
		  AND (
		  	LOWER(COALESCE(p.display_name, '')) LIKE $2
		  	OR LOWER(COALESCE(u.first_name, '')) LIKE $2
		  	OR LOWER(COALESCE(u.last_name, '')) LIKE $2
		  )
		ORDER BY r.created_at DESC
		LIMIT $3 OFFSET $4
	`, userID, searchPattern, limit, offset)
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

func (r *Repository) GetRelationshipStatus(ctx context.Context, currentUserID, targetUserID string) (*RelationshipStatus, error) {
	type relationshipRow struct {
		UserID           string `db:"user_id"`
		TargetUserID     string `db:"target_user_id"`
		RelationshipType string `db:"relationship_type"`
	}

	var rows []relationshipRow
	err := r.db.SelectContext(ctx, &rows, `
		SELECT user_id, target_user_id, relationship_type
		FROM user_relationships
		WHERE (user_id = $1 AND target_user_id = $2)
		   OR (user_id = $2 AND target_user_id = $1)
	`, currentUserID, targetUserID)
	if err != nil {
		return nil, fmt.Errorf("get relationship status failed: %w", err)
	}

	status := &RelationshipStatus{
		UserID:          targetUserID,
		IFollowThem:     false,
		TheyFollowMe:    false,
		IBlockedThem:    false,
		TheyBlockedMe:   false,
		IRestrictedThem: false,
	}

	// Process all matching relationships
	for _, row := range rows {
		if row.UserID == currentUserID && row.TargetUserID == targetUserID {
			// Current user -> Target user relationships
			switch row.RelationshipType {
			case "ally":
				status.IFollowThem = true
			case "block":
				status.IBlockedThem = true
			case "restrict":
				status.IRestrictedThem = true
			}
		} else if row.UserID == targetUserID && row.TargetUserID == currentUserID {
			// Target user -> Current user relationships
			switch row.RelationshipType {
			case "ally":
				status.TheyFollowMe = true
			case "block":
				status.TheyBlockedMe = true
			}
		}
	}

	return status, nil
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

// SearchUsersByName ищет пользователей по имени/фамилии (LIKE)
func (r *Repository) SearchUsersByName(ctx context.Context, firstName, lastName string, limit int) ([]UserSearchResult, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 50 {
		limit = 50
	}

	firstPattern := "%"
	lastPattern := "%"
	if firstName != "" {
		firstPattern = "%" + strings.ToLower(firstName) + "%"
	}
	if lastName != "" {
		lastPattern = "%" + strings.ToLower(lastName) + "%"
	}

	// Initialize as empty slice so JSON returns [] instead of null when empty
	rows := []UserSearchResult{}
	err := r.db.SelectContext(ctx, &rows, `
		SELECT
			u.id as user_id,
			COALESCE(u.first_name, '') as first_name,
			COALESCE(u.last_name, '') as last_name,
			COALESCE(p.display_name, '') as display_name,
			COALESCE(p.avatar_url, '') as avatar_url
		FROM users u
		LEFT JOIN profiles p ON p.user_id = u.id
		WHERE u.is_shadow_banned = false
		  AND LOWER(COALESCE(u.first_name, '')) LIKE $1
		  AND LOWER(COALESCE(u.last_name, '')) LIKE $2
		ORDER BY u.first_name, u.last_name
		LIMIT $3
	`, firstPattern, lastPattern, limit)
	if err != nil {
		return nil, fmt.Errorf("search users failed: %w", err)
	}
	return rows, nil
}

// SearchProfilesForFeed ищет профили с учетом приватности и блокировок
func (r *Repository) SearchProfilesForFeed(ctx context.Context, currentUserID, query string, limit, offset int) ([]ProfileSearchResult, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 50 {
		limit = 50
	}
	if offset < 0 {
		offset = 0
	}

	pattern := "%" + strings.ToLower(query) + "%"

	// Initialize as empty slice so JSON returns [] instead of null when empty
	rows := []ProfileSearchResult{}
	err := r.db.SelectContext(ctx, &rows, `
		SELECT
			u.id as user_id,
			COALESCE(p.display_name, '') as display_name,
			COALESCE(p.avatar_url, '') as avatar_url,
			COALESCE(w.balance / 100, 0) as reputation_score
		FROM users u
		JOIN profiles p ON p.user_id = u.id
		LEFT JOIN wallets w ON u.id = w.user_id AND w.currency = 'GOLD_SEAL'
		LEFT JOIN user_relationships blocked ON blocked.user_id = $1 
			AND blocked.target_user_id = u.id 
			AND blocked.relationship_type = 'block'
		LEFT JOIN user_relationships blocked_by ON blocked_by.user_id = u.id 
			AND blocked_by.target_user_id = $1 
			AND blocked_by.relationship_type = 'block'
		LEFT JOIN user_relationships ally ON ally.user_id = $1 
			AND ally.target_user_id = u.id 
			AND ally.relationship_type = 'ally'
		WHERE u.id != $1
		  AND u.is_shadow_banned = false
		  AND blocked.id IS NULL
		  AND blocked_by.id IS NULL
		  AND (p.is_profile_public = true OR ally.id IS NOT NULL)
		  AND (
			  LOWER(COALESCE(u.first_name, '')) LIKE $2
			  OR LOWER(COALESCE(u.last_name, '')) LIKE $2
			  OR LOWER(COALESCE(p.display_name, '')) LIKE $2
		  )
		ORDER BY w.balance DESC NULLS LAST, u.first_name, u.last_name
		LIMIT $3 OFFSET $4
	`, currentUserID, pattern, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("search profiles for feed failed: %w", err)
	}
	return rows, nil
}
