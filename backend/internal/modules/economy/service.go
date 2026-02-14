package economy

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/brightbund-backend/internal/config"
)

type Service interface {
	GetUserBalance(ctx context.Context, userID string) (*BalanceResponse, error)
	GetOrCreateWallets(ctx context.Context, userID string) error

	TransferSeals(ctx context.Context, senderUserID string, req *TransferRequest) (*TransferResponse, error)
	GiveSealToPost(ctx context.Context, userID, postID string, req *GiveSealToPostRequest) (*TransferResponse, error)
	GiveSealToUser(ctx context.Context, fromUserID, toUserID string, req *GiveSealToUserRequest) (*TransferResponse, error)

	GetTransactionHistory(ctx context.Context, userID string, req *TransactionHistoryRequest) (*TransactionHistoryResponse, error)

	ClaimDailyAccrual(ctx context.Context, userID, idempotencyKey string) (*AccrualResponse, error)
	ProcessDailyAccrual(ctx context.Context, userID string) error
	ProcessReferralBonus(ctx context.Context, referrerUserID, refereeUserID string) error

	GetLimits(ctx context.Context, userID string) (*LimitsResponse, error)
	GetReferralStats(ctx context.Context, userID string) (*ReferralStatsResponse, error)

	GetViolationLogs(ctx context.Context, userID string, limit, offset int) ([]*ViolationLog, int, error)

	ProcessIAPDeposit(ctx context.Context, userID string, amountCentinels int64, currency CurrencyCode, receiptID string) error
	ChargeForTaskCreation(ctx context.Context, userID, taskID string, cost int64) error
	RewardForTaskCompletion(ctx context.Context, userID, taskID string, reward int64) error

	AdminAdjustBalance(ctx context.Context, userID string, amountCentinels int64, currency CurrencyCode, reason string) error
}

type service struct {
	repo             Repository
	cfg              config.EconomyConfig
	cacheInvalidator StatsCacheInvalidator // Optional cache invalidator for profile stats
}

func NewService(repo Repository, cfg config.EconomyConfig, cacheInvalidator StatsCacheInvalidator) Service {
	// Use no-op invalidator if none provided
	if cacheInvalidator == nil {
		cacheInvalidator = &NoopCacheInvalidator{}
	}
	return &service{
		repo:             repo,
		cfg:              cfg,
		cacheInvalidator: cacheInvalidator,
	}
}

func (s *service) executeWithRetry(ctx context.Context, fn func() error) error {
	maxRetries := 3
	for i := 0; i < maxRetries; i++ {
		err := fn()
		if err == nil {
			return nil
		}
		// Check if error is retryable (optimistic lock or database concurrency error)
		if !isRetryableError(err) {
			return err
		}
		// Simple backoff: 50ms, 100ms, 150ms
		time.Sleep(time.Duration((i+1)*50) * time.Millisecond)
	}
	return NewEconomyError(ErrOptimisticLockFailure, CodeOptimisticLock, "Failed to complete transaction after retries due to concurrent updates", 409)
}

// isRetryableError checks if an error is caused by concurrency and should be retried
func isRetryableError(err error) bool {
	if err == nil {
		return false
	}

	// Check for optimistic lock failure
	if errors.Is(err, ErrOptimisticLockFailure) {
		return true
	}

	// Check error message for database concurrency errors
	errMsg := err.Error()

	// PostgreSQL serialization/concurrency errors
	retryablePatterns := []string{
		"could not serialize access",
		"deadlock detected",
		"failed to commit transaction",
		"failed to update transfer limit",
		"failed to update wallet",
		"failed to update cooldown",
		"failed to upsert pair cooldown",
		"failed to get pair cooldown",
		"failed to get wallet",
		"failed to get receiver wallet",
		"failed to create ledger entry",
		"pq: could not serialize",
		"SQLSTATE 40001", // serialization_failure
		"SQLSTATE 40P01", // deadlock_detected
	}

	for _, pattern := range retryablePatterns {
		if strings.Contains(errMsg, pattern) {
			return true
		}
	}

	return false
}

func (s *service) GetUserBalance(ctx context.Context, userID string) (*BalanceResponse, error) {
	silverWallet, err := s.repo.GetWallet(ctx, userID, CurrencySilverSeal)
	if err != nil && err != ErrWalletNotFound {
		return nil, WrapErrorf(err, "failed to get silver wallet")
	}

	goldWallet, err := s.repo.GetWallet(ctx, userID, CurrencyGoldSeal)
	if err != nil && err != ErrWalletNotFound {
		return nil, WrapErrorf(err, "failed to get gold wallet")
	}

	return ToBalanceResponse(silverWallet, goldWallet), nil
}

func (s *service) GetOrCreateWallets(ctx context.Context, userID string) error {
	_, err := s.repo.GetOrCreateWallet(ctx, userID, CurrencySilverSeal)
	if err != nil {
		return WrapErrorf(err, "failed to create silver wallet")
	}

	_, err = s.repo.GetOrCreateWallet(ctx, userID, CurrencyGoldSeal)
	if err != nil {
		return WrapErrorf(err, "failed to create gold wallet")
	}

	return nil
}

