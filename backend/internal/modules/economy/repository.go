package economy

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/jmoiron/sqlx"
)

type Repository interface {
	BeginTx(ctx context.Context) (*sqlx.Tx, error)
	WithTx(tx *sqlx.Tx) Repository
	GetDB() *sqlx.DB

	GetWallet(ctx context.Context, userID string, currency CurrencyCode) (*Wallet, error)
	GetOrCreateWallet(ctx context.Context, userID string, currency CurrencyCode) (*Wallet, error)
	UpdateWallet(ctx context.Context, wallet *Wallet) error
	UpdateWalletWithVersion(ctx context.Context, wallet *Wallet, expectedVersion int64) error

	CreateLedgerEntry(ctx context.Context, entry *LedgerEntry) error
	GetUserTransactionHistory(ctx context.Context, userID string, currency CurrencyCode, category *TransactionCategory, limit, offset int) ([]*LedgerEntry, int, error)
	GetLedgerEntryByReferenceID(ctx context.Context, referenceID string) (*LedgerEntry, error)

	CreateReferral(ctx context.Context, referral *Referral) error
	GetReferralsByReferrer(ctx context.Context, referrerUserID string) ([]*Referral, error)
	GetReferralByReferee(ctx context.Context, refereeUserID string) (*Referral, error)

	GetOrCreateTransferLimit(ctx context.Context, userID, monthYear string) (*TransferLimit, error)
	UpdateTransferLimit(ctx context.Context, limit *TransferLimit, oldTransfersCount int, oldTotalSent int64) error

	CreateViolationLog(ctx context.Context, violation *ViolationLog) error
	GetViolationLogs(ctx context.Context, userID string, limit, offset int) ([]*ViolationLog, int, error)

	GetUserInteraction(ctx context.Context, senderID, receiverID string) (*UserInteraction, error)
	UpsertUserInteraction(ctx context.Context, senderID, receiverID string, amount int64) error

	GetPairCooldown(ctx context.Context, senderID, receiverID string) (*PairCooldown, error)
	UpsertPairCooldown(ctx context.Context, cooldown *PairCooldown) error
}

type repository struct {
	db *sqlx.DB
	tx *sqlx.Tx
}

func NewRepository(db *sqlx.DB) Repository {
	return &repository{db: db}
}

func (r *repository) BeginTx(ctx context.Context) (*sqlx.Tx, error) {
	return r.db.BeginTxx(ctx, &sql.TxOptions{
		Isolation: sql.LevelReadCommitted,
	})
}

func (r *repository) WithTx(tx *sqlx.Tx) Repository {
	return &repository{
		db: r.db,
		tx: tx,
	}
}

func (r *repository) GetDB() *sqlx.DB {
	return r.db
}

func (r *repository) getExecutor() sqlx.ExtContext {
	if r.tx != nil {
		return r.tx
	}
	return r.db
}

func (r *repository) GetWallet(ctx context.Context, userID string, currency CurrencyCode) (*Wallet, error) {
	query := `
		SELECT id, user_id, currency, balance, free_balance, 
		       last_daily_accrual_at, last_transfer_at, version, created_at, updated_at
		FROM wallets
		WHERE user_id = $1 AND currency = $2
	`

	var wallet Wallet
	err := sqlx.GetContext(ctx, r.getExecutor(), &wallet, query, userID, currency)
	if err == sql.ErrNoRows {
		return nil, ErrWalletNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get wallet: %w", err)
	}

	return &wallet, nil
}

func (r *repository) GetOrCreateWallet(ctx context.Context, userID string, currency CurrencyCode) (*Wallet, error) {
	wallet, err := r.GetWallet(ctx, userID, currency)
	if err == nil {
		return wallet, nil
	}
	if err != ErrWalletNotFound {
		return nil, err
	}

	query := `
		INSERT INTO wallets (user_id, currency, balance, free_balance, version)
		VALUES ($1, $2, 0, 0, 1)
		RETURNING id, user_id, currency, balance, free_balance, 
		          last_daily_accrual_at, last_transfer_at, version, created_at, updated_at
	`

	var newWallet Wallet
	err = sqlx.GetContext(ctx, r.getExecutor(), &newWallet, query, userID, currency)
	if err != nil {
		return nil, fmt.Errorf("failed to create wallet: %w", err)
	}

	return &newWallet, nil
}

