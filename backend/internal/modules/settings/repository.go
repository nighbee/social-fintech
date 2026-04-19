package settings

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
	"github.com/lib/pq"
)

type TwoFAMethod struct {
	Method          string  `db:"method"`
	IsActive        bool    `db:"is_active"`
	SecretEncrypted *string `db:"secret_encrypted"`
}

type deleteAccountRequest struct {
	ID                  string     `db:"id"`
	UserID              string     `db:"user_id"`
	Reason              string     `db:"reason"`
	VerificationMethod  string     `db:"verification_method"`
	OTPCodeHash         *string    `db:"otp_code_hash"`
	VerificationToken   *string    `db:"verification_token"`
	VerificationExpires *time.Time `db:"verification_expires_at"`
	VerifiedAt          *time.Time `db:"verified_at"`
	CreatedAt           time.Time  `db:"created_at"`
}

type Repository interface {
	GetUserSettings(ctx context.Context, userID string) (*UserSettings, error)
	UpdateFeedLimitPending(ctx context.Context, userID string, pending int, applyAt time.Time) error
	ApplyDueFeedLimits(ctx context.Context, now time.Time) error
	ListDueHardDeleteUserIDs(ctx context.Context, now time.Time, limit int) ([]string, error)
	HardDeleteUser(ctx context.Context, userID string) error

	UpdateMessagesSettings(ctx context.Context, userID, whoCanMessage string, readStatus, safeMode *bool) error
	UpdateCommentsSettings(ctx context.Context, userID, whoCanComment string, filterUnwanted *bool) error
	UpdateMentionsSettings(ctx context.Context, userID, whoCanMention string) error
	ListMessageKeywords(ctx context.Context, userID string) ([]KeywordItem, error)
	AddMessageKeyword(ctx context.Context, userID, keyword string) (string, error)
	DeleteMessageKeyword(ctx context.Context, userID, keywordID string) error

	CountActiveSessions(ctx context.Context, userID string) (int, error)
	ListSessions(ctx context.Context, userID string) ([]SessionItem, error)
	RevokeSession(ctx context.Context, userID, sessionID string, revokedAt time.Time) error
	RevokeAllSessionsExcept(ctx context.Context, userID, currentSessionID string, revokedAt time.Time) error
	RevokeAllSessions(ctx context.Context, userID string, revokedAt time.Time) error

	GetUserPasswordHash(ctx context.Context, userID string) (string, error)
	UpdateUserPasswordHash(ctx context.Context, userID, passwordHash string, updatedAt time.Time) error

	GetActiveTwoFAMethods(ctx context.Context, userID string) ([]TwoFAMethod, error)
	UpsertTwoFAMethod(ctx context.Context, userID, method string, isActive bool, secret *string) error
	DeactivateAllTwoFAMethods(ctx context.Context, userID string) error
	GetUserPhone(ctx context.Context, userID string) (string, string, error)

	CreateDeleteRequest(ctx context.Context, userID, reason, verificationMethod string) (string, error)
	GetLatestDeleteRequest(ctx context.Context, userID string) (*deleteAccountRequest, error)
	SetDeleteOTPCodeHash(ctx context.Context, requestID, otpCodeHash string) error
	SetDeleteVerification(ctx context.Context, requestID, token string, expiresAt time.Time) error
	MarkDeleteRequestVerified(ctx context.Context, requestID string, verifiedAt time.Time) error
	SoftDeleteUser(ctx context.Context, userID string, deletedAt, hardDeleteAt time.Time) error

	CreateBugReport(ctx context.Context, userID string, req *BugReportRequest) error

	ListBlockedUsers(ctx context.Context, userID string, cursor *time.Time, limit int) ([]BlockedUserItem, error)
	UnblockUser(ctx context.Context, userID, targetUserID string) error
	IsBlockedBetween(ctx context.Context, actorID, targetID string) (bool, error)

	CreateAuditLog(ctx context.Context, userID, action string, details map[string]any) error

	GetFeedTimeLimit(ctx context.Context, userID string) (int, error)
	GetCommentPrivacy(ctx context.Context, userID string) (string, bool, error)
	GetMessagePrivacy(ctx context.Context, userID string) (string, bool, bool, error)
	GetMentionsPrivacy(ctx context.Context, userID string) (string, error)
}