func (s *service) TransferSeals(ctx context.Context, senderUserID string, req *TransferRequest) (*TransferResponse, error) {
	if req.Amount <= 0 {
		return nil, NewInvalidAmountError(req.Amount)
	}

	currency := CurrencyCode(req.Currency)
	if !currency.IsValid() {
		return nil, NewInvalidCurrencyError(req.Currency)
	}

	if senderUserID == req.RecipientUserID {
		return nil, NewSelfTransferError()
	}

	amountCents := SealsToCentinels(req.Amount)
	isSeal := currency == CurrencySilverSeal || currency == CurrencyGoldSeal

	if isSeal && amountCents != CentinelsPerSeal {
		return nil, NewValidationError("amount", "seal transfer must be exactly 1 seal")
	}

	var response *TransferResponse
	err := s.executeWithRetry(ctx, func() error {
		tx, err := s.repo.BeginTx(ctx)
		if err != nil {
			return WrapErrorf(err, "failed to begin transaction")
		}
		defer tx.Rollback()

		txRepo := s.repo.WithTx(tx)

		if isSeal {
			// 1. Check/Update Cooldown for Seals
			cooldown, err := txRepo.GetPairCooldown(ctx, senderUserID, req.RecipientUserID)
			if err != nil {
				return WrapErrorf(err, "failed to get pair cooldown")
			}

			now := time.Now()
			repeatLevel := 1

			if cooldown != nil {
				if now.Before(cooldown.NextAllowedAt) {
					return NewCooldownError(cooldown.LastGrantAt, cooldown.NextAllowedAt.Sub(cooldown.LastGrantAt), cooldown.RepeatLevel)
				}

				diff := now.Sub(cooldown.LastGrantAt)
				repeatLevel = cooldown.RepeatLevel

				threshold1 := time.Duration(s.cfg.SealDecayThreshold1Days) * 24 * time.Hour
				threshold2 := time.Duration(s.cfg.SealDecayThreshold2Days) * 24 * time.Hour

				if diff >= threshold2 {
					repeatLevel = max(repeatLevel-2, 1)
				} else if diff >= threshold1 {
					repeatLevel = max(repeatLevel-1, 1)
				}
			}

			// Update levels later after transaction success
			// But we need to keep track of it
			ctx = context.WithValue(ctx, "seal_repeat_level", repeatLevel)
		}

		monthYear := FormatMonthYear(time.Now())
		limit, err := txRepo.GetOrCreateTransferLimit(ctx, senderUserID, monthYear)
		if err != nil {
			return WrapErrorf(err, "failed to get transfer limit")
		}

		if !limit.CanTransfer(s.cfg.MaxDailyTransfers) {
			s.logViolation(ctx, senderUserID, ViolationMonthlyLimitExceeded, "/economy/transfer", &amountCents, map[string]interface{}{
				"recipient_id":  req.RecipientUserID,
				"current_count": limit.TransfersCount,
				"limit":         s.cfg.MaxDailyTransfers,
			})
			return NewMonthlyLimitError(senderUserID, req.RecipientUserID, currency,
				int64(s.cfg.MaxDailyTransfers), int64(limit.TransfersCount), amountCents)
		}

		senderWallet, err := txRepo.GetWallet(ctx, senderUserID, currency)
		if err != nil {
			return WrapErrorf(err, "failed to get sender wallet")
		}

		if senderWallet.LastTransferAt != nil {
			elapsed := time.Since(*senderWallet.LastTransferAt)
			if elapsed < time.Duration(s.cfg.TransferCooldownSeconds)*time.Second {
				s.logViolation(ctx, senderUserID, ViolationCooldownBreach, "/economy/transfer", &amountCents, map[string]interface{}{
					"recipient_id":     req.RecipientUserID,
					"elapsed_seconds":  int(elapsed.Seconds()),
					"cooldown_seconds": s.cfg.TransferCooldownSeconds,
				})
				return NewCooldownError(*senderWallet.LastTransferAt, time.Duration(s.cfg.TransferCooldownSeconds)*time.Second, 0)
			}
		}

		if ui, err := s.repo.GetUserInteraction(ctx, senderUserID, req.RecipientUserID); err == nil && ui != nil {
			if ui.LastAmount == amountCents && ui.TotalTransfers >= 5 {
				if time.Since(ui.LastTransferAt) < 24*time.Hour {
					s.logViolation(ctx, senderUserID, ViolationRepeatTransferPattern, "/economy/transfer", &amountCents, map[string]interface{}{
						"recipient_id":    req.RecipientUserID,
						"total_transfers": ui.TotalTransfers,
						"last_amount":     ui.LastAmount,
					})
				}
			}
		}

		if !senderWallet.HasSufficientBalance(amountCents) {
			s.logViolation(ctx, senderUserID, ViolationInsufficientFundsAttempt, "/economy/transfer", &amountCents, map[string]interface{}{
				"recipient_id": req.RecipientUserID,
				"available":    senderWallet.Balance,
				"required":     amountCents,
			})
			return NewInsufficientFundsError(senderUserID, currency, amountCents, senderWallet.Balance)
		}

		receiverWallet, err := txRepo.GetOrCreateWallet(ctx, req.RecipientUserID, currency)
		if err != nil {
			return WrapErrorf(err, "failed to get receiver wallet")
		}

		referenceID := req.IdempotencyKey
		if referenceID == "" {
			referenceID = fmt.Sprintf("transfer_%s_%s_%d", senderUserID, req.RecipientUserID, time.Now().Unix())
		}

		if existing, err := txRepo.GetLedgerEntryByReferenceID(ctx, referenceID); err == nil && existing != nil {
			response = &TransferResponse{
				LedgerEntryID:   existing.ID,
				SenderBalance:   CentinelsToSeals(senderWallet.Balance),
				ReceiverBalance: CentinelsToSeals(receiverWallet.Balance),
				Timestamp:       existing.CreatedAt,
			}
			return nil
		}

		senderWallet.Balance -= amountCents
		if currency == CurrencySilverSeal && senderWallet.FreeBalance > 0 {
			deductFromFree := min(senderWallet.FreeBalance, amountCents)
			senderWallet.FreeBalance -= deductFromFree
		}
		now := time.Now()
		senderWallet.LastTransferAt = &now

		if err := txRepo.UpdateWalletWithVersion(ctx, senderWallet, senderWallet.Version); err != nil {
			return err // Can be ErrOptimisticLockFailure
		}

		// Use optimistic locking for receiver as well to prevent race conditions
		receiverWallet.Balance += amountCents
		if err := txRepo.UpdateWalletWithVersion(ctx, receiverWallet, receiverWallet.Version); err != nil {
			return err
		}

		entry := &LedgerEntry{
			ID:               uuid.New().String(),
			Amount:           amountCents,
			Currency:         currency,
			SenderWalletID:   &senderWallet.ID,
			ReceiverWalletID: &receiverWallet.ID,
			Category:         CategoryP2PTransfer,
			ReferenceID:      referenceID,
			Metadata:         mustMarshalJSON(map[string]interface{}{"reason": req.Reason}),
			CreatedAt:        time.Now(),
		}

		if err := txRepo.CreateLedgerEntry(ctx, entry); err != nil {
			return WrapErrorf(err, "failed to create ledger entry")
		}

		oldTransfersCount := limit.TransfersCount
		oldTotalSent := limit.TotalSentCentinels
		limit.IncrementTransfer(amountCents)
		if err := txRepo.UpdateTransferLimit(ctx, limit, oldTransfersCount, oldTotalSent); err != nil {
			return WrapErrorf(err, "failed to update transfer limit")
		}

		if isSeal {
			if rl, ok := ctx.Value("seal_repeat_level").(int); ok {
				now := time.Now()
				duration := s.getCooldownDuration(rl)
				newLevel := rl + 1
				if newLevel > 5 {
					newLevel = 5
				}

				newCooldown := &PairCooldown{
					SenderUserID:   senderUserID,
					ReceiverUserID: req.RecipientUserID,
					RepeatLevel:    newLevel,
					LastGrantAt:    now,
					NextAllowedAt:  now.Add(duration),
				}

				if err := txRepo.UpsertPairCooldown(ctx, newCooldown); err != nil {
					return WrapErrorf(err, "failed to update cooldown")
				}
			}
		}

		if err := tx.Commit(); err != nil {
			return WrapErrorf(err, "failed to commit transaction")
		}

		// Invalidate stats cache for both sender and receiver (fire-and-forget)
		_ = s.cacheInvalidator.InvalidateStats(ctx, senderUserID)
		_ = s.cacheInvalidator.InvalidateStats(ctx, req.RecipientUserID)

		_ = s.repo.UpsertUserInteraction(ctx, senderUserID, req.RecipientUserID, amountCents)

		response = &TransferResponse{
			LedgerEntryID:   entry.ID,
			SenderBalance:   CentinelsToSeals(senderWallet.Balance),
			ReceiverBalance: CentinelsToSeals(receiverWallet.Balance),
			Timestamp:       entry.CreatedAt,
		}
		return nil
	})

	return response, err
}

