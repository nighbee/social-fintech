package auth

import (
	"context"
	"database/sql"
	"strings"
	"time"

	"github.com/jmoiron/sqlx"
)

// первый слой интерфейса
type Repository interface {
	GetUserByIdentity(ctx context.Context, provider, subject string) (*User, error)
	GetUserByID(ctx context.Context, id string) (*User, error)
	GetUserByEmail(ctx context.Context, email string) (*User, error)
	GetUserByPhone(ctx context.Context, countryCode, phoneNumber string) (*User, error)
	UsernameExists(ctx context.Context, username string) (bool, error)
	CreateUser(ctx context.Context, user *User) error
	CreateIdentity(ctx context.Context, identity *Identity) error

	CreateSession(ctx context.Context, session *Session) error
	GetSessionByID(ctx context.Context, id string) (*Session, error)
	GetLastSessionByUser(ctx context.Context, userID string) (*Session, error)
	UpdateSessionsRefreshToken(ctx context.Context, id, refreshHash string, lastActive time.Time) error
	TouchSession(ctx context.Context, id string, lastActive time.Time) error
	TouchUser(ctx context.Context, id string, lastActive time.Time) error
	RevokeSession(ctx context.Context, id string, revokedAt time.Time) error
	DeleteSession(ctx context.Context, id string) error
	CountActiveSessionsByUser(ctx context.Context, userID string) (int, error)
	ListActiveSessionsByUser(ctx context.Context, userID string) ([]Session, error)
	RevokeSessionForUser(ctx context.Context, userID, sessionID string, revokedAt time.Time) error
	RevokeAllSessionsExceptForUser(ctx context.Context, userID, currentSessionID string, revokedAt time.Time) error
	RevokeAllSessionsForUser(ctx context.Context, userID string, revokedAt time.Time) error
	GetUserPasswordHashByID(ctx context.Context, userID string) (string, error)
	UpdateUserPasswordHashByID(ctx context.Context, userID, passwordHash string, updatedAt time.Time) error
	GetUserPhoneByID(ctx context.Context, userID string) (string, string, error)
	RecordRegistrationSignal(ctx context.Context, deviceID, ip string, now time.Time) (int, int, error)
	RecordActivationLogin(ctx context.Context, userID string, now time.Time) (string, bool, error)

	CreatePhoneVerification(ctx context.Context, v *PhoneVerification) error
	GetPhoneVerificationByID(ctx context.Context, id string) (*PhoneVerification, error)
	ConsumePhoneVerification(ctx context.Context, id string, consumedAt time.Time) error
	UsePhoneVerification(ctx context.Context, id string, usedAt time.Time) error
	SetAdminStatus(ctx context.Context, userID string, isAdmin bool) error
}

// структурирование бд в первый слой репозитория
type PostgresRepository struct {
	db *sqlx.DB
}

// конструктор для нового репо
func NewRepository(db *sqlx.DB) *PostgresRepository {
	return &PostgresRepository{db: db}
}

// найти провайдера + и subject с бд
func (r *PostgresRepository) GetUserByIdentity(ctx context.Context, provider, subject string) (*User, error) {
	var user User
	query := `
	SELECT u.*
	FROM users u
	JOIN user_identities ui ON ui.user_id = u.id
	WHERE ui.provider = $1 AND ui.subject = $2 AND u.deleted_at IS NULL
	`
	if err := r.db.GetContext(ctx, &user, query, provider, subject); err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *PostgresRepository) GetUserByID(ctx context.Context, id string) (*User, error) {
	var user User
	query := `SELECT * FROM users WHERE id = $1`
	if err := r.db.GetContext(ctx, &user, query, id); err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *PostgresRepository) GetUserByEmail(ctx context.Context, email string) (*User, error) {
	var user User
	query := `SELECT * FROM users WHERE email = $1 AND deleted_at IS NULL`
	if err := r.db.GetContext(ctx, &user, query, email); err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *PostgresRepository) GetUserByPhone(ctx context.Context, countryCode, phoneNumber string) (*User, error) {
	var user User
	query := `SELECT * FROM users WHERE phone_country_code = $1 AND phone_number = $2 AND deleted_at IS NULL`
	if err := r.db.GetContext(ctx, &user, query, countryCode, phoneNumber); err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *PostgresRepository) UsernameExists(ctx context.Context, username string) (bool, error) {
	var exists bool
	query := `SELECT EXISTS(SELECT 1 FROM users WHERE username = $1)`
	if err := r.db.GetContext(ctx, &exists, query, username); err != nil {
		return false, err
	}
	return exists, nil
}