type PostgresRepository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *PostgresRepository {
	return &PostgresRepository{db: db}
}

func (r *PostgresRepository) GetUserSettings(ctx context.Context, userID string) (*UserSettings, error) {
	var s UserSettings
	query := `
		SELECT
			user_id,
			feed_time_limit_current_mins,
			feed_time_limit_pending_mins,
			feed_time_limit_pending_apply_at,
			messages_who_can_message,
			messages_read_status_enabled,
			messages_safe_mode_enabled,
			comments_who_can_comment,
			comments_filter_unwanted_enabled,
			mentions_who_can_mention,
			participate_district_ranking
		FROM user_settings
		WHERE user_id = $1
	`
	if err := r.db.GetContext(ctx, &s, query, userID); err != nil {
		if isUndefinedTable(err) {
			defaults := defaultUserSettings(userID)
			return &defaults, nil
		}
		if isUndefinedColumn(err, "participate_district_ranking") {
			legacy, legacyErr := r.getUserSettingsLegacy(ctx, userID)
			if legacyErr != nil {
				return nil, legacyErr
			}
			return legacy, nil
		}
		if err == sql.ErrNoRows {
			_, _ = r.db.ExecContext(ctx, `INSERT INTO user_settings(user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING`, userID)
			if retryErr := r.db.GetContext(ctx, &s, query, userID); retryErr != nil {
				if isUndefinedColumn(retryErr, "participate_district_ranking") {
					legacy, legacyErr := r.getUserSettingsLegacy(ctx, userID)
					if legacyErr != nil {
						return nil, legacyErr
					}
					return legacy, nil
				}
				if isUndefinedTable(retryErr) {
					defaults := defaultUserSettings(userID)
					return &defaults, nil
				}
				return nil, retryErr
			}
			return &s, nil
		}
		return nil, err
	}
	return &s, nil
}

func (r *PostgresRepository) getUserSettingsLegacy(ctx context.Context, userID string) (*UserSettings, error) {
	var s UserSettings
	legacyQuery := `
		SELECT
			user_id,
			feed_time_limit_current_mins,
			feed_time_limit_pending_mins,
			feed_time_limit_pending_apply_at,
			messages_who_can_message,
			messages_read_status_enabled,
			messages_safe_mode_enabled,
			comments_who_can_comment,
			comments_filter_unwanted_enabled,
			mentions_who_can_mention
		FROM user_settings
		WHERE user_id = $1
	`
	if err := r.db.GetContext(ctx, &s, legacyQuery, userID); err != nil {
		if err == sql.ErrNoRows {
			defaults := defaultUserSettings(userID)
			return &defaults, nil
		}
		if isUndefinedTable(err) {
			defaults := defaultUserSettings(userID)
			return &defaults, nil
		}
		return nil, err
	}
	// This column was introduced later; default to true for backward compatibility.
	s.ParticipateDistrictRanking = true
	return &s, nil
}

func defaultUserSettings(userID string) UserSettings {
	return UserSettings{
		UserID:                     userID,
		FeedTimeLimitCurrentMins:   FeedLimit20,
		MessagesWhoCanMessage:      MessagePrivacyEveryone,
		MessagesReadStatusEnabled:  true,
		MessagesSafeModeEnabled:    false,
		CommentsWhoCanComment:      MessagePrivacyEveryone,
		CommentsFilterUnwanted:     false,
		MentionsWhoCanMention:      MessagePrivacyEveryone,
		ParticipateDistrictRanking: true,
	}
}