func (s *service) GiveSealToPost(ctx context.Context, userID, postID string, req *GiveSealToPostRequest) (*TransferResponse, error) {
	currency := CurrencyCode(req.Currency)
	if !currency.IsValid() {
		return nil, NewInvalidCurrencyError(req.Currency)
	}

	metadata := map[string]interface{}{
		"post_id": postID,
		"context": "post_seal",
	}

	return s.processSealTransfer(ctx, userID, req.ReceiverUserID, req.Amount*CentinelsPerSeal, currency, CategoryPostSeal, req.IdempotencyKey, metadata)
}

func (s *service) GiveSealToUser(ctx context.Context, fromUserID, toUserID string, req *GiveSealToUserRequest) (*TransferResponse, error) {
	currency := CurrencyCode(req.Currency)
	if !currency.IsValid() {
		return nil, NewInvalidCurrencyError(req.Currency)
	}

	metadata := map[string]interface{}{
		"message": StringOrEmpty(req.Message),
		"context": "user_seal",
	}

	amountCents := SealsToCentinels(req.Amount)

	return s.processSealTransfer(ctx, fromUserID, toUserID, amountCents, currency, CategoryP2PTransfer, req.IdempotencyKey, metadata)
}

func (s *service) GetTransactionHistory(ctx context.Context, userID string, req *TransactionHistoryRequest) (*TransactionHistoryResponse, error) {
	silverWallet, _ := s.repo.GetWallet(ctx, userID, CurrencySilverSeal)
	goldWallet, _ := s.repo.GetWallet(ctx, userID, CurrencyGoldSeal)

	var walletIDs []string
	if silverWallet != nil {
		walletIDs = append(walletIDs, silverWallet.ID)
	}
	if goldWallet != nil {
		walletIDs = append(walletIDs, goldWallet.ID)
	}

	if len(walletIDs) == 0 {
		return &TransactionHistoryResponse{
			Transactions: []TransactionItem{},
			Page:         req.Page,
			PageSize:     req.PageSize,
			Total:        0,
		}, nil
	}

	currency := CurrencySilverSeal
	if req.Currency != "" {
		currency = CurrencyCode(req.Currency)
		if !currency.IsValid() {
			currency = CurrencySilverSeal
		}
	}

	var categoryPtr *TransactionCategory
	if req.Category != "" {
		cat := TransactionCategory(req.Category)
		if cat.IsValid() {
			categoryPtr = &cat
		}
	}

	offset := (req.Page - 1) * req.PageSize
	entries, total, err := s.repo.GetUserTransactionHistory(ctx, userID, currency, categoryPtr, req.PageSize, offset)
	if err != nil {
		return nil, WrapErrorf(err, "failed to get transaction history")
	}

	transactions := make([]TransactionItem, 0, len(entries))
	for _, entry := range entries {
		txType := "RECEIVED"
		if entry.SenderWalletID != nil {
			if silverWallet != nil && *entry.SenderWalletID == silverWallet.ID {
				txType = "SENT"
			}
			if goldWallet != nil && *entry.SenderWalletID == goldWallet.ID {
				txType = "SENT"
			}
		}

		transactions = append(transactions, TransactionItem{
			ID:        entry.ID,
			Type:      txType,
			Amount:    CentinelsToSeals(entry.Amount),
			Currency:  entry.Currency,
			Category:  entry.Category,
			Timestamp: entry.CreatedAt,
		})
	}

	return &TransactionHistoryResponse{
		Transactions: transactions,
		Page:         req.Page,
		PageSize:     req.PageSize,
		Total:        int64(total),
	}, nil
}

