package economy

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/brightbund-backend/internal/modules/ranks"
	"github.com/google/uuid"

	"github.com/brightbund-backend/internal/config"
	"github.com/brightbund-backend/internal/platform/eventbus"
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
	RegisterPendingReferral(ctx context.Context, referrerUserID, refereeUserID string) error
	ActivateDeferredReferral(ctx context.Context, refereeUserID string) error
	GrantSignupBonus(ctx context.Context, userID string) error

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
	eventBus         *eventbus.Producer
}

func NewService(repo Repository, cfg config.EconomyConfig, cacheInvalidator StatsCacheInvalidator, eventBus *eventbus.Producer) Service {
	// Use no-op invalidator if none provided
	if cacheInvalidator == nil {
		cacheInvalidator = &NoopCacheInvalidator{}
	}
	return &service{
		repo:             repo,
		cfg:              cfg,
		cacheInvalidator: cacheInvalidator,
		eventBus:         eventBus,
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

func (s *service) ensureUserActivated(ctx context.Context, userID string) error {
	status, restrictionsUntil, err := s.repo.GetUserActivationState(ctx, userID)
	if err != nil {
		return WrapErrorf(err, "failed to get user activation state")
	}

	now := time.Now()
	if isActivationEligible(status, restrictionsUntil, now) {
		return nil
	}

	if restrictionsUntil != nil && restrictionsUntil.Valid && restrictionsUntil.Time.After(now) {
		return NewCooldownError(now, restrictionsUntil.Time.Sub(now), 0)
	}

	return NewCooldownError(now, 24*time.Hour, 0)
}

func (s *service) isUserActivationEligible(ctx context.Context, userID string) (bool, error) {
	status, restrictionsUntil, err := s.repo.GetUserActivationState(ctx, userID)
	if err != nil {
		return false, WrapErrorf(err, "failed to get user activation state")
	}

	return isActivationEligible(status, restrictionsUntil, time.Now()), nil
}

func isActivationEligible(status string, restrictionsUntil *sql.NullTime, now time.Time) bool {
	if status != "active" {
		return false
	}

	if restrictionsUntil != nil && restrictionsUntil.Valid && restrictionsUntil.Time.After(now) {
		return false
	}

	return true
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
	if err := s.ensureUserActivated(ctx, senderUserID); err != nil {
		return nil, err
	}

	if req.Amount <= 0 {
		return nil, NewInvalidAmountError(req.Amount)
	}

	currency := CurrencyCode(req.Currency)
	if !currency.IsValid() {
		return nil, NewInvalidCurrencyError(req.Currency)
	}
	if currency != CurrencySilverSeal {
		return nil, NewValidationError("currency", "only SILVER_SEAL can be sent; receiver gains GOLD_SEAL")
	}

	if senderUserID == req.RecipientUserID {
		return nil, NewSelfTransferError()
	}

	amountCents := SealsToCentinels(req.Amount)
	isSeal := true

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

		// Early idempotency gate — short-circuit before cooldown/balance checks
		// so that a re-tap with the same key never hits the cooldown guard.
		if req.IdempotencyKey != "" {
			debitRef := req.IdempotencyKey + ":silver_debit"
			creditRef := req.IdempotencyKey + ":gold_credit"
			debitExisting, debitErr := txRepo.GetLedgerEntryByReferenceID(ctx, debitRef)
			creditExisting, creditErr := txRepo.GetLedgerEntryByReferenceID(ctx, creditRef)
			if debitErr == nil && debitExisting != nil && creditErr == nil && creditExisting != nil {
				senderWallet, _ := txRepo.GetOrCreateWallet(ctx, senderUserID, CurrencySilverSeal)
				receiverWallet, _ := txRepo.GetOrCreateWallet(ctx, req.RecipientUserID, CurrencyGoldSeal)
				response = &TransferResponse{
					LedgerEntryID:   creditExisting.ID,
					SenderBalance:   CentinelsToSeals(senderWallet.Balance),
					ReceiverBalance: CentinelsToSeals(receiverWallet.Balance),
					CreatedNew:      false,
					Timestamp:       creditExisting.CreatedAt,
				}
				return nil
			}
			if (debitErr == nil && debitExisting != nil) || (creditErr == nil && creditExisting != nil) {
				return ErrIdempotencyConflict
			}
		}

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

				decayed := false
				if diff >= threshold2 {
					repeatLevel = max(repeatLevel-2, 1)
					decayed = true
				} else if diff >= threshold1 {
					repeatLevel = max(repeatLevel-1, 1)
					decayed = true
				}

				if !decayed && repeatLevel < 5 {
					repeatLevel++
				}
			}

			// Update values in context to use later when upserting cooldown
			ctx = context.WithValue(ctx, "seal_repeat_level", repeatLevel)
		}

		monthYear := FormatMonthYear(time.Now())
		limit, err := txRepo.GetOrCreateTransferLimit(ctx, senderUserID, monthYear)
		if err != nil {
			return WrapErrorf(err, "failed to get transfer limit")
		}

		if !limit.CanTransfer(s.cfg.MaxDailyTransfers) {
			// TODO: Extract client IP from context and pass as last parameter to logViolation
			// See: backend/internal/platform/geolocation/ip_extractor.go for IP extraction utilities
			s.logViolation(ctx, senderUserID, ViolationMonthlyLimitExceeded, "/economy/transfer", &amountCents, map[string]interface{}{
				"recipient_id":  req.RecipientUserID,
				"current_count": limit.TransfersCount,
				"limit":         s.cfg.MaxDailyTransfers,
			}, nil) // IP address should be extracted from handler request context
			return NewMonthlyLimitError(senderUserID, req.RecipientUserID, currency,
				int64(s.cfg.MaxDailyTransfers), int64(limit.TransfersCount), amountCents)
		}

		senderWallet, err := txRepo.GetOrCreateWallet(ctx, senderUserID, CurrencySilverSeal)
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
				}, nil) // IP address should be extracted from handler request context
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
					}, nil) // IP address should be extracted from handler request context
				}
			}
		}

		if !senderWallet.HasSufficientBalance(amountCents) {
			s.logViolation(ctx, senderUserID, ViolationInsufficientFundsAttempt, "/economy/transfer", &amountCents, map[string]interface{}{
				"recipient_id": req.RecipientUserID,
				"available":    senderWallet.Balance,
				"required":     amountCents,
			}, nil) // IP address should be extracted from handler request context
			return NewInsufficientFundsError(senderUserID, currency, amountCents, senderWallet.Balance)
		}

		receiverWallet, err := txRepo.GetOrCreateWallet(ctx, req.RecipientUserID, CurrencyGoldSeal)
		if err != nil {
			return WrapErrorf(err, "failed to get receiver wallet")
		}

		referenceID := req.IdempotencyKey
		if referenceID == "" {
			referenceID = fmt.Sprintf("transfer_%s_%s_%d", senderUserID, req.RecipientUserID, time.Now().Unix())
		}
		debitRef := referenceID + ":silver_debit"
		creditRef := referenceID + ":gold_credit"

		debitExisting, debitErr := txRepo.GetLedgerEntryByReferenceID(ctx, debitRef)
		creditExisting, creditErr := txRepo.GetLedgerEntryByReferenceID(ctx, creditRef)
		if debitErr == nil && debitExisting != nil && creditErr == nil && creditExisting != nil {
			response = &TransferResponse{
				LedgerEntryID:   creditExisting.ID,
				SenderBalance:   CentinelsToSeals(senderWallet.Balance),
				ReceiverBalance: CentinelsToSeals(receiverWallet.Balance),
				CreatedNew:      false,
				Timestamp:       creditExisting.CreatedAt,
			}
			return nil
		}
		if (debitErr == nil && debitExisting != nil) || (creditErr == nil && creditExisting != nil) {
			return ErrIdempotencyConflict
		}

		senderWallet.Balance -= amountCents
		senderWallet.TotalSentAmount += amountCents
		if senderWallet.FreeBalance > 0 {
			deductFromFree := min(senderWallet.FreeBalance, amountCents)
			senderWallet.FreeBalance -= deductFromFree
		}
		now := time.Now()
		senderWallet.LastTransferAt = &now

		if err := txRepo.UpdateWalletWithVersion(ctx, senderWallet, senderWallet.Version); err != nil {
			return err // Can be ErrOptimisticLockFailure
		}

		// Use optimistic locking for receiver as well to prevent race conditions
		newRBalance, err := txRepo.IncrementWalletBalanceAtomic(ctx, receiverWallet.ID, amountCents)
		if err != nil {
			return err
		}
		receiverWallet.Balance = newRBalance

		debitEntry := &LedgerEntry{
			ID:             uuid.New().String(),
			Amount:         amountCents,
			Currency:       CurrencySilverSeal,
			SenderWalletID: &senderWallet.ID,
			Category:       CategoryP2PTransfer,
			ReferenceID:    debitRef,
			Metadata:       mustMarshalJSON(map[string]interface{}{"reason": req.Reason, "receiver_user_id": req.RecipientUserID, "conversion": "silver_to_gold"}),
			CreatedAt:      time.Now(),
		}

		if err := txRepo.CreateLedgerEntry(ctx, debitEntry); err != nil {
			return WrapErrorf(err, "failed to create debit ledger entry")
		}

		creditEntry := &LedgerEntry{
			ID:               uuid.New().String(),
			Amount:           amountCents,
			Currency:         CurrencyGoldSeal,
			ReceiverWalletID: &receiverWallet.ID,
			Category:         CategoryP2PTransfer,
			ReferenceID:      creditRef,
			Metadata:         mustMarshalJSON(map[string]interface{}{"reason": req.Reason, "sender_user_id": senderUserID, "conversion": "silver_to_gold"}),
			CreatedAt:        debitEntry.CreatedAt,
		}

		if err := txRepo.CreateLedgerEntry(ctx, creditEntry); err != nil {
			return WrapErrorf(err, "failed to create credit ledger entry")
		}

		if err := txRepo.UpsertGoldPeriodStat(ctx, req.RecipientUserID, debitEntry.CreatedAt.Year(), isoWeek(debitEntry.CreatedAt), amountCents); err != nil {
			return WrapErrorf(err, "failed to upsert gold period stat")
		}

		receiverRankTier := ranks.GetRankTierString(int(receiverWallet.Balance / CentinelsPerSeal))
		if err := txRepo.UpsertProfileSealProjection(ctx, senderUserID, req.RecipientUserID, amountCents/CentinelsPerSeal, receiverWallet.Balance, receiverRankTier); err != nil {
			return WrapErrorf(err, "failed to upsert profile seal projection")
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

				newCooldown := &PairCooldown{
					SenderUserID:   senderUserID,
					ReceiverUserID: req.RecipientUserID,
					RepeatLevel:    rl,
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
			LedgerEntryID:   creditEntry.ID,
			SenderBalance:   CentinelsToSeals(senderWallet.Balance),
			ReceiverBalance: CentinelsToSeals(receiverWallet.Balance),
			CreatedNew:      true,
			Timestamp:       creditEntry.CreatedAt,
		}
		return nil
	})

	return response, err
}