func (r *PostgresRepository) UpdateFeedLimitPending(ctx context.Context, userID string, pending int, applyAt time.Time) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE user_settings
		SET feed_time_limit_pending_mins = $2,
			feed_time_limit_pending_apply_at = $3,
			updated_at = NOW()
		WHERE user_id = $1
	`, userID, pending, applyAt)
	return err
}

func (r *PostgresRepository) ApplyDueFeedLimits(ctx context.Context, now time.Time) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE user_settings
		SET feed_time_limit_current_mins = feed_time_limit_pending_mins,
			feed_time_limit_pending_mins = NULL,
			feed_time_limit_pending_apply_at = NULL,
			updated_at = NOW()
		WHERE feed_time_limit_pending_mins IS NOT NULL
		  AND feed_time_limit_pending_apply_at IS NOT NULL
		  AND feed_time_limit_pending_apply_at <= $1
	`, now)
	return err
}

func (r *PostgresRepository) ListDueHardDeleteUserIDs(ctx context.Context, now time.Time, limit int) ([]string, error) {
	if limit <= 0 {
		limit = 100
	}

	items := make([]string, 0, limit)
	err := r.db.SelectContext(ctx, &items, `
		SELECT id
		FROM users
		WHERE deleted_at IS NOT NULL
		  AND hard_delete_scheduled_at IS NOT NULL
		  AND hard_delete_scheduled_at <= $1
		ORDER BY hard_delete_scheduled_at ASC
		LIMIT $2
	`, now, limit)
	if err != nil {
		return nil, err
	}
	return items, nil
}

func (r *PostgresRepository) HardDeleteUser(ctx context.Context, userID string) error {
	result, err := r.db.ExecContext(ctx, `
		DELETE FROM users
		WHERE id = $1
		  AND deleted_at IS NOT NULL
		  AND hard_delete_scheduled_at IS NOT NULL
	`, userID)
	if err != nil {
		return err
	}

	_, _ = result.RowsAffected()
	return nil
}

func (r *PostgresRepository) UpdateMessagesSettings(ctx context.Context, userID, whoCanMessage string, readStatus, safeMode *bool) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE user_settings
		SET messages_who_can_message = COALESCE(NULLIF($2, ''), messages_who_can_message),
			messages_read_status_enabled = COALESCE($3, messages_read_status_enabled),
			messages_safe_mode_enabled = COALESCE($4, messages_safe_mode_enabled),
			updated_at = NOW()
		WHERE user_id = $1
	`, userID, whoCanMessage, readStatus, safeMode)
	return err
}

func (r *PostgresRepository) UpdateCommentsSettings(ctx context.Context, userID, whoCanComment string, filterUnwanted *bool) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE user_settings
		SET comments_who_can_comment = COALESCE(NULLIF($2, ''), comments_who_can_comment),
			comments_filter_unwanted_enabled = COALESCE($3, comments_filter_unwanted_enabled),
			updated_at = NOW()
		WHERE user_id = $1
	`, userID, whoCanComment, filterUnwanted)
	return err
}

func (r *PostgresRepository) UpdateMentionsSettings(ctx context.Context, userID, whoCanMention string) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE user_settings
		SET mentions_who_can_mention = $2,
			updated_at = NOW()
		WHERE user_id = $1
	`, userID, whoCanMention)
	return err
}

func (r *PostgresRepository) ListMessageKeywords(ctx context.Context, userID string) ([]KeywordItem, error) {
	items := make([]KeywordItem, 0)
	err := r.db.SelectContext(ctx, &items, `
		SELECT id, keyword, created_at AS added_at
		FROM message_keyword_filters
		WHERE user_id = $1
		ORDER BY created_at DESC
	`, userID)
	if err != nil {
		if isUndefinedTable(err) {
			return items, nil
		}
		return nil, err
	}
	return items, nil
}

func (r *PostgresRepository) AddMessageKeyword(ctx context.Context, userID, keyword string) (string, error) {
	id := uuid.NewString()
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO message_keyword_filters(id, user_id, keyword)
		VALUES ($1, $2, $3)
		ON CONFLICT (user_id, keyword) DO NOTHING
	`, id, userID, keyword)
	if err != nil {
		return "", err
	}
	return id, nil
}