func (s *service) ClaimDailyAccrual(ctx context.Context, userID, idempotencyKey string) (*AccrualResponse, error) {
	var response *AccrualResponse
	err := s.executeWithRetry(ctx, func() error {
		tx, err := s.repo.BeginTx(ctx)
		if err != nil {
			return WrapErrorf(err, "failed to begin transaction")
		}
		defer tx.Rollback()

		txRepo := s.repo.WithTx(tx)

		wallet, err := txRepo.GetOrCreateWallet(ctx, userID, CurrencySilverSeal)
		if err != nil {
			return WrapErrorf(err, "failed to get wallet")
		}

		now := time.Now()
		if !wallet.NeedsDailyAccrual(now) {
			// Next claim is 48 hours after last accrual
			nextClaim := wallet.LastDailyAccrualAt.Add(time.Duration(AccrualIntervalHours) * time.Hour)
			return NewDailyAccrualError(nextClaim)
		}

		if !wallet.CanReceiveFreeAccrual(s.cfg.MaxFreeSilverBalance) {
			s.logViolation(ctx, userID, ViolationFreeSilverCap, "/economy/accrual/claim", nil, map[string]interface{}{
				"current_free_balance": wallet.FreeBalance,
				"max_free_balance":     s.cfg.MaxFreeSilverBalance,
			})
			return NewFreeSilverCapError()
		}

		wallet.Balance += s.cfg.DailyAccrualCents
		wallet.FreeBalance += s.cfg.DailyAccrualCents
		wallet.LastDailyAccrualAt = &now

		if err := txRepo.UpdateWalletWithVersion(ctx, wallet, wallet.Version); err != nil {
			return err
		}

		referenceID := idempotencyKey
		if referenceID == "" {
			referenceID = fmt.Sprintf("accrual_%s_%s", userID, now.Format("2006-01-02"))
		}

		if existing, err := txRepo.GetLedgerEntryByReferenceID(ctx, referenceID); err == nil && existing != nil {
			// Next claim is 48 hours from now
			nextClaim := now.Add(time.Duration(AccrualIntervalHours) * time.Hour)
			response = &AccrualResponse{
				Success:    true,
				Amount:     s.cfg.DailyAccrualSeals,
				NewBalance: CentinelsToSeals(wallet.Balance),
				NextClaim:  nextClaim,
			}
			return nil
		}

		entry := &LedgerEntry{
			ID:               uuid.New().String(),
			Amount:           s.cfg.DailyAccrualCents,
			Currency:         CurrencySilverSeal,
			ReceiverWalletID: &wallet.ID,
			Category:         CategoryDailyAccrual,
			ReferenceID:      referenceID,
			Metadata:         mustMarshalJSON(map[string]interface{}{}),
			CreatedAt:        now,
		}

		if err := txRepo.CreateLedgerEntry(ctx, entry); err != nil {
			return WrapErrorf(err, "failed to create ledger entry")
		}

		if err := tx.Commit(); err != nil {
			return WrapErrorf(err, "failed to commit transaction")
		}

		// Invalidate stats cache for user (fire-and-forget)
		_ = s.cacheInvalidator.InvalidateStats(ctx, userID)

		// Next claim is 48 hours from now
		nextClaim := now.Add(time.Duration(AccrualIntervalHours) * time.Hour)
		response = &AccrualResponse{
			Success:    true,
			Amount:     s.cfg.DailyAccrualSeals,
			NewBalance: CentinelsToSeals(wallet.Balance),
			NextClaim:  nextClaim,
		}
		return nil
	})

	return response, err
}

func (s *service) ProcessDailyAccrual(ctx context.Context, userID string) error {
	_, err := s.ClaimDailyAccrual(ctx, userID, "")
	return err
}

