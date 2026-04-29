package notifications

import (
	"context"
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

type Repository interface {
	Insert(ctx context.Context, n *Notification) error
	List(ctx context.Context, userID uuid.UUID, cursor *time.Time, limit int) ([]Notification, *time.Time, error)
	UnreadCount(ctx context.Context, userID uuid.UUID) (int, error)
	MarkRead(ctx context.Context, userID, notificationID uuid.UUID, readAt time.Time) error
	MarkAllRead(ctx context.Context, userID uuid.UUID, readAt time.Time) error
}

type PostgresRepository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *PostgresRepository {
	return &PostgresRepository{db: db}
}

func (r *PostgresRepository) Insert(ctx context.Context, n *Notification) error {
	if n.ID == uuid.Nil {
		n.ID = uuid.New()
	}
	if n.CreatedAt.IsZero() {
		n.CreatedAt = time.Now().UTC()
	}
	payload := []byte(n.Payload)
	if len(payload) == 0 {
		payload = []byte("{}")
	}
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO notifications (id, user_id, kind, title, body, payload, created_at)
		VALUES ($1, $2, $3, $4, NULLIF($5, ''), $6::jsonb, $7)
	`,
		n.ID, n.UserID, string(n.Kind), n.Title, n.Body, string(payload), n.CreatedAt,
	)
	return err
}

func (r *PostgresRepository) List(ctx context.Context, userID uuid.UUID, cursor *time.Time, limit int) ([]Notification, *time.Time, error) {
	if limit <= 0 || limit > 100 {
		limit = 30
	}

	const cursoredQuery = `
		SELECT id, user_id, kind, title, COALESCE(body, '') AS body, payload, read_at, created_at
		FROM notifications
		WHERE user_id = $1 AND created_at < $2
		ORDER BY created_at DESC
		LIMIT $3
	`
	const firstPageQuery = `
		SELECT id, user_id, kind, title, COALESCE(body, '') AS body, payload, read_at, created_at
		FROM notifications
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT $2
	`

	var rows []struct {
		ID        uuid.UUID       `db:"id"`
		UserID    uuid.UUID       `db:"user_id"`
		Kind      string          `db:"kind"`
		Title     string          `db:"title"`
		Body      string          `db:"body"`
		Payload   json.RawMessage `db:"payload"`
		ReadAt    *time.Time      `db:"read_at"`
		CreatedAt time.Time       `db:"created_at"`
	}

	var err error
	if cursor != nil {
		err = r.db.SelectContext(ctx, &rows, cursoredQuery, userID, *cursor, limit+1)
	} else {
		err = r.db.SelectContext(ctx, &rows, firstPageQuery, userID, limit+1)
	}
	if err != nil {
		return nil, nil, err
	}

	var nextCursor *time.Time
	if len(rows) > limit {
		boundary := rows[limit-1].CreatedAt
		nextCursor = &boundary
		rows = rows[:limit]
	}

	out := make([]Notification, 0, len(rows))
	for _, row := range rows {
		out = append(out, Notification{
			ID:        row.ID,
			UserID:    row.UserID,
			Kind:      Kind(row.Kind),
			Title:     row.Title,
			Body:      row.Body,
			Payload:   row.Payload,
			ReadAt:    row.ReadAt,
			CreatedAt: row.CreatedAt,
		})
	}
	return out, nextCursor, nil
}

func (r *PostgresRepository) UnreadCount(ctx context.Context, userID uuid.UUID) (int, error) {
	var count int
	err := r.db.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND read_at IS NULL
	`, userID).Scan(&count)
	return count, err
}

func (r *PostgresRepository) MarkRead(ctx context.Context, userID, notificationID uuid.UUID, readAt time.Time) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE notifications
		SET read_at = COALESCE(read_at, $3)
		WHERE id = $1 AND user_id = $2
	`, notificationID, userID, readAt)
	return err
}

func (r *PostgresRepository) MarkAllRead(ctx context.Context, userID uuid.UUID, readAt time.Time) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE notifications
		SET read_at = $2
		WHERE user_id = $1 AND read_at IS NULL
	`, userID, readAt)
	return err
}