func (r *PostgresRepository) DeleteMessageKeyword(ctx context.Context, userID, keywordID string) error {
	_, err := r.db.ExecContext(ctx, `
		DELETE FROM message_keyword_filters
		WHERE id = $1 AND user_id = $2
	`, keywordID, userID)
	return err
}

func (r *PostgresRepository) CountActiveSessions(ctx context.Context, userID string) (int, error) {
	var count int
	err := r.db.GetContext(ctx, &count, `
		SELECT COUNT(1)
		FROM sessions
		WHERE user_id = $1 AND revoked_at IS NULL
	`, userID)
	return count, err
}

func normalizeOS(userAgent string) string {
	s := strings.ToLower(userAgent)
	switch {
	case strings.Contains(s, "android"):
		return "android"
	case strings.Contains(s, "ios"), strings.Contains(s, "iphone"), strings.Contains(s, "ipad"):
		return "ios"
	case strings.Contains(s, "windows"):
		return "windows"
	case strings.Contains(s, "mac"):
		return "macos"
	case strings.Contains(s, "linux"):
		return "linux"
	default:
		return "unknown"
	}
}

func (r *PostgresRepository) ListSessions(ctx context.Context, userID string) ([]SessionItem, error) {
	type sessionRow struct {
		ID           string    `db:"id"`
		DeviceID     string    `db:"device_id"`
		UserAgent    string    `db:"user_agent"`
		IP           string    `db:"ip"`
		LastActiveAt time.Time `db:"last_active_at"`
	}
	rows := make([]sessionRow, 0)
	err := r.db.SelectContext(ctx, &rows, `
		SELECT id, device_id, user_agent, ip, last_active_at
		FROM sessions
		WHERE user_id = $1 AND revoked_at IS NULL
		ORDER BY last_active_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	items := make([]SessionItem, 0, len(rows))
	for _, row := range rows {
		deviceName := row.DeviceID
		if deviceName == "" {
			deviceName = "Unknown device"
		}
		items = append(items, SessionItem{
			ID:           row.ID,
			DeviceName:   deviceName,
			OS:           normalizeOS(row.UserAgent),
			IP:           row.IP,
			LastActiveAt: row.LastActiveAt,
		})
	}
	return items, nil
}

func (r *PostgresRepository) RevokeSession(ctx context.Context, userID, sessionID string, revokedAt time.Time) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE sessions
		SET revoked_at = $3
		WHERE user_id = $1 AND id = $2 AND revoked_at IS NULL
	`, userID, sessionID, revokedAt)
	return err
}

func (r *PostgresRepository) RevokeAllSessionsExcept(ctx context.Context, userID, currentSessionID string, revokedAt time.Time) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE sessions
		SET revoked_at = $3
		WHERE user_id = $1 AND id <> $2 AND revoked_at IS NULL
	`, userID, currentSessionID, revokedAt)
	return err
}

func (r *PostgresRepository) RevokeAllSessions(ctx context.Context, userID string, revokedAt time.Time) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE sessions
		SET revoked_at = $2
		WHERE user_id = $1 AND revoked_at IS NULL
	`, userID, revokedAt)
	return err
}

func (r *PostgresRepository) GetUserPasswordHash(ctx context.Context, userID string) (string, error) {
	var hash string
	err := r.db.GetContext(ctx, &hash, `SELECT password_hash FROM users WHERE id = $1`, userID)
	return hash, err
}