func (s *service) ProcessReferralBonus(ctx context.Context, referrerUserID, refereeUserID string) error {
	if referrerUserID == refereeUserID {
		return NewSelfReferralError()
	}

	existing, err := s.repo.GetReferralByReferee(ctx, refereeUserID)
	if err != nil && err != ErrReferralNotFound {
		return WrapErrorf(err, "failed to check existing referral")
	}
	if existing != nil {
		return NewReferralExistsError()
	}

	err = s.executeWithRetry(ctx, func() error {
		tx, err := s.repo.BeginTx(ctx)
		if err != nil {
			return WrapErrorf(err, "failed to begin transaction")
		}
		defer tx.Rollback()

		txRepo := s.repo.WithTx(tx)

		// Check inside transaction to be safe or just rely on unique constraint?
		// Re-checking here might be safer if we want to catch it before insert
		// but simple wrap of the transaction part is enough.

		wallet, err := txRepo.GetOrCreateWallet(ctx, referrerUserID, CurrencySilverSeal)
		if err != nil {
			return WrapErrorf(err, "failed to get referrer wallet")
		}

		wallet.Balance += s.cfg.ReferralBonusCents

		if err := txRepo.UpdateWalletWithVersion(ctx, wallet, wallet.Version); err != nil {
			return err
		}

		referenceID := fmt.Sprintf("referral_%s_%s", referrerUserID, refereeUserID)
		// Check for idempotency/duplicates inside Tx to avoid errors
		if existing, err := txRepo.GetLedgerEntryByReferenceID(ctx, referenceID); err == nil && existing != nil {
			return NewReferralExistsError()
		}

		entry := &LedgerEntry{
			ID:               uuid.New().String(),
			Amount:           s.cfg.ReferralBonusCents,
			Currency:         CurrencySilverSeal,
			ReceiverWalletID: &wallet.ID,
			Category:         CategoryReferralBonus,
			ReferenceID:      referenceID,
			Metadata:         mustMarshalJSON(map[string]interface{}{"referee_id": refereeUserID}),
			CreatedAt:        time.Now(),
		}

		if err := txRepo.CreateLedgerEntry(ctx, entry); err != nil {
			return WrapErrorf(err, "failed to create ledger entry")
		}

		referral := &Referral{
			ID:                 uuid.New().String(),
			ReferrerUserID:     referrerUserID,
			RefereeUserID:      refereeUserID,
			BonusLedgerEntryID: &entry.ID,
			IsActive:           true,
			CreatedAt:          time.Now(),
		}

		if err := txRepo.CreateReferral(ctx, referral); err != nil {
			return WrapErrorf(err, "failed to create referral")
		}

		if err := tx.Commit(); err != nil {
			return WrapErrorf(err, "failed to commit transaction")
		}

		// Invalidate stats cache for referrer (fire-and-forget)
		_ = s.cacheInvalidator.InvalidateStats(ctx, referrerUserID)

		return nil
	})

	return err
}

func (s *service) GetLimits(ctx context.Context, userID string) (*LimitsResponse, error) {
	wallet, _ := s.repo.GetWallet(ctx, userID, CurrencySilverSeal)

	monthYear := FormatMonthYear(time.Now())
	limit, err := s.repo.GetOrCreateTransferLimit(ctx, userID, monthYear)
	if err != nil {
		return nil, WrapErrorf(err, "failed to get transfer limit")
	}

	now := time.Now()
	nextReset := time.Date(now.Year(), now.Month()+1, 1, 0, 0, 0, 0, time.UTC)

	dailyClaimed := false
	var nextAccrual *time.Time
	if wallet != nil && wallet.LastDailyAccrualAt != nil {
		if !wallet.NeedsDailyAccrual(now) {
			dailyClaimed = true
			next := wallet.LastDailyAccrualAt.Add(24 * time.Hour)
			nextAccrual = &next
		}
	}

	return &LimitsResponse{
		MonthlyTransferLimit: int64(s.cfg.MaxDailyTransfers),
		MonthlyTransferred:   limit.TotalSentCentinels,
		Remaining:            int64(s.cfg.MaxDailyTransfers - limit.TransfersCount),
		NextReset:            nextReset,
		DailyAccrualClaimed:  dailyClaimed,
		NextAccrual:          nextAccrual,
	}, nil
}

func (s *service) GetReferralStats(ctx context.Context, userID string) (*ReferralStatsResponse, error) {
	referrals, err := s.repo.GetReferralsByReferrer(ctx, userID)
	if err != nil {
		return nil, WrapErrorf(err, "failed to get referrals")
	}

	activeCount := 0
	for _, ref := range referrals {
		if ref.IsActive {
			activeCount++
		}
	}

	totalEarned := float64(len(referrals)) * s.cfg.ReferralBonusSeals

	referralList := make([]Referral, len(referrals))
	for i, ref := range referrals {
		referralList[i] = *ref
	}

	return &ReferralStatsResponse{
		TotalReferrals:  len(referrals),
		ActiveReferrals: activeCount,
		TotalEarned:     totalEarned,
		Referrals:       referralList,
	}, nil
}

func (s *service) GetViolationLogs(ctx context.Context, userID string, limit, offset int) ([]*ViolationLog, int, error) {
	violations, total, err := s.repo.GetViolationLogs(ctx, userID, limit, offset)
	if err != nil {
		return nil, 0, WrapErrorf(err, "failed to get violation logs")
	}

	return violations, total, nil
}

