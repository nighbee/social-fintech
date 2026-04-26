package economy

import (
	"context"
	"database/sql"
	"fmt"
	"strings"

	"github.com/google/uuid"
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
	IncrementWalletBalanceAtomic(ctx context.Context, walletID string, amount int64) (int64, error)

	CreateLedgerEntry(ctx context.Context, entry *LedgerEntry) error
	GetUserTransactionHistory(ctx context.Context, userID string, currency CurrencyCode, category *TransactionCategory, limit, offset int) ([]*LedgerEntry, int, error)
	GetLedgerEntryByReferenceID(ctx context.Context, referenceID string) (*LedgerEntry, error)

	CreateReferral(ctx context.Context, referral *Referral) error
	GetReferralsByReferrer(ctx context.Context, referrerUserID string) ([]*Referral, error)
	GetReferralByReferee(ctx context.Context, refereeUserID string) (*Referral, error)
	ActivateReferral(ctx context.Context, refereeUserID, bonusLedgerEntryID string) error
	GetUserActivationState(ctx context.Context, userID string) (string, *sql.NullTime, error)

	GetOrCreateTransferLimit(ctx context.Context, userID, monthYear string) (*TransferLimit, error)
	UpdateTransferLimit(ctx context.Context, limit *TransferLimit, oldTransfersCount int, oldTotalSent int64) error

	CreateViolationLog(ctx context.Context, violation *ViolationLog) error
	GetViolationLogs(ctx context.Context, userID string, limit, offset int) ([]*ViolationLog, int, error)

	GetUserInteraction(ctx context.Context, senderID, receiverID string) (*UserInteraction, error)
	UpsertUserInteraction(ctx context.Context, senderID, receiverID string, amount int64) error

	GetPairCooldown(ctx context.Context, senderID, receiverID string) (*PairCooldown, error)
	GetLastTransferMessageBetweenUsers(ctx context.Context, senderID, receiverID string) (string, error)
	UpsertPairCooldown(ctx context.Context, cooldown *PairCooldown) error
	UpsertGoldPeriodStat(ctx context.Context, userID string, periodYear, periodWeek int, amount int64) error
	GetTopGoldUserForWeek(ctx context.Context, periodYear, periodWeek int) (string, int64, error)
	UpsertProfileSealProjection(ctx context.Context, senderID, receiverID string, sealsDelta int64, receiverGoldBalanceCentinels int64, receiverRankTier string) error
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
		       total_sent_amount, total_received_amount,
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

	newID := uuid.New().String()
	query := `
		INSERT INTO wallets (id, user_id, currency, balance, free_balance, version, total_sent_amount, total_received_amount)
		VALUES ($3, $1, $2, 0, 0, 1, 0, 0)
		RETURNING id, user_id, currency, balance, free_balance, 
		          total_sent_amount, total_received_amount,
		          last_daily_accrual_at, last_transfer_at, version, created_at, updated_at
	`

	var newWallet Wallet
	err = sqlx.GetContext(ctx, r.getExecutor(), &newWallet, query, userID, currency, newID)
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
		    total_sent_amount = $3,
		    total_received_amount = $4,
		    last_daily_accrual_at = $5,
		    last_transfer_at = $6,
		    version = version + 1,
		    updated_at = NOW()
		WHERE id = $7
		RETURNING version
	`

	err := sqlx.GetContext(ctx, r.getExecutor(), &wallet.Version, query,
		wallet.Balance, wallet.FreeBalance, wallet.TotalSentAmount, wallet.TotalReceivedAmount, wallet.LastDailyAccrualAt, wallet.LastTransferAt, wallet.ID)
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
		    total_sent_amount = $3,
		    total_received_amount = $4,
		    last_daily_accrual_at = $5,
		    last_transfer_at = $6,
		    version = version + 1,
		    updated_at = NOW()
		WHERE id = $7 AND version = $8
		RETURNING version
	`

	var newVersion int64
	err := sqlx.GetContext(ctx, r.getExecutor(), &newVersion, query,
		wallet.Balance, wallet.FreeBalance, wallet.TotalSentAmount, wallet.TotalReceivedAmount, wallet.LastDailyAccrualAt, wallet.LastTransferAt, wallet.ID, expectedVersion)
	if err == sql.ErrNoRows {
		fmt.Printf("DEBUG OPTIMISTIC: ID='%s', Version=%d, Balance=%d\n", wallet.ID, expectedVersion, wallet.Balance)
		return ErrOptimisticLock
	}
	if err != nil {
		fmt.Printf("DEBUG UPDATE ERROR: %v\n", err)
		return fmt.Errorf("failed to update wallet with version: %w", err)
	}

	wallet.Version = newVersion
	return nil
}