func (s *service) GiveSealToPost(ctx context.Context, userID, postID string, req *GiveSealToPostRequest) (*TransferResponse, error) {
	if err := s.ensureUserActivated(ctx, userID); err != nil {
		return nil, err
	}

	currency := CurrencyCode(req.Currency)
	if !currency.IsValid() {
		return nil, NewInvalidCurrencyError(req.Currency)
	}
	if currency != CurrencySilverSeal {
		return nil, NewValidationError("currency", "only SILVER_SEAL can be sent; receiver gains GOLD_SEAL")
	}

	metadata := map[string]interface{}{
		"post_id": postID,
		"context": "post_seal",
	}
	if comment := strings.TrimSpace(req.Comment); comment != "" {
		metadata["comment"] = comment
	}

	return s.processSealTransfer(ctx, userID, req.ReceiverUserID, req.Amount*CentinelsPerSeal, CurrencySilverSeal, CurrencyGoldSeal, CategoryPostSeal, req.IdempotencyKey, metadata)
}

func (s *service) GiveSealToUser(ctx context.Context, fromUserID, toUserID string, req *GiveSealToUserRequest) (*TransferResponse, error) {
	if err := s.ensureUserActivated(ctx, fromUserID); err != nil {
		return nil, err
	}

	currency := CurrencyCode(req.Currency)
	if !currency.IsValid() {
		return nil, NewInvalidCurrencyError(req.Currency)
	}
	if currency != CurrencySilverSeal {
		return nil, NewValidationError("currency", "only SILVER_SEAL can be sent; receiver gains GOLD_SEAL")
	}

	metadata := map[string]interface{}{
		"message": StringOrEmpty(req.Message),
		"context": "user_seal",
	}

	amountCents := SealsToCentinels(req.Amount)

	return s.processSealTransfer(ctx, fromUserID, toUserID, amountCents, CurrencySilverSeal, CurrencyGoldSeal, CategoryP2PTransfer, req.IdempotencyKey, metadata)
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
		// Normalize "transfer" to P2P_TRANSFER
		if strings.ToLower(string(cat)) == "transfer" {
			cat = CategoryP2PTransfer
		}
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
	if err := s.ensureUserActivated(ctx, userID); err != nil {
		return nil, err
	}

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
			}, nil) // IP address should be extracted from handler request context
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
		if existing.IsActive {
			return NewReferralExistsError()
		}

		canActivateNow, err := s.isUserActivationEligible(ctx, refereeUserID)
		if err != nil {
			return err
		}
		if !canActivateNow {
			return nil
		}

		return s.ActivateDeferredReferral(ctx, refereeUserID)
	}

	canActivateNow, err := s.isUserActivationEligible(ctx, refereeUserID)
	if err != nil {
		return err
	}
	if !canActivateNow {
		return s.RegisterPendingReferral(ctx, referrerUserID, refereeUserID)
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

func (s *service) RegisterPendingReferral(ctx context.Context, referrerUserID, refereeUserID string) error {
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

	referral := &Referral{
		ID:             uuid.New().String(),
		ReferrerUserID: referrerUserID,
		RefereeUserID:  refereeUserID,
		IsActive:       false,
		CreatedAt:      time.Now(),
	}

	if err := s.repo.CreateReferral(ctx, referral); err != nil {
		return WrapErrorf(err, "failed to create pending referral")
	}

	return nil
}

func (s *service) ActivateDeferredReferral(ctx context.Context, refereeUserID string) error {
	referral, err := s.repo.GetReferralByReferee(ctx, refereeUserID)
	if err == ErrReferralNotFound {
		return nil
	}
	if err != nil {
		return WrapErrorf(err, "failed to fetch referral")
	}
	if referral.IsActive {
		return nil
	}

	canActivateNow, err := s.isUserActivationEligible(ctx, refereeUserID)
	if err != nil {
		return err
	}
	if !canActivateNow {
		return nil
	}

	return s.executeWithRetry(ctx, func() error {
		tx, err := s.repo.BeginTx(ctx)
		if err != nil {
			return WrapErrorf(err, "failed to begin transaction")
		}
		defer tx.Rollback()

		txRepo := s.repo.WithTx(tx)
		wallet, err := txRepo.GetOrCreateWallet(ctx, referral.ReferrerUserID, CurrencySilverSeal)
		if err != nil {
			return WrapErrorf(err, "failed to get referrer wallet")
		}

		wallet.Balance += s.cfg.ReferralBonusCents
		if err := txRepo.UpdateWalletWithVersion(ctx, wallet, wallet.Version); err != nil {
			return err
		}

		referenceID := fmt.Sprintf("referral_%s_%s", referral.ReferrerUserID, refereeUserID)
		if existingEntry, err := txRepo.GetLedgerEntryByReferenceID(ctx, referenceID); err == nil && existingEntry != nil {
			if err := txRepo.ActivateReferral(ctx, refereeUserID, existingEntry.ID); err != nil {
				return err
			}
			if err := tx.Commit(); err != nil {
				return WrapErrorf(err, "failed to commit transaction")
			}
			return nil
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

		if err := txRepo.ActivateReferral(ctx, refereeUserID, entry.ID); err != nil {
			return err
		}

		if err := tx.Commit(); err != nil {
			return WrapErrorf(err, "failed to commit transaction")
		}

		_ = s.cacheInvalidator.InvalidateStats(ctx, referral.ReferrerUserID)
		return nil
	})
}

func (s *service) GrantSignupBonus(ctx context.Context, userID string) error {
	amount := int64(CentinelsPerSeal)
	referenceID := fmt.Sprintf("signup_bonus_%s", userID)

	return s.executeWithRetry(ctx, func() error {
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

		if existing, err := txRepo.GetLedgerEntryByReferenceID(ctx, referenceID); err == nil && existing != nil {
			return nil
		}

		wallet.Balance += amount
		if wallet.FreeBalance < s.cfg.MaxFreeSilverBalance {
			addFree := min(amount, s.cfg.MaxFreeSilverBalance-wallet.FreeBalance)
			wallet.FreeBalance += addFree
		}

		if err := txRepo.UpdateWalletWithVersion(ctx, wallet, wallet.Version); err != nil {
			return err
		}

		entry := &LedgerEntry{
			ID:               uuid.New().String(),
			Amount:           amount,
			Currency:         CurrencySilverSeal,
			ReceiverWalletID: &wallet.ID,
			Category:         CategorySignupBonus,
			ReferenceID:      referenceID,
			Metadata:         mustMarshalJSON(map[string]interface{}{"user_id": userID}),
			CreatedAt:        time.Now(),
		}

		if err := txRepo.CreateLedgerEntry(ctx, entry); err != nil {
			return WrapErrorf(err, "failed to create ledger entry")
		}

		if err := tx.Commit(); err != nil {
			return WrapErrorf(err, "failed to commit transaction")
		}

		_ = s.cacheInvalidator.InvalidateStats(ctx, userID)
		return nil
	})
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
	if currency == CurrencyGoldSeal {
		return NewValidationError("currency", "direct GOLD_SEAL purchase is disabled")
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

		if err := ChargeForTaskCreationTx(ctx, txRepo, userID, taskID, cost); err != nil {
			return err
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

// ChargeForTaskCreationTx charges the user for task creation within an existing transaction.
// The passed repo MUST be bound to the current transaction.
func ChargeForTaskCreationTx(ctx context.Context, repo Repository, userID, taskID string, cost int64) error {
	if cost <= 0 {
		return NewInvalidAmountError(CentinelsToSeals(cost))
	}

	wallet, err := repo.GetOrCreateWallet(ctx, userID, CurrencySilverSeal)
	if err != nil {
		return WrapErrorf(err, "failed to get wallet")
	}

	referenceID := fmt.Sprintf("task_create_%s", taskID)
	if existing, err := repo.GetLedgerEntryByReferenceID(ctx, referenceID); err == nil && existing != nil {
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

	if err := repo.UpdateWalletWithVersion(ctx, wallet, wallet.Version); err != nil {
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

	if err := repo.CreateLedgerEntry(ctx, entry); err != nil {
		return WrapErrorf(err, "failed to create ledger entry")
	}

	return nil
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

		if err := RewardForTaskCompletionTx(ctx, txRepo, userID, taskID, reward); err != nil {
			return err
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

// RewardForTaskCompletionTx credits the user for completing a task within an existing transaction.
// The passed repo MUST be bound to the current transaction.
func RewardForTaskCompletionTx(ctx context.Context, repo Repository, userID, taskID string, reward int64) error {
	if reward <= 0 {
		return NewInvalidAmountError(CentinelsToSeals(reward))
	}

	wallet, err := repo.GetOrCreateWallet(ctx, userID, CurrencySilverSeal)
	if err != nil {
		return WrapErrorf(err, "failed to get wallet")
	}

	referenceID := fmt.Sprintf("task_reward_%s", taskID)
	if existing, err := repo.GetLedgerEntryByReferenceID(ctx, referenceID); err == nil && existing != nil {
		return nil
	}

	wallet.Balance += reward

	if err := repo.UpdateWalletWithVersion(ctx, wallet, wallet.Version); err != nil {
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

	if err := repo.CreateLedgerEntry(ctx, entry); err != nil {
		return WrapErrorf(err, "failed to create ledger entry")
	}

	return nil
}

// RefundTaskCreationTx refunds the task-creation charge back to the creator.
// Must be called within an existing transaction. Idempotent via reference ID.
func RefundTaskCreationTx(ctx context.Context, repo Repository, userID, taskID string, amount int64) error {
	if amount <= 0 {
		return NewInvalidAmountError(CentinelsToSeals(amount))
	}

	referenceID := fmt.Sprintf("task_refund_%s", taskID)
	if existing, err := repo.GetLedgerEntryByReferenceID(ctx, referenceID); err == nil && existing != nil {
		return nil // already refunded
	}

	wallet, err := repo.GetWallet(ctx, userID, CurrencySilverSeal)
	if err != nil {
		return WrapErrorf(err, "failed to get wallet for refund")
	}

	wallet.Balance += amount

	if err := repo.UpdateWalletWithVersion(ctx, wallet, wallet.Version); err != nil {
		return err
	}

	entry := &LedgerEntry{
		ID:               uuid.New().String(),
		Amount:           amount,
		Currency:         CurrencySilverSeal,
		ReceiverWalletID: &wallet.ID,
		Category:         CategoryTaskRefund,
		ReferenceID:      referenceID,
		Metadata:         mustMarshalJSON(map[string]interface{}{"task_id": taskID}),
		CreatedAt:        time.Now(),
	}

	if err := repo.CreateLedgerEntry(ctx, entry); err != nil {
		return WrapErrorf(err, "failed to create refund ledger entry")
	}

	return nil
}

// RewardForApplicationConfirmationTx credits a helper for completing a task application.
// Uses applicationID as part of the idempotency key so each worker in a multi-worker
// task receives their individual reward correctly.
func RewardForApplicationConfirmationTx(ctx context.Context, repo Repository, workerUserID, taskID, applicationID string, reward int64) error {
	if reward <= 0 {
		return NewInvalidAmountError(CentinelsToSeals(reward))
	}

	referenceID := fmt.Sprintf("task_reward_%s_%s", taskID, applicationID)
	if existing, err := repo.GetLedgerEntryByReferenceID(ctx, referenceID); err == nil && existing != nil {
		return nil // already rewarded
	}

	wallet, err := repo.GetOrCreateWallet(ctx, workerUserID, CurrencySilverSeal)
	if err != nil {
		return WrapErrorf(err, "failed to get worker wallet")
	}

	wallet.Balance += reward

	if err := repo.UpdateWalletWithVersion(ctx, wallet, wallet.Version); err != nil {
		return err
	}

	entry := &LedgerEntry{
		ID:               uuid.New().String(),
		Amount:           reward,
		Currency:         CurrencySilverSeal,
		ReceiverWalletID: &wallet.ID,
		Category:         CategoryTaskReward,
		ReferenceID:      referenceID,
		Metadata:         mustMarshalJSON(map[string]interface{}{"task_id": taskID, "application_id": applicationID}),
		CreatedAt:        time.Now(),
	}

	if err := repo.CreateLedgerEntry(ctx, entry); err != nil {
		return WrapErrorf(err, "failed to create reward ledger entry")
	}

	return nil
}

func (s *service) AdminAdjustBalance(ctx context.Context, userID string, amountCentinels int64, currency CurrencyCode, reason string) error {
	if !currency.IsValid() {
		return NewInvalidCurrencyError(string(currency))
	}
	if currency == CurrencyGoldSeal && amountCentinels > 0 {
		return NewValidationError("currency", "direct GOLD_SEAL mint is disabled")
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

func (s *service) logViolation(ctx context.Context, userID string, violationType ViolationType, endpoint string, amountAttempted *int64, details map[string]interface{}, ipAddress *string) {
	violation := &ViolationLog{
		ID:              uuid.New().String(),
		UserID:          userID,
		ViolationType:   violationType,
		AmountAttempted: amountAttempted,
		Details:         mustMarshalJSON(details),
		Endpoint:        StringPtr(endpoint),
		IPAddress:       ipAddress,
		CreatedAt:       time.Now(),
	}

	_ = s.repo.CreateViolationLog(ctx, violation)
}

func (s *service) processSealTransfer(ctx context.Context, senderID, receiverID string, amount int64, senderCurrency CurrencyCode, receiverCurrency CurrencyCode, category TransactionCategory, refID string, metadata map[string]interface{}) (*TransferResponse, error) {
	if amount != CentinelsPerSeal {
		return nil, NewValidationError("amount", "seal transfer must be exactly 1 seal")
	}

	if senderID == receiverID {
		return nil, NewSelfTransferError()
	}

	// Compute refID exactly once, before any retry. If left inside the closure,
	// a future refactor could declare 'var refID' inside the loop, causing each
	// retry iteration to generate a distinct nanosecond-stamped key — bypassing
	// the idempotency check and allowing triple-debits.
	if refID == "" {
		refID = fmt.Sprintf("seal_%s_%s_%d", senderID, receiverID, time.Now().UnixNano())
	}

	var response *TransferResponse
	err := s.executeWithRetry(ctx, func() error {
		tx, err := s.repo.BeginTx(ctx)
		if err != nil {
			return WrapErrorf(err, "failed to begin transaction")
		}
		defer tx.Rollback()

		txRepo := s.repo.WithTx(tx)

		debitRef := refID + ":silver_debit"
		creditRef := refID + ":gold_credit"

		debitExisting, debitErr := txRepo.GetLedgerEntryByReferenceID(ctx, debitRef)
		creditExisting, creditErr := txRepo.GetLedgerEntryByReferenceID(ctx, creditRef)
		if debitErr == nil && debitExisting != nil && creditErr == nil && creditExisting != nil {
			senderWalletCheck, _ := txRepo.GetOrCreateWallet(ctx, senderID, senderCurrency)
			receiverWalletCheck, _ := txRepo.GetOrCreateWallet(ctx, receiverID, receiverCurrency)

			if debitExisting.Amount != amount || debitExisting.Currency != senderCurrency || creditExisting.Amount != amount || creditExisting.Currency != receiverCurrency {
				return ErrIdempotencyConflict
			}
			if debitExisting.SenderWalletID == nil || *debitExisting.SenderWalletID != senderWalletCheck.ID {
				return ErrIdempotencyConflict
			}
			if creditExisting.ReceiverWalletID == nil || *creditExisting.ReceiverWalletID != receiverWalletCheck.ID {
				return ErrIdempotencyConflict
			}

			response = &TransferResponse{
				LedgerEntryID:   creditExisting.ID,
				SenderBalance:   CentinelsToSeals(senderWalletCheck.Balance),
				ReceiverBalance: CentinelsToSeals(receiverWalletCheck.Balance),
				CreatedNew:      false,
				Timestamp:       creditExisting.CreatedAt,
			}
			return nil
		}
		if (debitErr == nil && debitExisting != nil) || (creditErr == nil && creditExisting != nil) {
			return ErrIdempotencyConflict
		}

		// 2. Check/Update Cooldown
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

			decayed := false
			if diff >= threshold2 {
				repeatLevel = max(repeatLevel-2, 1)
				decayed = true
			} else if diff >= threshold1 {
				repeatLevel = max(repeatLevel-1, 1)
				decayed = true
			}

			if !decayed && repeatLevel < 5 {
				repeatLevel++
			}
		}

		// 3. Check Balances
		wallet, err := txRepo.GetOrCreateWallet(ctx, senderID, senderCurrency)
		if err != nil {
			return WrapErrorf(err, "failed to get wallet")
		}

		if !wallet.HasSufficientBalance(amount) {
			return NewInsufficientFundsError(senderID, senderCurrency, amount, wallet.Balance)
		}

		// 4. Get Receiver Wallet (required for recording ID)
		receiverWallet, err := txRepo.GetOrCreateWallet(ctx, receiverID, receiverCurrency)
		if err != nil {
			return WrapErrorf(err, "failed to get receiver wallet")
		}

		// 5. Atomic Updates
		// Sender
		wallet.Balance -= amount
		wallet.TotalSentAmount += amount
		if senderCurrency == CurrencySilverSeal && wallet.FreeBalance > 0 {
			deductFromFree := min(wallet.FreeBalance, amount)
			wallet.FreeBalance -= deductFromFree
		}
		if err := txRepo.UpdateWalletWithVersion(ctx, wallet, wallet.Version); err != nil {
			return err
		}

		// Receiver (Atomic Increment to avoid optimistic locking retries during high-concurrency)
		newRBalance, err := txRepo.IncrementWalletBalanceAtomic(ctx, receiverWallet.ID, amount)
		if err != nil {
			return err
		}
		receiverWallet.Balance = newRBalance

		// 6. Create Ledger Entries (SILVER debit + GOLD credit)
		debitMeta := map[string]interface{}{
			"sender_user_id":   senderID,
			"receiver_user_id": receiverID,
			"conversion":       "silver_to_gold",
			"entry_role":       "silver_debit",
		}
		for k, v := range metadata {
			debitMeta[k] = v
		}

		creditMeta := map[string]interface{}{
			"sender_user_id":   senderID,
			"receiver_user_id": receiverID,
			"conversion":       "silver_to_gold",
			"entry_role":       "gold_credit",
		}
		for k, v := range metadata {
			creditMeta[k] = v
		}

		entry := &LedgerEntry{
			ID:             uuid.New().String(),
			Amount:         amount,
			Currency:       senderCurrency,
			SenderWalletID: &wallet.ID,
			Category:       category,
			ReferenceID:    debitRef,
			Metadata:       mustMarshalJSON(debitMeta),
			CreatedAt:      now,
		}

		if err := txRepo.CreateLedgerEntry(ctx, entry); err != nil {
			return WrapErrorf(err, "failed to create debit ledger entry")
		}

		creditEntry := &LedgerEntry{
			ID:               uuid.New().String(),
			Amount:           amount,
			Currency:         receiverCurrency,
			ReceiverWalletID: &receiverWallet.ID,
			Category:         category,
			ReferenceID:      creditRef,
			Metadata:         mustMarshalJSON(creditMeta),
			CreatedAt:        now,
		}

		if err := txRepo.CreateLedgerEntry(ctx, creditEntry); err != nil {
			return WrapErrorf(err, "failed to create credit ledger entry")
		}

		if err := txRepo.UpsertGoldPeriodStat(ctx, receiverID, now.Year(), isoWeek(now), amount); err != nil {
			return WrapErrorf(err, "failed to upsert gold period stat")
		}

		receiverRankTier := ranks.GetRankTierString(int(receiverWallet.Balance / CentinelsPerSeal))
		if err := txRepo.UpsertProfileSealProjection(ctx, senderID, receiverID, amount/CentinelsPerSeal, receiverWallet.Balance, receiverRankTier); err != nil {
			return WrapErrorf(err, "failed to upsert profile seal projection")
		}

		// 7. Update Pair Cooldown
		duration := s.getCooldownDuration(repeatLevel)

		newCooldown := &PairCooldown{
			SenderUserID:   senderID,
			ReceiverUserID: receiverID,
			RepeatLevel:    repeatLevel,
			LastGrantAt:    now,
			NextAllowedAt:  now.Add(duration),
		}

		if err := txRepo.UpsertPairCooldown(ctx, newCooldown); err != nil {
			return WrapErrorf(err, "failed to update cooldown")
		}

		if err := tx.Commit(); err != nil {
			return WrapErrorf(err, "failed to commit transaction")
		}

		// Publish event
		if s.eventBus != nil {
			postID := ""
			if pid, ok := metadata["post_id"].(string); ok {
				postID = pid
			}
			_ = s.eventBus.Publish(ctx, eventbus.TypeSealReceived, eventbus.EconomyEvent{
				BaseEvent: eventbus.BaseEvent{
					Type:      eventbus.TypeSealReceived,
					ActorID:   senderID,
					Timestamp: time.Now(),
				},
				RecipientID: receiverID,
				Amount:      int(CentinelsToSeals(amount)),
				PostID:      postID,
			})
		}

		_ = s.cacheInvalidator.InvalidateStats(ctx, senderID)
		_ = s.cacheInvalidator.InvalidateStats(ctx, receiverID)

		response = &TransferResponse{
			LedgerEntryID:   creditEntry.ID,
			SenderBalance:   CentinelsToSeals(wallet.Balance),
			ReceiverBalance: CentinelsToSeals(receiverWallet.Balance),
			CreatedNew:      true,
			Timestamp:       creditEntry.CreatedAt,
		}

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

func isoWeek(t time.Time) int {
	_, w := t.ISOWeek()
	return w
}
