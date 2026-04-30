package payment

import (
	"context"
	"database/sql"

	"github.com/jmoiron/sqlx"
)

type Repository interface {
	CreatePaymentLog(ctx context.Context, log *PaymentLog) error
	GetPaymentLogByEventID(ctx context.Context, eventID string) (*PaymentLog, error)
}

type PaymentLog struct {
	ID        string `db:"id"`
	EventID   string `db:"event_id"`
	UserID    string `db:"user_id"`
	ProductID string `db:"product_id"`
	Amount    int64  `db:"amount"`
	EventType string `db:"event_type"`
	CreatedAt string `db:"created_at"`
}

type repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) Repository {
	return &repository{db: db}
}

func (r *repository) CreatePaymentLog(ctx context.Context, log *PaymentLog) error {
	query := `
		INSERT INTO payment_logs (id, event_id, user_id, product_id, amount, event_type, created_at)
		VALUES (:id, :event_id, :user_id, :product_id, :amount, :event_type, NOW())
	`
	_, err := r.db.NamedExecContext(ctx, query, log)
	return err
}

func (r *repository) GetPaymentLogByEventID(ctx context.Context, eventID string) (*PaymentLog, error) {
	query := `SELECT * FROM payment_logs WHERE event_id = $1`
	var log PaymentLog
	err := r.db.GetContext(ctx, &log, query, eventID)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &log, nil
}