func (r *PostgresRepository) CreateUser(ctx context.Context, user *User) error {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	query := `
	  INSERT INTO users (
			id, email, username, password_hash, first_name, last_name, date_of_birth, referral_code,
			phone_country_code, phone_number,
			avatar_url, is_shadow_banned, activation_status, restrictions_until, created_at, updated_at, last_active_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NULLIF($9, ''), NULLIF($10, ''), $11, $12, COALESCE(NULLIF($13, ''), 'restricted'), $14, $15, $16, $17)
	`
	// Convert empty strings to NULL for phone fields to avoid unique constraint violations
	var phoneCountry, phoneNumber interface{}
	if user.PhoneCountry == nil && user.PhoneNumber == nil {
		phoneCountry = nil
		phoneNumber = nil
	} else {
		if user.PhoneCountry != nil {
			phoneCountry = *user.PhoneCountry
		} else {
			phoneCountry = nil
		}
		if user.PhoneNumber != nil {
			phoneNumber = *user.PhoneNumber
		} else {
			phoneNumber = nil
		}
	}

	_, err = tx.ExecContext(ctx, query,
		user.ID, user.Email, user.Username, user.PasswordHash, user.FirstName, user.LastName,
		user.DateOfBirth, user.ReferralCode, phoneCountry, phoneNumber,
		user.AvatarURL, user.IsShadowBanned, user.ActivationStatus, user.RestrictionsUntil, user.CreatedAt, user.UpdatedAt, user.LastActiveAt,
	)
	if err != nil {
		return err
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO profiles (user_id, display_name, avatar_url, is_profile_public, created_at, updated_at)
		VALUES ($1, NULLIF($2, ''), $3, true, $4, $5)
		ON CONFLICT (user_id) DO NOTHING
	`, user.ID, strings.TrimSpace(user.FirstName+" "+user.LastName), user.AvatarURL, user.CreatedAt, user.UpdatedAt)
	if err != nil {
		return err
	}

	return tx.Commit()
}

func (r *PostgresRepository) CreateIdentity(ctx context.Context, identity *Identity) error {
	query := `
		INSERT INTO user_identities (user_id, provider, subject, email, created_at)
		VALUES ($1, $2, $3, $4, $5)
	`
	_, err := r.db.ExecContext(ctx, query,
		identity.UserID, identity.Provider, identity.Subject, identity.Email, identity.CreatedAt,
	)
	return err
}

func (r *PostgresRepository) CreateSession(ctx context.Context, session *Session) error {
	query := `
		INSERT INTO sessions (id, user_id, device_id, ip, user_agent, app_version, last_active_at, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`
	_, err := r.db.ExecContext(ctx, query,
		session.ID, session.UserID, session.DeviceID, session.IP,
		session.UserAgent, session.AppVersion, session.LastActiveAt, session.CreatedAt,
	)
	return err
}

func (r *PostgresRepository) GetSessionByID(ctx context.Context, id string) (*Session, error) {
	var session Session
	query := `SELECT * FROM sessions WHERE id = $1`
	if err := r.db.GetContext(ctx, &session, query, id); err != nil {
		return nil, err
	}
	return &session, nil
}

func (r *PostgresRepository) GetLastSessionByUser(ctx context.Context, userID string) (*Session, error) {
	var session Session
	query := `SELECT * FROM sessions WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1`
	if err := r.db.GetContext(ctx, &session, query, userID); err != nil {
		return nil, err
	}
	return &session, nil
}

func (r *PostgresRepository) DeleteSession(ctx context.Context, id string) error {
	query := `DELETE FROM sessions WHERE id = $1`
	_, err := r.db.ExecContext(ctx, query, id)
	return err
}

func IsNotFound(err error) bool {
	return err == sql.ErrNoRows
}

func (r *PostgresRepository) UpdateSessionsRefreshToken(ctx context.Context, id, refreshHash string, lastActive time.Time) error {
	query := `
		UPDATE sessions
		SET refresh_token_hash = $1, last_active_at = $2
		WHERE id = $3
	`
	_, err := r.db.ExecContext(ctx, query, refreshHash, lastActive, id)
	return err
}

func (r *PostgresRepository) TouchSession(ctx context.Context, id string, lastActive time.Time) error {
	query := `UPDATE sessions SET last_active_at = $1 WHERE id = $2`
	_, err := r.db.ExecContext(ctx, query, lastActive, id)
	return err
}

func (r *PostgresRepository) TouchUser(ctx context.Context, id string, lastActive time.Time) error {
	query := `UPDATE users SET last_active_at = $1 WHERE id = $2`
	_, err := r.db.ExecContext(ctx, query, lastActive, id)
	return err
}

func (r *PostgresRepository) RevokeSession(ctx context.Context, id string, revokedAt time.Time) error {
	query := `UPDATE sessions SET revoked_at = $1 WHERE id = $2`
	_, err := r.db.ExecContext(ctx, query, revokedAt, id)
	return err
}

func (r *PostgresRepository) CountActiveSessionsByUser(ctx context.Context, userID string) (int, error) {
	var count int
	query := `SELECT COUNT(1) FROM sessions WHERE user_id = $1 AND revoked_at IS NULL`
	if err := r.db.GetContext(ctx, &count, query, userID); err != nil {
		return 0, err
	}
	return count, nil
}

func (r *PostgresRepository) ListActiveSessionsByUser(ctx context.Context, userID string) ([]Session, error) {
	items := make([]Session, 0)
	query := `
		SELECT id, user_id, device_id, ip, user_agent, app_version, last_active_at, created_at, refresh_token_hash, revoked_at
		FROM sessions
		WHERE user_id = $1 AND revoked_at IS NULL
		ORDER BY last_active_at DESC
	`
	if err := r.db.SelectContext(ctx, &items, query, userID); err != nil {
		return nil, err
	}
	return items, nil
}

func (r *PostgresRepository) RevokeSessionForUser(ctx context.Context, userID, sessionID string, revokedAt time.Time) error {
	query := `UPDATE sessions SET revoked_at = $3 WHERE user_id = $1 AND id = $2 AND revoked_at IS NULL`
	_, err := r.db.ExecContext(ctx, query, userID, sessionID, revokedAt)
	return err
}

func (r *PostgresRepository) RevokeAllSessionsExceptForUser(ctx context.Context, userID, currentSessionID string, revokedAt time.Time) error {
	query := `UPDATE sessions SET revoked_at = $3 WHERE user_id = $1 AND id <> $2 AND revoked_at IS NULL`
	_, err := r.db.ExecContext(ctx, query, userID, currentSessionID, revokedAt)
	return err
}

func (r *PostgresRepository) RevokeAllSessionsForUser(ctx context.Context, userID string, revokedAt time.Time) error {
	query := `UPDATE sessions SET revoked_at = $2 WHERE user_id = $1 AND revoked_at IS NULL`
	_, err := r.db.ExecContext(ctx, query, userID, revokedAt)
	return err
}

func (r *PostgresRepository) GetUserPasswordHashByID(ctx context.Context, userID string) (string, error) {
	var hash string
	query := `SELECT password_hash FROM users WHERE id = $1`
	if err := r.db.GetContext(ctx, &hash, query, userID); err != nil {
		return "", err
	}
	return hash, nil
}

func (r *PostgresRepository) UpdateUserPasswordHashByID(ctx context.Context, userID, passwordHash string, updatedAt time.Time) error {
	query := `UPDATE users SET password_hash = $2, updated_at = $3 WHERE id = $1`
	_, err := r.db.ExecContext(ctx, query, userID, passwordHash, updatedAt)
	return err
}

func (r *PostgresRepository) GetUserPhoneByID(ctx context.Context, userID string) (string, string, error) {
	var countryCode string
	var phoneNumber string
	query := `SELECT COALESCE(phone_country_code, ''), COALESCE(phone_number, '') FROM users WHERE id = $1`
	if err := r.db.QueryRowContext(ctx, query, userID).Scan(&countryCode, &phoneNumber); err != nil {
		return "", "", err
	}
	return countryCode, phoneNumber, nil
}

func (r *PostgresRepository) RecordRegistrationSignal(ctx context.Context, deviceID, ip string, now time.Time) (int, int, error) {
	statDate := now.UTC().Format("2006-01-02")

	deviceCount := 0
	if strings.TrimSpace(deviceID) != "" {
		if err := r.db.QueryRowContext(ctx, `
			INSERT INTO device_registration_stats (device_id, stat_date, registrations_count)
			VALUES ($1, $2, 1)
			ON CONFLICT (device_id, stat_date)
			DO UPDATE SET registrations_count = device_registration_stats.registrations_count + 1
			RETURNING registrations_count
		`, deviceID, statDate).Scan(&deviceCount); err != nil {
			return 0, 0, err
		}
	}

	ipCount := 0
	if strings.TrimSpace(ip) != "" {
		if err := r.db.QueryRowContext(ctx, `
			INSERT INTO ip_registration_stats (ip_address, stat_date, registrations_count)
			VALUES ($1, $2, 1)
			ON CONFLICT (ip_address, stat_date)
			DO UPDATE SET registrations_count = ip_registration_stats.registrations_count + 1
			RETURNING registrations_count
		`, ip, statDate).Scan(&ipCount); err != nil {
			return 0, 0, err
		}
	}

	return deviceCount, ipCount, nil
}

func (r *PostgresRepository) RecordActivationLogin(ctx context.Context, userID string, now time.Time) (string, bool, error) {
	loginDate := now.UTC().Format("2006-01-02")

	if _, err := r.db.ExecContext(ctx, `
		INSERT INTO user_activation_activity (user_id, distinct_login_days, login_events_count, meaningful_actions_count, last_login_date, updated_at)
		VALUES ($1, 1, 1, 0, $2, NOW())
		ON CONFLICT (user_id) DO UPDATE
		SET login_events_count = user_activation_activity.login_events_count + 1,
		    distinct_login_days = CASE
		        WHEN user_activation_activity.last_login_date IS DISTINCT FROM $2::date THEN user_activation_activity.distinct_login_days + 1
		        ELSE user_activation_activity.distinct_login_days
		    END,
		    last_login_date = $2,
		    updated_at = NOW()
	`, userID, loginDate); err != nil {
		return "", false, err
	}

	var status string
	var restrictionsUntil sql.NullTime
	var createdAt time.Time
	var phoneNumber sql.NullString
	var email string
	if err := r.db.QueryRowContext(ctx, `
		SELECT activation_status, restrictions_until, created_at, phone_number, email
		FROM users
		WHERE id = $1
	`, userID).Scan(&status, &restrictionsUntil, &createdAt, &phoneNumber, &email); err != nil {
		return "", false, err
	}

	if status == "active" {
		return status, false, nil
	}
	if restrictionsUntil.Valid && restrictionsUntil.Time.After(now) {
		return status, false, nil
	}

	var distinctDays int
	var loginEvents int
	var meaningfulActions int
	if err := r.db.QueryRowContext(ctx, `
		SELECT distinct_login_days, login_events_count, meaningful_actions_count
		FROM user_activation_activity
		WHERE user_id = $1
	`, userID).Scan(&distinctDays, &loginEvents, &meaningfulActions); err != nil {
		return "", false, err
	}

	ageHours := now.Sub(createdAt).Hours()

	requiredDays := 3
	requiredLogins := 3
	requiredMeaningful := 5
	requiredAgeHours := 24.0
	if status == "suspicious" {
		requiredDays = 5
		requiredLogins = 5
		requiredMeaningful = 8
		requiredAgeHours = 120.0
	}

	if distinctDays >= requiredDays &&
		loginEvents >= requiredLogins &&
		ageHours >= requiredAgeHours &&
		phoneNumber.Valid && phoneNumber.String != "" &&
		email != "" &&
		meaningfulActions >= requiredMeaningful {
		if _, err := r.db.ExecContext(ctx, `
			UPDATE users
			SET activation_status = 'active',
			    activation_unlocked_at = COALESCE(activation_unlocked_at, NOW()),
			    restrictions_until = NULL,
			    updated_at = NOW()
			WHERE id = $1
		`, userID); err != nil {
			return "", false, err
		}
		return "active", true, nil
	}

	return status, false, nil
}

func (r *PostgresRepository) CreatePhoneVerification(ctx context.Context, v *PhoneVerification) error {
	query := `
		INSERT INTO phone_verifications (
			id, phone_country_code, phone_number, purpose, code_hash, expires_at, created_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	_, err := r.db.ExecContext(ctx, query,
		v.ID, v.PhoneCountry, v.PhoneNumber, v.Purpose, v.CodeHash, v.ExpiresAt, v.CreatedAt,
	)
	return err
}

func (r *PostgresRepository) GetPhoneVerificationByID(ctx context.Context, id string) (*PhoneVerification, error) {
	var v PhoneVerification
	query := `SELECT * FROM phone_verifications WHERE id = $1`
	if err := r.db.GetContext(ctx, &v, query, id); err != nil {
		return nil, err
	}
	return &v, nil
}

// для подтверждения принятия кода
func (r *PostgresRepository) ConsumePhoneVerification(ctx context.Context, id string, consumedAt time.Time) error {
	query := `UPDATE phone_verifications SET consumed_at = $1 WHERE id = $2`
	_, err := r.db.ExecContext(ctx, query, consumedAt, id)
	return err
}

func (r *PostgresRepository) UsePhoneVerification(ctx context.Context, id string, usedAt time.Time) error {
	query := `UPDATE phone_verifications SET used_at = $1 WHERE id = $2`
	_, err := r.db.ExecContext(ctx, query, usedAt, id)
	return err
}

func (r *PostgresRepository) SetAdminStatus(ctx context.Context, userID string, isAdmin bool) error {
	query := `UPDATE users SET is_admin = $1 WHERE id = $2`
	_, err := r.db.ExecContext(ctx, query, isAdmin, userID)
	return err
}