func (r *repository) UpdateWallet(ctx context.Context, wallet *Wallet) error {
	query := `
		UPDATE wallets
		SET balance = $1,
		    free_balance = $2,
		    last_daily_accrual_at = $3,
		    last_transfer_at = $4,
		    version = version + 1,
		    updated_at = NOW()
		WHERE id = $5
		RETURNING version
	`

	err := sqlx.GetContext(ctx, r.getExecutor(), &wallet.Version, query,
		wallet.Balance, wallet.FreeBalance, wallet.LastDailyAccrualAt, wallet.LastTransferAt, wallet.ID)
	if err != nil {
		return fmt.Errorf("failed to update wallet: %w", err)
	}

	return nil
}

func (r *repository) UpdateWalletWithVersion(ctx context.Context, wallet *Wallet, expectedVersion int64) error {
	query := `
		UPDATE wallets
		SET balance = $1,
		    free_balance = $2,
		    last_daily_accrual_at = $3,
		    last_transfer_at = $4,
		    version = version + 1,
		    updated_at = NOW()
		WHERE id = $5 AND version = $6
		RETURNING version
	`

	var newVersion int64
	err := sqlx.GetContext(ctx, r.getExecutor(), &newVersion, query,
		wallet.Balance, wallet.FreeBalance, wallet.LastDailyAccrualAt, wallet.LastTransferAt, wallet.ID, expectedVersion)
	if err == sql.ErrNoRows {
		return ErrOptimisticLock
	}
	if err != nil {
		return fmt.Errorf("failed to update wallet with version: %w", err)
	}

	wallet.Version = newVersion
	return nil
}

func (r *repository) CreateLedgerEntry(ctx context.Context, entry *LedgerEntry) error {
	query := `
		INSERT INTO ledger_entries (
			id, amount, currency, sender_wallet_id, receiver_wallet_id,
			category, reference_id, metadata, created_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`

	_, err := r.getExecutor().ExecContext(ctx, query,
		entry.ID, entry.Amount, entry.Currency, entry.SenderWalletID, entry.ReceiverWalletID,
		entry.Category, entry.ReferenceID, entry.Metadata, entry.CreatedAt)
	if err != nil {
		return fmt.Errorf("failed to create ledger entry: %w", err)
	}

	return nil
}

func (r *repository) GetUserTransactionHistory(ctx context.Context, userID string, currency CurrencyCode, category *TransactionCategory, limit, offset int) ([]*LedgerEntry, int, error) {
	countQuery := `
		SELECT COUNT(*)
		FROM ledger_entries le
		LEFT JOIN wallets ws ON le.sender_wallet_id = ws.id
		LEFT JOIN wallets wr ON le.receiver_wallet_id = wr.id
		WHERE le.currency = $1
		  AND (ws.user_id = $2 OR wr.user_id = $2)
	`

	args := []interface{}{currency, userID}
	if category != nil {
		countQuery += " AND le.category = $3"
		args = append(args, *category)
	}

	var total int
	err := sqlx.GetContext(ctx, r.getExecutor(), &total, countQuery, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to count transactions: %w", err)
	}

	query := `
		SELECT le.id, le.amount, le.currency, le.sender_wallet_id, le.receiver_wallet_id,
		       le.category, le.reference_id, le.metadata, le.created_at
		FROM ledger_entries le
		LEFT JOIN wallets ws ON le.sender_wallet_id = ws.id
		LEFT JOIN wallets wr ON le.receiver_wallet_id = wr.id
		WHERE le.currency = $1
		  AND (ws.user_id = $2 OR wr.user_id = $2)
		ORDER BY le.created_at DESC
		LIMIT $3 OFFSET $4
	`

	args = []interface{}{currency, userID}
	if category != nil {
		query = `
			SELECT le.id, le.amount, le.currency, le.sender_wallet_id, le.receiver_wallet_id,
			       le.category, le.reference_id, le.metadata, le.created_at
			FROM ledger_entries le
			LEFT JOIN wallets ws ON le.sender_wallet_id = ws.id
			LEFT JOIN wallets wr ON le.receiver_wallet_id = wr.id
			WHERE le.currency = $1
			  AND (ws.user_id = $2 OR wr.user_id = $2)
			  AND le.category = $3
			ORDER BY le.created_at DESC
			LIMIT $4 OFFSET $5
		`
		args = append(args, *category, limit, offset)
	} else {
		args = append(args, limit, offset)
	}

	var entries []*LedgerEntry
	err = sqlx.SelectContext(ctx, r.getExecutor(), &entries, query, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to get transaction history: %w", err)
	}

	return entries, total, nil
}