func (r *PostgresRepository) UpdateUserPasswordHash(ctx context.Context, userID, passwordHash string, updatedAt time.Time) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE users
		SET password_hash = $2,
			updated_at = $3
		WHERE id = $1
	`, userID, passwordHash, updatedAt)
	return err
}

func (r *PostgresRepository) GetActiveTwoFAMethods(ctx context.Context, userID string) ([]TwoFAMethod, error) {
	items := make([]TwoFAMethod, 0)
	err := r.db.SelectContext(ctx, &items, `
		SELECT method, is_active, secret_encrypted
		FROM two_factor_methods
		WHERE user_id = $1 AND is_active = true
		ORDER BY method ASC
	`, userID)
	return items, err
}

func (r *PostgresRepository) UpsertTwoFAMethod(ctx context.Context, userID, method string, isActive bool, secret *string) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO two_factor_methods (user_id, method, is_active, secret_encrypted)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (user_id, method)
		DO UPDATE SET
			is_active = EXCLUDED.is_active,
			secret_encrypted = COALESCE(EXCLUDED.secret_encrypted, two_factor_methods.secret_encrypted),
			updated_at = NOW()
	`, userID, method, isActive, secret)
	return err
}

func (r *PostgresRepository) DeactivateAllTwoFAMethods(ctx context.Context, userID string) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE two_factor_methods
		SET is_active = false,
			updated_at = NOW()
		WHERE user_id = $1
	`, userID)
	return err
}

func (r *PostgresRepository) GetUserPhone(ctx context.Context, userID string) (string, string, error) {
	var countryCode string
	var phoneNumber string
	err := r.db.QueryRowxContext(ctx, `
		SELECT COALESCE(phone_country_code, ''), COALESCE(phone_number, '')
		FROM users
		WHERE id = $1
	`, userID).Scan(&countryCode, &phoneNumber)
	if err != nil {
		return "", "", err
	}
	return countryCode, phoneNumber, nil
}

func (r *PostgresRepository) CreateDeleteRequest(ctx context.Context, userID, reason, verificationMethod string) (string, error) {
	id := uuid.NewString()
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO delete_account_requests (id, user_id, reason, verification_method)
		VALUES ($1, $2, $3, $4)
	`, id, userID, reason, verificationMethod)
	if err != nil {
		return "", err
	}
	return id, nil
}

func (r *PostgresRepository) GetLatestDeleteRequest(ctx context.Context, userID string) (*deleteAccountRequest, error) {
	var req deleteAccountRequest
	err := r.db.GetContext(ctx, &req, `
		SELECT id, user_id, reason, verification_method, otp_code_hash, verification_token, verification_expires_at, verified_at, created_at
		FROM delete_account_requests
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT 1
	`, userID)
	if err != nil {
		return nil, err
	}
	return &req, nil
}

func (r *PostgresRepository) SetDeleteOTPCodeHash(ctx context.Context, requestID, otpCodeHash string) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE delete_account_requests
		SET otp_code_hash = $2,
			updated_at = NOW()
		WHERE id = $1
	`, requestID, otpCodeHash)
	return err
}

func (r *PostgresRepository) SetDeleteVerification(ctx context.Context, requestID, token string, expiresAt time.Time) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE delete_account_requests
		SET verification_token = $2,
			verification_expires_at = $3,
			updated_at = NOW()
		WHERE id = $1
	`, requestID, token, expiresAt)
	return err
}