func (r *repository) IncrementWalletBalanceAtomic(ctx context.Context, walletID string, amount int64) (int64, error) {
	query := `
		UPDATE wallets
		SET balance = balance + $1,
		    total_received_amount = total_received_amount + $1,
		    version = version + 1,
		    updated_at = NOW()
		WHERE id = $2
		RETURNING balance
	`

	var newBalance int64
	err := sqlx.GetContext(ctx, r.getExecutor(), &newBalance, query, amount, walletID)
	if err != nil {
		return 0, fmt.Errorf("failed to increment wallet balance atomically: %w", err)
	}

	return newBalance, nil
}

func (r *repository) CreateLedgerEntry(ctx context.Context, entry *LedgerEntry) error {
	query := `
		INSERT INTO ledger_entries (
			id, amount, currency, sender_wallet_id, receiver_wallet_id,
			category, reference_id, metadata, created_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`

	var metadataVal interface{}
	if entry.Metadata != nil {
		metadataVal = string(entry.Metadata)
	}

	_, err := r.getExecutor().ExecContext(ctx, query,
		entry.ID, entry.Amount, entry.Currency, entry.SenderWalletID, entry.ReceiverWalletID,
		entry.Category, entry.ReferenceID, metadataVal, entry.CreatedAt)
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

func (r *repository) UpsertGoldPeriodStat(ctx context.Context, userID string, periodYear, periodWeek int, amount int64) error {
	query := `
		INSERT INTO gold_reputation_period_stats (
			user_id, period_type, period_year, period_week, gold_received_centinels, computed_at
		) VALUES ($1, 'weekly', $2, $3, $4, NOW())
		ON CONFLICT (user_id, period_type, period_year, period_week)
		DO UPDATE SET
			gold_received_centinels = gold_reputation_period_stats.gold_received_centinels + EXCLUDED.gold_received_centinels,
			computed_at = NOW()
	`

	if _, err := r.getExecutor().ExecContext(ctx, query, userID, periodYear, periodWeek, amount); err != nil {
		return fmt.Errorf("failed to upsert gold period stat: %w", err)
	}

	return nil
}

func (r *repository) GetTopGoldUserForWeek(ctx context.Context, periodYear, periodWeek int) (string, int64, error) {
	query := `
		SELECT user_id::text, gold_received_centinels
		FROM gold_reputation_period_stats
		WHERE period_type = 'weekly'
		  AND period_year = $1
		  AND period_week = $2
		ORDER BY gold_received_centinels DESC, user_id ASC
		LIMIT 1
	`
	// DETERMINISTIC TIE-BREAK RULE:
	// When multiple users have the same gold_received_centinels score:
	// 1. PRIMARY: gold_received_centinels DESC (higher score wins)
	// 2. SECONDARY (TIE-BREAK): user_id ASC (alphabetically first UUID wins)
	// This ensures the same champion is selected consistently across server restarts,
	// data rebuilds, and concurrent queries. Prevents "phantom leader changes" where
	// users see different champions in the same week.

	type Result struct {
		UserID string `db:"user_id"`
		Amount int64  `db:"gold_received_centinels"`
	}

	var result Result
	err := sqlx.GetContext(ctx, r.getExecutor(), &result, query, periodYear, periodWeek)
	if err != nil {
		if err == sql.ErrNoRows {
			return "", 0, nil
		}
		return "", 0, fmt.Errorf("failed to get top gold user for week: %w", err)
	}

	return result.UserID, result.Amount, nil
}

func (r *repository) UpsertProfileSealProjection(ctx context.Context, senderID, receiverID string, sealsDelta int64, receiverGoldBalanceCentinels int64, receiverRankTier string) error {
	senderQuery := `
		INSERT INTO profiles (
			user_id, total_gold_seals_received, total_silver_seals_given, reputation_score, current_rank_tier, created_at, updated_at
		) VALUES ($1, 0, $2, 0, 'Pearl', NOW(), NOW())
		ON CONFLICT (user_id)
		DO UPDATE SET
			total_silver_seals_given = profiles.total_silver_seals_given + EXCLUDED.total_silver_seals_given,
			updated_at = NOW()
	`

	if _, err := r.getExecutor().ExecContext(ctx, senderQuery, senderID, sealsDelta); err != nil {
		return fmt.Errorf("failed to upsert sender profile seal projection: %w", err)
	}

	receiverQuery := `
		INSERT INTO profiles (
			user_id, total_gold_seals_received, total_silver_seals_given, reputation_score, current_rank_tier, created_at, updated_at
		) VALUES ($1, $2, 0, $3, $4, NOW(), NOW())
		ON CONFLICT (user_id)
		DO UPDATE SET
			total_gold_seals_received = profiles.total_gold_seals_received + EXCLUDED.total_gold_seals_received,
			reputation_score = EXCLUDED.reputation_score,
			current_rank_tier = EXCLUDED.current_rank_tier,
			updated_at = NOW()
	`

	if _, err := r.getExecutor().ExecContext(ctx, receiverQuery, receiverID, sealsDelta, receiverGoldBalanceCentinels/CentinelsPerSeal, receiverRankTier); err != nil {
		return fmt.Errorf("failed to upsert receiver profile seal projection: %w", err)
	}

	return nil
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

func (r *repository) ActivateReferral(ctx context.Context, refereeUserID, bonusLedgerEntryID string) error {
	_, err := r.getExecutor().ExecContext(ctx, `
		UPDATE referrals
		SET is_active = true,
		    bonus_ledger_entry_id = $2
		WHERE referee_user_id = $1
	`, refereeUserID, bonusLedgerEntryID)
	if err != nil {
		return fmt.Errorf("failed to activate referral: %w", err)
	}
	return nil
}

func (r *repository) GetUserActivationState(ctx context.Context, userID string) (string, *sql.NullTime, error) {
	row := struct {
		ActivationStatus string       `db:"activation_status"`
		Restrictions     sql.NullTime `db:"restrictions_until"`
	}{}
	if err := sqlx.GetContext(ctx, r.getExecutor(), &row, `SELECT activation_status, restrictions_until FROM users WHERE id = $1`, userID); err != nil {
		// Backward compatibility for stale local DBs where activation columns are missing.
		// In this case treat user as active to avoid hard 500 on task/economy flows.
		errMsg := strings.ToLower(err.Error())
		if strings.Contains(errMsg, "activation_status") || strings.Contains(errMsg, "restrictions_until") {
			return "active", nil, nil
		}
		return "", nil, fmt.Errorf("failed to scan activation state: %w", err)
	}
	return row.ActivationStatus, &row.Restrictions, nil
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

func (r *repository) GetLastTransferMessageBetweenUsers(ctx context.Context, senderID, receiverID string) (string, error) {
	query := `
		SELECT le.metadata->>'reason' as reason, le.metadata->>'message' as message
		FROM ledger_entries le
		JOIN wallets ws ON le.sender_wallet_id = ws.id
		WHERE le.category = 'P2P_TRANSFER'
		  AND ws.user_id = $1
		  AND (le.metadata->>'receiver_user_id' = $2 OR le.metadata->>'referee_id' = $2)
		ORDER BY le.created_at DESC
		LIMIT 1
	`
	
	row := struct {
		Reason  sql.NullString `db:"reason"`
		Message sql.NullString `db:"message"`
	}{}
	
	err := sqlx.GetContext(ctx, r.getExecutor(), &row, query, senderID, receiverID)
	if err != nil {
		if err == sql.ErrNoRows {
			return "", nil
		}
		return "", fmt.Errorf("failed to get last transfer message: %w", err)
	}
	
	if row.Reason.Valid && row.Reason.String != "" {
		return row.Reason.String, nil
	}
	if row.Message.Valid && row.Message.String != "" {
		return row.Message.String, nil
	}
	return "", nil
}
