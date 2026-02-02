package auth

import (
	"context"
	"database/sql"
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

	CreatePhoneVerification(ctx context.Context, v *PhoneVerification) error
	GetPhoneVerificationByID(ctx context.Context, id string) (*PhoneVerification, error)
	ConsumePhoneVerification(ctx context.Context, id string, consumedAt time.Time) error
	UsePhoneVerification(ctx context.Context, id string, usedAt time.Time) error
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
	WHERE ui.provider = $1 AND ui.subject = $2
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
	query := `SELECT * FROM users WHERE email = $1`
	if err := r.db.GetContext(ctx, &user, query, email); err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *PostgresRepository) GetUserByPhone(ctx context.Context, countryCode, phoneNumber string) (*User, error) {
	var user User
	query := `SELECT * FROM users WHERE phone_country_code = $1 AND phone_number = $2`
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
	query := `
	  INSERT INTO users (
			id, email, username, password_hash, first_name, last_name, date_of_birth, referral_code,
			phone_country_code, phone_number,
			avatar_url, is_shadow_banned, created_at, updated_at, last_active_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NULLIF($9, ''), NULLIF($10, ''), $11, $12, $13, $14, $15)
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

	_, err := r.db.ExecContext(ctx, query,
		user.ID, user.Email, user.Username, user.PasswordHash, user.FirstName, user.LastName,
		user.DateOfBirth, user.ReferralCode, phoneCountry, phoneNumber,
		user.AvatarURL, user.IsShadowBanned, user.CreatedAt, user.UpdatedAt, user.LastActiveAt,
	)
	return err
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