func (r *PostgresRepository) MarkDeleteRequestVerified(ctx context.Context, requestID string, verifiedAt time.Time) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE delete_account_requests
		SET verified_at = $2,
			updated_at = NOW()
		WHERE id = $1
	`, requestID, verifiedAt)
	return err
}

func (r *PostgresRepository) SoftDeleteUser(ctx context.Context, userID string, deletedAt, hardDeleteAt time.Time) error {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() {
		_ = tx.Rollback()
	}()

	// 1. Get current credentials to rename them
	var user struct {
		Email        *string `db:"email"`
		Username     string  `db:"username"`
		PhoneNumber  *string `db:"phone_number"`
	}
	if err := tx.GetContext(ctx, &user, `SELECT email, username, phone_number FROM users WHERE id = $1`, userID); err != nil {
		return err
	}

	suffix := fmt.Sprintf("_del_%d", deletedAt.Unix())

	// 2. Update users table with renamed credentials
	query := `
		UPDATE users
		SET deleted_at = $2,
			hard_delete_scheduled_at = $3,
			is_shadow_banned = true,
			updated_at = NOW(),
			username = username || $4,
			email = CASE WHEN email IS NOT NULL THEN email || $4 ELSE NULL END,
			phone_number = CASE WHEN phone_number IS NOT NULL THEN phone_number || $4 ELSE NULL END
		WHERE id = $1
	`
	if _, err = tx.ExecContext(ctx, query, userID, deletedAt, hardDeleteAt, suffix); err != nil {
		return err
	}

	// 3. Update user_identities to free up subjects
	if _, err = tx.ExecContext(ctx, `
		UPDATE user_identities
		SET subject = subject || $2,
			email = CASE WHEN email IS NOT NULL AND email != '' THEN email || $2 ELSE email END
		WHERE user_id = $1
	`, userID, suffix); err != nil {
		return err
	}

	if _, err = tx.ExecContext(ctx, `
		UPDATE user_settings
		SET participate_district_ranking = false,
			updated_at = NOW()
		WHERE user_id = $1
	`, userID); err != nil {
		return err
	}

	if _, err = tx.ExecContext(ctx, `UPDATE users SET participate_district = false WHERE id = $1`, userID); err != nil {
		return err
	}

	if _, err = tx.ExecContext(ctx, `DELETE FROM comment_interactions WHERE user_id = $1`, userID); err != nil {
		return err
	}
	if _, err = tx.ExecContext(ctx, `DELETE FROM post_comments WHERE user_id = $1`, userID); err != nil {
		return err
	}
	if _, err = tx.ExecContext(ctx, `DELETE FROM post_interactions WHERE user_id = $1`, userID); err != nil {
		return err
	}
	if _, err = tx.ExecContext(ctx, `DELETE FROM post_media WHERE post_id IN (SELECT id FROM posts WHERE user_id = $1)`, userID); err != nil {
		return err
	}
	if _, err = tx.ExecContext(ctx, `DELETE FROM posts WHERE user_id = $1`, userID); err != nil {
		return err
	}
	if _, err = tx.ExecContext(ctx, `DELETE FROM user_relationships WHERE user_id = $1 OR target_user_id = $1`, userID); err != nil {
		return err
	}

	if err = tx.Commit(); err != nil {
		return err
	}
	return nil
}

func (r *PostgresRepository) CreateBugReport(ctx context.Context, userID string, req *BugReportRequest) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO bug_reports (user_id, description, screenshot_url, app_version, device_os, status)
		VALUES ($1, $2, $3, $4, $5, 'new')
	`, userID, req.Description, req.Screenshot, req.AppVersion, req.DeviceOS)
	return err
}

func hashDeleteOTP(code string) string {
	sum := sha256.Sum256([]byte(code))
	return hex.EncodeToString(sum[:])
}

func isUndefinedTable(err error) bool {
	var pqErr *pq.Error
	if errors.As(err, &pqErr) {
		return string(pqErr.Code) == "42P01"
	}
	return false
}

func isUndefinedColumn(err error, column string) bool {
	var pqErr *pq.Error
	if errors.As(err, &pqErr) {
		return string(pqErr.Code) == "42703" && strings.Contains(strings.ToLower(pqErr.Message), strings.ToLower(column))
	}
	return false
}

