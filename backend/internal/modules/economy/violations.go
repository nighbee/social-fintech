package economy

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

// структура для вписывания анти абьюза или логов\лимитов в бд
type ViolationLogger struct {
	db *sqlx.DB
}

// логгер для дб
func NewViolationLogger(db *sqlx.DB) *ViolationLogger {
	return &ViolationLogger{db: db}
}

// вызывается когда хитаются лимиты 
func (v *ViolationLogger) Log(ctx context.Context, userID, violationType, endpoint string) error {
	query := `
		INSERT INTO violation_logs (id, user_id, violation_type, endpoint, created_at)
		VALUES ($1, $2, $3, $4, $5)
	`
	_, err := v.db.ExecContext(ctx, query, uuid.NewString(), userID, violationType, endpoint, time.Now())
	return err
}
