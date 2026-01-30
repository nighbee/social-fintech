package economy

import (
	"context"
	"time"

	"github.com/jmoiron/sqlx"
)

// для тркеинга связей и трансферов денег
type InteractionTracker struct {
	db *sqlx.DB
}

// трекер баунд для БД
func NewInteractionTracker(db *sqlx.DB) *InteractionTracker {
	return &InteractionTracker{db: db}
}

// сохраняется данные о последнем трансфере + количестве
func (t *InteractionTracker) RecordTransfer(ctx context.Context, senderID, receiverID string, amount int64) error {
	query := `
		INSERT INTO user_interactions (
			sender_id, receiver_id, total_transfers, total_amount, last_amount, last_transfer_at, created_at, updated_at
		) VALUES ($1, $2, 1, $3, $3, $4, $4, $4)
		ON CONFLICT (sender_id, receiver_id)
		DO UPDATE SET
			total_transfers = user_interactions.total_transfers + 1,
			total_amount = user_interactions.total_amount + EXCLUDED.total_amount,
			last_amount = EXCLUDED.last_amount,
			last_transfer_at = EXCLUDED.last_transfer_at,
			updated_at = EXCLUDED.updated_at
	`
	now := time.Now()
	_, err := t.db.ExecContext(ctx, query, senderID, receiverID, amount, now)
	return err
}