func (r *repository) GetLedgerEntryByReferenceID(ctx context.Context, referenceID string) (*LedgerEntry, error) {
	query := `
		SELECT id, amount, currency, sender_wallet_id, receiver_wallet_id,
		       category, reference_id, metadata, created_at
		FROM ledger_entries
		WHERE reference_id = $1
	`

	var entry LedgerEntry
	err := sqlx.GetContext(ctx, r.getExecutor(), &entry, query, referenceID)
	if err == sql.ErrNoRows {
		return nil, ErrLedgerEntryNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get ledger entry: %w", err)
	}

	return &entry, nil
}

func (r *repository) CreateReferral(ctx context.Context, referral *Referral) error {
	query := `
		INSERT INTO referrals (
			id, referrer_user_id, referee_user_id, bonus_ledger_entry_id, is_active, created_at
		) VALUES ($1, $2, $3, $4, $5, $6)
	`

	_, err := r.getExecutor().ExecContext(ctx, query,
		referral.ID, referral.ReferrerUserID, referral.RefereeUserID,
		referral.BonusLedgerEntryID, referral.IsActive, referral.CreatedAt)
	if err != nil {
		return fmt.Errorf("failed to create referral: %w", err)
	}

	return nil
}

func (r *repository) GetReferralsByReferrer(ctx context.Context, referrerUserID string) ([]*Referral, error) {
	query := `
		SELECT id, referrer_user_id, referee_user_id, bonus_ledger_entry_id,
		       is_active, created_at
		FROM referrals
		WHERE referrer_user_id = $1
		ORDER BY created_at DESC
	`

	var referrals []*Referral
	err := sqlx.SelectContext(ctx, r.getExecutor(), &referrals, query, referrerUserID)
	if err != nil {
		return nil, fmt.Errorf("failed to get referrals: %w", err)
	}

	return referrals, nil
}

func (r *repository) GetReferralByReferee(ctx context.Context, refereeUserID string) (*Referral, error) {
	query := `
		SELECT id, referrer_user_id, referee_user_id, bonus_ledger_entry_id,
		       is_active, created_at
		FROM referrals
		WHERE referee_user_id = $1
	`

	var referral Referral
	err := sqlx.GetContext(ctx, r.getExecutor(), &referral, query, refereeUserID)
	if err == sql.ErrNoRows {
		return nil, ErrReferralNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get referral: %w", err)
	}

	return &referral, nil
}

func (r *repository) GetOrCreateTransferLimit(ctx context.Context, userID, monthYear string) (*TransferLimit, error) {
	query := `
		SELECT id, user_id, month_year, transfers_count, total_sent_centinels, created_at, updated_at
		FROM transfer_limits
		WHERE user_id = $1 AND month_year = $2
	`

	var limit TransferLimit
	err := sqlx.GetContext(ctx, r.getExecutor(), &limit, query, userID, monthYear)
	if err == nil {
		return &limit, nil
	}
	if err != sql.ErrNoRows {
		return nil, fmt.Errorf("failed to get transfer limit: %w", err)
	}

	insertQuery := `
		INSERT INTO transfer_limits (user_id, month_year, transfers_count, total_sent_centinels)
		VALUES ($1, $2, 0, 0)
		RETURNING id, user_id, month_year, transfers_count, total_sent_centinels, created_at, updated_at
	`

	var newLimit TransferLimit
	err = sqlx.GetContext(ctx, r.getExecutor(), &newLimit, insertQuery, userID, monthYear)
	if err != nil {
		return nil, fmt.Errorf("failed to create transfer limit: %w", err)
	}

	return &newLimit, nil
}

func (r *repository) UpdateTransferLimit(ctx context.Context, limit *TransferLimit, oldTransfersCount int, oldTotalSent int64) error {
	query := `
		UPDATE transfer_limits
		SET transfers_count = $1,
		    total_sent_centinels = $2,
		    updated_at = NOW()
		WHERE id = $3 AND transfers_count = $4 AND total_sent_centinels = $5
	`

	res, err := r.getExecutor().ExecContext(ctx, query,
		limit.TransfersCount, limit.TotalSentCentinels, limit.ID,
		oldTransfersCount, oldTotalSent)
	if err != nil {
		return fmt.Errorf("failed to update transfer limit: %w", err)
	}

	rows, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rows == 0 {
		return ErrOptimisticLockFailure
	}

	return nil
}