func (s *service) ProcessIAPDeposit(ctx context.Context, userID string, amountCentinels int64, currency CurrencyCode, receiptID string) error {
	if amountCentinels <= 0 {
		return NewInvalidAmountError(CentinelsToSeals(amountCentinels))
	}

	if !currency.IsValid() {
		return NewInvalidCurrencyError(string(currency))
	}

	err := s.executeWithRetry(ctx, func() error {
		tx, err := s.repo.BeginTx(ctx)
		if err != nil {
			return WrapErrorf(err, "failed to begin transaction")
		}
		defer tx.Rollback()

		txRepo := s.repo.WithTx(tx)

		wallet, err := txRepo.GetOrCreateWallet(ctx, userID, currency)
		if err != nil {
			return WrapErrorf(err, "failed to get wallet")
		}

		if existing, err := txRepo.GetLedgerEntryByReferenceID(ctx, receiptID); err == nil && existing != nil {
			return nil
		}

		wallet.Balance += amountCentinels

		if err := txRepo.UpdateWalletWithVersion(ctx, wallet, wallet.Version); err != nil {
			return err
		}

		entry := &LedgerEntry{
			ID:               uuid.New().String(),
			Amount:           amountCentinels,
			Currency:         currency,
			ReceiverWalletID: &wallet.ID,
			Category:         CategoryIAPDeposit,
			ReferenceID:      receiptID,
			Metadata:         mustMarshalJSON(map[string]interface{}{"receipt_id": receiptID}),
			CreatedAt:        time.Now(),
		}

		if err := txRepo.CreateLedgerEntry(ctx, entry); err != nil {
			return WrapErrorf(err, "failed to create ledger entry")
		}

		if err := tx.Commit(); err != nil {
			return WrapErrorf(err, "failed to commit transaction")
		}

		// Invalidate stats cache for user (fire-and-forget)
		_ = s.cacheInvalidator.InvalidateStats(ctx, userID)

		return nil
	})

	return err
}

func (s *service) ChargeForTaskCreation(ctx context.Context, userID, taskID string, cost int64) error {
	if cost <= 0 {
		return NewInvalidAmountError(CentinelsToSeals(cost))
	}

	err := s.executeWithRetry(ctx, func() error {
		tx, err := s.repo.BeginTx(ctx)
		if err != nil {
			return WrapErrorf(err, "failed to begin transaction")
		}
		defer tx.Rollback()

		txRepo := s.repo.WithTx(tx)

		wallet, err := txRepo.GetWallet(ctx, userID, CurrencySilverSeal)
		if err != nil {
			return WrapErrorf(err, "failed to get wallet")
		}

		referenceID := fmt.Sprintf("task_create_%s", taskID)
		if existing, err := txRepo.GetLedgerEntryByReferenceID(ctx, referenceID); err == nil && existing != nil {
			return nil
		}

		if !wallet.HasSufficientBalance(cost) {
			return NewInsufficientFundsError(userID, CurrencySilverSeal, cost, wallet.Balance)
		}

		wallet.Balance -= cost
		if wallet.FreeBalance > 0 {
			deductFromFree := min(wallet.FreeBalance, cost)
			wallet.FreeBalance -= deductFromFree
		}

		if err := txRepo.UpdateWalletWithVersion(ctx, wallet, wallet.Version); err != nil {
			return err
		}

		entry := &LedgerEntry{
			ID:             uuid.New().String(),
			Amount:         cost,
			Currency:       CurrencySilverSeal,
			SenderWalletID: &wallet.ID,
			Category:       CategoryTaskCreation,
			ReferenceID:    referenceID,
			Metadata:       mustMarshalJSON(map[string]interface{}{"task_id": taskID}),
			CreatedAt:      time.Now(),
		}

		if err := txRepo.CreateLedgerEntry(ctx, entry); err != nil {
			return WrapErrorf(err, "failed to create ledger entry")
		}

		if err := tx.Commit(); err != nil {
			return WrapErrorf(err, "failed to commit transaction")
		}

		// Invalidate stats cache for user (fire-and-forget)
		_ = s.cacheInvalidator.InvalidateStats(ctx, userID)

		return nil
	})

	return err
}

func (s *service) RewardForTaskCompletion(ctx context.Context, userID, taskID string, reward int64) error {
	if reward <= 0 {
		return NewInvalidAmountError(CentinelsToSeals(reward))
	}

	err := s.executeWithRetry(ctx, func() error {
		tx, err := s.repo.BeginTx(ctx)
		if err != nil {
			return WrapErrorf(err, "failed to begin transaction")
		}
		defer tx.Rollback()

		txRepo := s.repo.WithTx(tx)

		wallet, err := txRepo.GetOrCreateWallet(ctx, userID, CurrencySilverSeal)
		if err != nil {
			return WrapErrorf(err, "failed to get wallet")
		}

		referenceID := fmt.Sprintf("task_reward_%s", taskID)
		if existing, err := txRepo.GetLedgerEntryByReferenceID(ctx, referenceID); err == nil && existing != nil {
			return nil
		}

		wallet.Balance += reward

		if err := txRepo.UpdateWalletWithVersion(ctx, wallet, wallet.Version); err != nil {
			return err
		}

		entry := &LedgerEntry{
			ID:               uuid.New().String(),
			Amount:           reward,
			Currency:         CurrencySilverSeal,
			ReceiverWalletID: &wallet.ID,
			Category:         CategoryTaskReward,
			ReferenceID:      referenceID,
			Metadata:         mustMarshalJSON(map[string]interface{}{"task_id": taskID}),
			CreatedAt:        time.Now(),
		}

		if err := txRepo.CreateLedgerEntry(ctx, entry); err != nil {
			return WrapErrorf(err, "failed to create ledger entry")
		}

		if err := tx.Commit(); err != nil {
			return WrapErrorf(err, "failed to commit transaction")
		}

		// Invalidate stats cache for user (fire-and-forget)
		_ = s.cacheInvalidator.InvalidateStats(ctx, userID)

		return nil
	})

	return err
}

