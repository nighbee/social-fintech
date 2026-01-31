package economy

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

// ViolationLogger writes violations into economy_violations table.
type ViolationLogger struct {
	db *sqlx.DB
}

// NewViolationLogger binds logger to DB.
func NewViolationLogger(db *sqlx.DB) *ViolationLogger {
	return &ViolationLogger{db: db}
}

// Log inserts a violation with endpoint.
func (v *ViolationLogger) Log(ctx context.Context, userID, violationType, endpoint string) error {
	query := `
		INSERT INTO economy_violations (id, user_id, violation_type, endpoint, created_at)
		VALUES ($1, $2, $3, $4, $5)
	`
	_, err := v.db.ExecContext(ctx, query, uuid.NewString(), userID, violationType, endpoint, time.Now())
	return err
}