func (r *repository) CreateViolationLog(ctx context.Context, violation *ViolationLog) error {
	query := `
		INSERT INTO economy_violations (
			id, user_id, violation_type, amount_attempted, details, ip_address, endpoint, created_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`

	_, err := r.getExecutor().ExecContext(ctx, query,
		violation.ID, violation.UserID, violation.ViolationType,
		violation.AmountAttempted, violation.Details, violation.IPAddress, violation.Endpoint, violation.CreatedAt)
	if err != nil {
		return fmt.Errorf("failed to create violation log: %w", err)
	}

	return nil
}

func (r *repository) GetViolationLogs(ctx context.Context, userID string, limit, offset int) ([]*ViolationLog, int, error) {
	countQuery := `SELECT COUNT(*) FROM economy_violations WHERE user_id = $1`

	var total int
	err := sqlx.GetContext(ctx, r.getExecutor(), &total, countQuery, userID)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to count violations: %w", err)
	}

	query := `
		SELECT id, user_id, violation_type, amount_attempted, details, ip_address, endpoint, created_at
		FROM economy_violations
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`

	var violations []*ViolationLog
	err = sqlx.SelectContext(ctx, r.getExecutor(), &violations, query, userID, limit, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to get violations: %w", err)
	}

	return violations, total, nil
}

func (r *repository) GetUserInteraction(ctx context.Context, senderID, receiverID string) (*UserInteraction, error) {
	query := `
		SELECT sender_id, receiver_id, total_transfers, total_amount, last_amount,
		       last_transfer_at, created_at, updated_at
		FROM user_interactions
		WHERE sender_id = $1 AND receiver_id = $2
	`

	var ui UserInteraction
	err := sqlx.GetContext(ctx, r.getExecutor(), &ui, query, senderID, receiverID)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get user interaction: %w", err)
	}

	return &ui, nil
}

func (r *repository) UpsertUserInteraction(ctx context.Context, senderID, receiverID string, amount int64) error {
	query := `
		INSERT INTO user_interactions (
			sender_id, receiver_id, total_transfers, total_amount, last_amount, last_transfer_at, created_at, updated_at
		) VALUES ($1, $2, 1, $3, $3, NOW(), NOW(), NOW())
		ON CONFLICT (sender_id, receiver_id)
		DO UPDATE SET
			total_transfers = user_interactions.total_transfers + 1,
			total_amount = user_interactions.total_amount + EXCLUDED.total_amount,
			last_amount = EXCLUDED.last_amount,
			last_transfer_at = NOW(),
			updated_at = NOW()
	`

	_, err := r.getExecutor().ExecContext(ctx, query, senderID, receiverID, amount)
	if err != nil {
		return fmt.Errorf("failed to upsert user interaction: %w", err)
	}
	return nil
}

func (r *repository) GetPairCooldown(ctx context.Context, senderID, receiverID string) (*PairCooldown, error) {
	query := `
		SELECT sender_user_id, receiver_user_id, repeat_level, last_grant_at, next_allowed_at, created_at, updated_at
		FROM pair_cooldowns
		WHERE sender_user_id = $1 AND receiver_user_id = $2
	`

	var pc PairCooldown
	err := sqlx.GetContext(ctx, r.getExecutor(), &pc, query, senderID, receiverID)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get pair cooldown: %w", err)
	}

	return &pc, nil
}

func (r *repository) UpsertPairCooldown(ctx context.Context, cooldown *PairCooldown) error {
	query := `
		INSERT INTO pair_cooldowns (
			sender_user_id, receiver_user_id, repeat_level, last_grant_at, next_allowed_at, created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
		ON CONFLICT (sender_user_id, receiver_user_id)
		DO UPDATE SET
			repeat_level = EXCLUDED.repeat_level,
			last_grant_at = EXCLUDED.last_grant_at,
			next_allowed_at = EXCLUDED.next_allowed_at,
			updated_at = NOW()
	`

	_, err := r.getExecutor().ExecContext(ctx, query,
		cooldown.SenderUserID, cooldown.ReceiverUserID, cooldown.RepeatLevel,
		cooldown.LastGrantAt, cooldown.NextAllowedAt)
	if err != nil {
		return fmt.Errorf("failed to upsert pair cooldown: %w", err)
	}

	return nil
}