func (s *service) AdminAdjustBalance(ctx context.Context, userID string, amountCentinels int64, currency CurrencyCode, reason string) error {
	if !currency.IsValid() {
		return NewInvalidCurrencyError(string(currency))
	}

	tx, err := s.repo.BeginTx(ctx)
	if err != nil {
		return WrapErrorf(err, "failed to begin transaction")
	}
	defer tx.Rollback()

	txRepo := s.repo.WithTx(tx)

	wallet, err := txRepo.GetOrCreateWallet(ctx, userID, currency)
	if err != nil {
		return WrapErrorf(err, "failed to get wallet")
	}

	if amountCentinels < 0 && wallet.Balance < -amountCentinels {
		return ErrNegativeBalance
	}

	referenceID := fmt.Sprintf("admin_adjust_%s_%d", userID, time.Now().Unix())
	if existing, err := txRepo.GetLedgerEntryByReferenceID(ctx, referenceID); err == nil && existing != nil {
		return nil
	}

	wallet.Balance += amountCentinels

	if err := txRepo.UpdateWalletWithVersion(ctx, wallet, wallet.Version); err != nil {
		return WrapErrorf(err, "failed to update wallet")
	}

	var senderWalletID, receiverWalletID *string
	if amountCentinels > 0 {
		receiverWalletID = &wallet.ID
	} else {
		senderWalletID = &wallet.ID
		amountCentinels = -amountCentinels
	}

	entry := &LedgerEntry{
		ID:               uuid.New().String(),
		Amount:           amountCentinels,
		Currency:         currency,
		SenderWalletID:   senderWalletID,
		ReceiverWalletID: receiverWalletID,
		Category:         CategorySystemCorrection,
		ReferenceID:      referenceID,
		Metadata:         mustMarshalJSON(map[string]interface{}{"reason": reason}),
		CreatedAt:        time.Now(),
	}

	if err := txRepo.CreateLedgerEntry(ctx, entry); err != nil {
		return WrapErrorf(err, "failed to create ledger entry")
	}

	if err := tx.Commit(); err != nil {
		return WrapErrorf(err, "failed to commit transaction")
	}

	// Invalidate stats cache for user (fire-and-forget)
	_ = s.cacheInvalidator.InvalidateStats(ctx, userID)

	return nil
}

func min(a, b int64) int64 {
	if a < b {
		return a
	}
	return b
}

// mustMarshalJSON marshals a value to JSON, panicking on error.
// This is safe for metadata fields that are simple key-value pairs.
func mustMarshalJSON(v interface{}) json.RawMessage {
	b, err := json.Marshal(v)
	if err != nil {
		// This should never happen for simple maps
		panic(fmt.Sprintf("failed to marshal JSON: %v", err))
	}
	return b
}

func (s *service) logViolation(ctx context.Context, userID string, violationType ViolationType, endpoint string, amountAttempted *int64, details map[string]interface{}) {
	violation := &ViolationLog{
		ID:              uuid.New().String(),
		UserID:          userID,
		ViolationType:   violationType,
		AmountAttempted: amountAttempted,
		Details:         mustMarshalJSON(details),
		Endpoint:        StringPtr(endpoint),
		CreatedAt:       time.Now(),
	}

	_ = s.repo.CreateViolationLog(ctx, violation)
}

