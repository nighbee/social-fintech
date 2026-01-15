package auth

import (
	"context"
	"database/sql"

	"github.com/jmoiron/sqlx"
)

type Repository interface {
	GetUserByIdentity(ctx context.Context, provider, subject string) (*User, error)
	GetUserByEmail(ctx context.Context, email string) (*User, error)
	UsernameExists(ctx context.Context, username string) (bool, error)
	CreateUser(ctx context.Context, user *User) error
	CreateIdentity(ctx context.Context, identity *Identity) error


	CreateSession(ctx context.Context, session *Session) error
	GetSessionByID(ctx context.Context, id string) (*Session, error)
	DeleteSession(ctx context.Context, id string) error
}

type PostgresRepository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *PostgresRepository {
	return &PostgresRepository{db: db}
}

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

func (r *PostgresRepository) GetUserByEmail(ctx context.Context, email string) (*User, error) {
	var user User
	query := `SELECT * FROM users WHERE email = $1`
	if err := r.db.GetContext(ctx, &user, query, email); err != nil {
		return nil, err
	}
	

	return &user, nil
}

func (r *PostgresRepository) UsernameExists(ctx context.Context, username string) (bool, error) {
	var exists bool
	query := `SELECT EXISTS(SELECT 1 FROM users WHERE usename = $1)`
	if err := r.db.GetContext(ctx, &exists, query, username); err != nil {
		return false, nil
	}

	return exists, nil
}

func (r *PostgresRepository) CreateUser(ctx context.Context, user *User) error {
	query := `
	  INSERT INTO users (id, email, username, avatar_url, is_shadow_banned, created_at, updated_at, last_active_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`

	_, err := r.db.ExecContext(ctx, query,
	user.ID, user.Email, user.Username, user.AvatarURL, user.IsShadowBanned,
	user.CreatedAt, user.UpdatedAt, user.LastActiveAt,
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
		INSERT INTO sessions (id, user_id, device_id, ip, last_active_at, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`

	_, err := r.db.ExecContext(ctx, query,
	session.ID, session.UserID, session.DeviceID, session.IP,
	session.LastActiveAt, session.CreatedAt,
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

func (r *PostgresRepository) DeleteSession(ctx context.Context, id string) error {
	query := `DELETE FROM sessions WHERE id = $1`
	_, err := r.db.ExecContext(ctx, query, id)
	return err
}

func IsNotFound(err error) bool {
	return err == sql.ErrNoRows
}