func (r *PostgresRepository) ListBlockedUsers(ctx context.Context, userID string, cursor *time.Time, limit int) ([]BlockedUserItem, error) {
	items := make([]BlockedUserItem, 0)
	query := `
		SELECT
			u.id AS user_id,
			u.username,
			COALESCE(p.avatar_url, '') AS avatar_url,
			u.last_active_at
		FROM user_relationships ur
		JOIN users u ON u.id = ur.target_user_id
		LEFT JOIN profiles p ON p.user_id = u.id
		WHERE ur.user_id = $1
		  AND ur.relationship_type = 'block'
	`
	args := []any{userID}
	if cursor != nil {
		query += ` AND u.last_active_at < $2`
		args = append(args, *cursor)
	}
	query += ` ORDER BY u.last_active_at DESC LIMIT $` + strconv.Itoa(len(args)+1)
	args = append(args, limit)

	if err := r.db.SelectContext(ctx, &items, query, args...); err != nil {
		return nil, err
	}
	return items, nil
}

func (r *PostgresRepository) UnblockUser(ctx context.Context, userID, targetUserID string) error {
	_, err := r.db.ExecContext(ctx, `
		DELETE FROM user_relationships
		WHERE user_id = $1 AND target_user_id = $2 AND relationship_type = 'block'
	`, userID, targetUserID)
	return err
}

func (r *PostgresRepository) IsBlockedBetween(ctx context.Context, actorID, targetID string) (bool, error) {
	var exists bool
	err := r.db.GetContext(ctx, &exists, `
		SELECT EXISTS (
			SELECT 1
			FROM user_relationships
			WHERE relationship_type = 'block'
			  AND ((user_id = $1 AND target_user_id = $2) OR (user_id = $2 AND target_user_id = $1))
		)
	`, actorID, targetID)
	return exists, err
}

func (r *PostgresRepository) CreateAuditLog(ctx context.Context, userID, action string, details map[string]any) error {
	var payload []byte
	if details != nil {
		b, err := json.Marshal(details)
		if err != nil {
			return err
		}
		payload = b
	}
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO settings_audit_logs (user_id, action, details)
		VALUES ($1, $2, $3)
	`, userID, action, payload)
	return err
}

func (r *PostgresRepository) GetFeedTimeLimit(ctx context.Context, userID string) (int, error) {
	var mins int
	err := r.db.GetContext(ctx, &mins, `
		SELECT COALESCE(us.feed_time_limit_current_mins, u.feed_time_limit_mins, 20)
		FROM users u
		LEFT JOIN user_settings us ON us.user_id = u.id
		WHERE u.id = $1
	`, userID)
	return mins, err
}

func (r *PostgresRepository) GetCommentPrivacy(ctx context.Context, userID string) (string, bool, error) {
	var who string
	var filter bool
	err := r.db.QueryRowxContext(ctx, `
		SELECT comments_who_can_comment, comments_filter_unwanted_enabled
		FROM user_settings WHERE user_id = $1
	`, userID).Scan(&who, &filter)
	if err == sql.ErrNoRows {
		return MessagePrivacyEveryone, false, nil
	}
	return who, filter, err
}

func (r *PostgresRepository) GetMessagePrivacy(ctx context.Context, userID string) (string, bool, bool, error) {
	var who string
	var read bool
	var safe bool
	err := r.db.QueryRowxContext(ctx, `
		SELECT messages_who_can_message, messages_read_status_enabled, messages_safe_mode_enabled
		FROM user_settings WHERE user_id = $1
	`, userID).Scan(&who, &read, &safe)
	if err == sql.ErrNoRows {
		return MessagePrivacyEveryone, true, false, nil
	}
	return who, read, safe, err
}

func (r *PostgresRepository) GetMentionsPrivacy(ctx context.Context, userID string) (string, error) {
	var who string
	err := r.db.GetContext(ctx, &who, `
		SELECT mentions_who_can_mention
		FROM user_settings WHERE user_id = $1
	`, userID)
	if err == sql.ErrNoRows {
		return MessagePrivacyEveryone, nil
	}
	return who, err
}