func (s *service) processSealTransfer(ctx context.Context, senderID, receiverID string, amount int64, currency CurrencyCode, category TransactionCategory, refID string, metadata map[string]interface{}) (*TransferResponse, error) {
	if amount != CentinelsPerSeal {
		return nil, NewValidationError("amount", "seal transfer must be exactly 1 seal")
	}

	if senderID == receiverID {
		return nil, NewSelfTransferError()
	}

	var response *TransferResponse
	err := s.executeWithRetry(ctx, func() error {
		tx, err := s.repo.BeginTx(ctx)
		if err != nil {
			return WrapErrorf(err, "failed to begin transaction")
		}
		defer tx.Rollback()

		txRepo := s.repo.WithTx(tx)

		// 1. Check/Update Cooldown
		cooldown, err := txRepo.GetPairCooldown(ctx, senderID, receiverID)
		if err != nil {
			return WrapErrorf(err, "failed to get pair cooldown")
		}

		now := time.Now()
		repeatLevel := 1

		if cooldown != nil {
			if now.Before(cooldown.NextAllowedAt) {
				return NewCooldownError(cooldown.LastGrantAt, cooldown.NextAllowedAt.Sub(cooldown.LastGrantAt), cooldown.RepeatLevel)
			}

			diff := now.Sub(cooldown.LastGrantAt)
			repeatLevel = cooldown.RepeatLevel

			threshold1 := time.Duration(s.cfg.SealDecayThreshold1Days) * 24 * time.Hour
			threshold2 := time.Duration(s.cfg.SealDecayThreshold2Days) * 24 * time.Hour

			if diff >= threshold2 {
				repeatLevel = max(repeatLevel-2, 1)
			} else if diff >= threshold1 {
				repeatLevel = max(repeatLevel-1, 1)
			}
		}

		// 2. Check Balances
		wallet, err := txRepo.GetOrCreateWallet(ctx, senderID, currency)
		if err != nil {
			return WrapErrorf(err, "failed to get wallet")
		}

		if !wallet.HasSufficientBalance(amount) {
			return NewInsufficientFundsError(senderID, currency, amount, wallet.Balance)
		}

		// 3. Check Idempotency
		if existing, err := txRepo.GetLedgerEntryByReferenceID(ctx, refID); err == nil && existing != nil {
			// Strict check: parameters must match exactly
			match := existing.Amount == amount && existing.Currency == currency

			// Check Sender Wallet
			if existing.SenderWalletID == nil || *existing.SenderWalletID != wallet.ID {
				match = false
			}

			// Check Receiver Wallet if applicable
			if receiverID != "" {
				receiverWallet, _ := txRepo.GetOrCreateWallet(ctx, receiverID, currency)
				fmt.Printf("[IDEMPOTENCY] Checking Receiver: existing=%v, current=%s\n", existing.ReceiverWalletID, receiverWallet.ID)
				if existing.ReceiverWalletID == nil || *existing.ReceiverWalletID != receiverWallet.ID {
					match = false
				}
			} else if existing.ReceiverWalletID != nil {
				match = false
			}

			fmt.Printf("[IDEMPOTENCY] Final Match Result: %v\n", match)
			if !match {
				return ErrIdempotencyConflict
			}

			response = &TransferResponse{
				LedgerEntryID: existing.ID,
				SenderBalance: CentinelsToSeals(wallet.Balance),
				Timestamp:     existing.CreatedAt,
			}
			return nil
		}

		// 4. Update Wallet
		wallet.Balance -= amount
		if currency == CurrencySilverSeal && wallet.FreeBalance > 0 {
			deductFromFree := min(wallet.FreeBalance, amount)
			wallet.FreeBalance -= deductFromFree
		}

		if err := txRepo.UpdateWalletWithVersion(ctx, wallet, wallet.Version); err != nil {
			return err
		}

		if category == CategoryP2PTransfer {
			// For P2P, we also update receiver wallet
			receiverWallet, err := txRepo.GetOrCreateWallet(ctx, receiverID, currency)
			if err != nil {
				return WrapErrorf(err, "failed to get receiver wallet")
			}
			receiverWallet.Balance += amount
			if err := txRepo.UpdateWalletWithVersion(ctx, receiverWallet, receiverWallet.Version); err != nil {
				return err
			}

			// For response
			response = &TransferResponse{
				ReceiverBalance: CentinelsToSeals(receiverWallet.Balance),
			}
		}

		// 5. Create Ledger Entry
		entry := &LedgerEntry{
			ID:             uuid.New().String(),
			Amount:         amount,
			Currency:       currency,
			SenderWalletID: &wallet.ID,
			Category:       category,
			ReferenceID:    refID,
			Metadata:       mustMarshalJSON(metadata),
			CreatedAt:      now,
		}

		if category != CategoryP2PTransfer {

			receiverWallet, err := txRepo.GetOrCreateWallet(ctx, receiverID, currency)
			if err != nil {
				return WrapErrorf(err, "failed to get receiver wallet")
			}
			receiverWallet.Balance += amount
			if err := txRepo.UpdateWalletWithVersion(ctx, receiverWallet, receiverWallet.Version); err != nil {
				return err
			}
			entry.ReceiverWalletID = &receiverWallet.ID

			if response == nil {
				response = &TransferResponse{}
			}
			response.ReceiverBalance = CentinelsToSeals(receiverWallet.Balance)
		} else {

		}

		if err := txRepo.CreateLedgerEntry(ctx, entry); err != nil {
			return WrapErrorf(err, "failed to create ledger entry")
		}

		duration := s.getCooldownDuration(repeatLevel)
		newLevel := repeatLevel + 1
		if newLevel > 5 {
			newLevel = 5
		}

		newCooldown := &PairCooldown{
			SenderUserID:   senderID,
			ReceiverUserID: receiverID,
			RepeatLevel:    newLevel,
			LastGrantAt:    now,
			NextAllowedAt:  now.Add(duration),
		}

		if err := txRepo.UpsertPairCooldown(ctx, newCooldown); err != nil {
			return WrapErrorf(err, "failed to update cooldown")
		}

		if err := tx.Commit(); err != nil {
			return WrapErrorf(err, "failed to commit transaction")
		}

		_ = s.cacheInvalidator.InvalidateStats(ctx, senderID)
		if category == CategoryP2PTransfer && receiverID != "" {
			_ = s.cacheInvalidator.InvalidateStats(ctx, receiverID)
		}

		if response == nil {
			response = &TransferResponse{}
		}
		response.SenderBalance = CentinelsToSeals(wallet.Balance)
		response.LedgerEntryID = entry.ID
		response.Timestamp = entry.CreatedAt

		return nil
	})

	return response, err
}

func (s *service) getCooldownDuration(level int) time.Duration {
	switch level {
	case 1:
		return time.Duration(s.cfg.SealCooldownLevel1Days) * 24 * time.Hour
	case 2:
		return time.Duration(s.cfg.SealCooldownLevel2Days) * 24 * time.Hour
	case 3:
		return time.Duration(s.cfg.SealCooldownLevel3Days) * 24 * time.Hour
	case 4:
		return time.Duration(s.cfg.SealCooldownLevel4Days) * 24 * time.Hour
	case 5:
		return time.Duration(s.cfg.SealCooldownLevel5Days) * 24 * time.Hour
	default:
		return time.Duration(s.cfg.SealCooldownLevel5Days) * 24 * time.Hour
	}
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
