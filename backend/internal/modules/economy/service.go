package economy

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
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
	repo Repository
}

func NewService(repo Repository) Service {
	return &service{
		repo: repo,
	}
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

	tx, err := s.repo.BeginTx(ctx)
	if err != nil {
		return nil, WrapErrorf(err, "failed to begin transaction")
	}
	defer tx.Rollback()

	txRepo := s.repo.WithTx(tx)

	monthYear := FormatMonthYear(time.Now())
	limit, err := txRepo.GetOrCreateTransferLimit(ctx, senderUserID, monthYear)
	if err != nil {
		return nil, WrapErrorf(err, "failed to get transfer limit")
	}

	if !limit.CanTransfer() {
		s.logViolation(ctx, senderUserID, ViolationMonthlyLimitExceeded, &amountCents, map[string]interface{}{
			"recipient_id":  req.RecipientUserID,
			"current_count": limit.TransfersCount,
			"limit":         DefaultTransferLimit,
		})
		return nil, NewMonthlyLimitError(senderUserID, req.RecipientUserID, currency,
			int64(DefaultTransferLimit), int64(limit.TransfersCount), amountCents)
	}

	senderWallet, err := txRepo.GetWallet(ctx, senderUserID, currency)
	if err != nil {
		return nil, WrapErrorf(err, "failed to get sender wallet")
	}

	if senderWallet.LastTransferAt != nil {
		elapsed := time.Since(*senderWallet.LastTransferAt)
		if elapsed < time.Duration(TransferCooldownSecs)*time.Second {
			s.logViolation(ctx, senderUserID, ViolationCooldownBreach, &amountCents, map[string]interface{}{
				"recipient_id":     req.RecipientUserID,
				"elapsed_seconds":  int(elapsed.Seconds()),
				"cooldown_seconds": TransferCooldownSecs,
			})
			return nil, NewCooldownError(*senderWallet.LastTransferAt, time.Duration(TransferCooldownSecs)*time.Second)
		}
	}

	if !senderWallet.HasSufficientBalance(amountCents) {
		s.logViolation(ctx, senderUserID, ViolationInsufficientFundsAttempt, &amountCents, map[string]interface{}{
			"recipient_id": req.RecipientUserID,
			"available":    senderWallet.Balance,
			"required":     amountCents,
		})
		return nil, NewInsufficientFundsError(senderUserID, currency, amountCents, senderWallet.Balance)
	}

	receiverWallet, err := txRepo.GetOrCreateWallet(ctx, req.RecipientUserID, currency)
	if err != nil {
		return nil, WrapErrorf(err, "failed to get receiver wallet")
	}

	senderWallet.Balance -= amountCents
	if currency == CurrencySilverSeal && senderWallet.FreeBalance > 0 {
		deductFromFree := min(senderWallet.FreeBalance, amountCents)
		senderWallet.FreeBalance -= deductFromFree
	}
	now := time.Now()
	senderWallet.LastTransferAt = &now

	if err := txRepo.UpdateWalletWithVersion(ctx, senderWallet, senderWallet.Version); err != nil {
		return nil, WrapErrorf(err, "failed to update sender wallet")
	}

	receiverWallet.Balance += amountCents
	if err := txRepo.UpdateWallet(ctx, receiverWallet); err != nil {
		return nil, WrapErrorf(err, "failed to update receiver wallet")
	}

	referenceID := req.IdempotencyKey
	if referenceID == "" {
		referenceID = fmt.Sprintf("transfer_%s_%s_%d", senderUserID, req.RecipientUserID, time.Now().Unix())
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
		return nil, WrapErrorf(err, "failed to create ledger entry")
	}

	limit.IncrementTransfer(amountCents)
	if err := txRepo.UpdateTransferLimit(ctx, limit); err != nil {
		return nil, WrapErrorf(err, "failed to update transfer limit")
	}

	if err := tx.Commit(); err != nil {
		return nil, WrapErrorf(err, "failed to commit transaction")
	}

	return &TransferResponse{
		LedgerEntryID:   entry.ID,
		SenderBalance:   CentinelsToSeals(senderWallet.Balance),
		ReceiverBalance: CentinelsToSeals(receiverWallet.Balance),
		Timestamp:       entry.CreatedAt,
	}, nil
}

func (s *service) GiveSealToPost(ctx context.Context, userID, postID string, req *GiveSealToPostRequest) (*TransferResponse, error) {
	if req.Amount < 1 || req.Amount > 10 {
		return nil, NewInvalidAmountError(float64(req.Amount))
	}

	currency := CurrencyCode(req.Currency)
	if !currency.IsValid() {
		return nil, NewInvalidCurrencyError(req.Currency)
	}

	amountCents := req.Amount * CentinelsPerSeal

	tx, err := s.repo.BeginTx(ctx)
	if err != nil {
		return nil, WrapErrorf(err, "failed to begin transaction")
	}
	defer tx.Rollback()

	txRepo := s.repo.WithTx(tx)

	wallet, err := txRepo.GetWallet(ctx, userID, currency)
	if err != nil {
		return nil, WrapErrorf(err, "failed to get wallet")
	}

	if !wallet.HasSufficientBalance(amountCents) {
		return nil, NewInsufficientFundsError(userID, currency, amountCents, wallet.Balance)
	}

	wallet.Balance -= amountCents
	if currency == CurrencySilverSeal && wallet.FreeBalance > 0 {
		deductFromFree := min(wallet.FreeBalance, amountCents)
		wallet.FreeBalance -= deductFromFree
	}

	if err := txRepo.UpdateWalletWithVersion(ctx, wallet, wallet.Version); err != nil {
		return nil, WrapErrorf(err, "failed to update wallet")
	}

	referenceID := req.IdempotencyKey
	if referenceID == "" {
		referenceID = fmt.Sprintf("post_seal_%s_%s_%d", userID, postID, time.Now().Unix())
	}

	entry := &LedgerEntry{
		ID:             uuid.New().String(),
		Amount:         amountCents,
		Currency:       currency,
		SenderWalletID: &wallet.ID,
		Category:       CategoryPostSeal,
		ReferenceID:    referenceID,
		Metadata:       mustMarshalJSON(map[string]interface{}{"post_id": postID}),
		CreatedAt:      time.Now(),
	}

	if err := txRepo.CreateLedgerEntry(ctx, entry); err != nil {
		return nil, WrapErrorf(err, "failed to create ledger entry")
	}

	if err := tx.Commit(); err != nil {
		return nil, WrapErrorf(err, "failed to commit transaction")
	}

	return &TransferResponse{
		LedgerEntryID: entry.ID,
		SenderBalance: CentinelsToSeals(wallet.Balance),
		Timestamp:     entry.CreatedAt,
	}, nil
}

func (s *service) GiveSealToUser(ctx context.Context, fromUserID, toUserID string, req *GiveSealToUserRequest) (*TransferResponse, error) {
	if req.Amount <= 0 {
		return nil, NewInvalidAmountError(req.Amount)
	}

	currency := CurrencyCode(req.Currency)
	if !currency.IsValid() {
		return nil, NewInvalidCurrencyError(req.Currency)
	}

	if fromUserID == toUserID {
		return nil, NewSelfTransferError()
	}

	transferReq := &TransferRequest{
		RecipientUserID: toUserID,
		Amount:          req.Amount,
		Currency:        req.Currency,
		Reason:          StringOrEmpty(req.Message),
		IdempotencyKey:  req.IdempotencyKey,
	}

	return s.TransferSeals(ctx, fromUserID, transferReq)
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

	offset := (req.Page - 1) * req.PageSize
	entries, total, err := s.repo.GetUserTransactionHistory(ctx, userID, currency, req.PageSize, offset)
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
	tx, err := s.repo.BeginTx(ctx)
	if err != nil {
		return nil, WrapErrorf(err, "failed to begin transaction")
	}
	defer tx.Rollback()

	txRepo := s.repo.WithTx(tx)

	wallet, err := txRepo.GetOrCreateWallet(ctx, userID, CurrencySilverSeal)
	if err != nil {
		return nil, WrapErrorf(err, "failed to get wallet")
	}

	now := time.Now()
	if !wallet.NeedsDailyAccrual(now) {
		nextClaim := wallet.LastDailyAccrualAt.Add(24 * time.Hour)
		return nil, NewDailyAccrualError(nextClaim)
	}

	if !wallet.CanReceiveFreeAccrual() {
		s.logViolation(ctx, userID, ViolationFreeSilverCap, nil, map[string]interface{}{
			"current_free_balance": wallet.FreeBalance,
			"max_free_balance":     MaxFreeSilverCents,
		})
		return nil, NewFreeSilverCapError()
	}

	wallet.Balance += DailyAccrualCents
	wallet.FreeBalance += DailyAccrualCents
	wallet.LastDailyAccrualAt = &now

	if err := txRepo.UpdateWalletWithVersion(ctx, wallet, wallet.Version); err != nil {
		return nil, WrapErrorf(err, "failed to update wallet")
	}

	referenceID := idempotencyKey
	if referenceID == "" {
		referenceID = fmt.Sprintf("accrual_%s_%s", userID, now.Format("2006-01-02"))
	}

	entry := &LedgerEntry{
		ID:               uuid.New().String(),
		Amount:           DailyAccrualCents,
		Currency:         CurrencySilverSeal,
		ReceiverWalletID: &wallet.ID,
		Category:         CategoryDailyAccrual,
		ReferenceID:      referenceID,
		CreatedAt:        now,
	}

	if err := txRepo.CreateLedgerEntry(ctx, entry); err != nil {
		return nil, WrapErrorf(err, "failed to create ledger entry")
	}

	if err := tx.Commit(); err != nil {
		return nil, WrapErrorf(err, "failed to commit transaction")
	}

	nextClaim := now.Add(24 * time.Hour)
	return &AccrualResponse{
		Success:    true,
		Amount:     DailyAccrualSeals,
		NewBalance: CentinelsToSeals(wallet.Balance),
		NextClaim:  nextClaim,
	}, nil
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

	tx, err := s.repo.BeginTx(ctx)
	if err != nil {
		return WrapErrorf(err, "failed to begin transaction")
	}
	defer tx.Rollback()

	txRepo := s.repo.WithTx(tx)

	wallet, err := txRepo.GetOrCreateWallet(ctx, referrerUserID, CurrencySilverSeal)
	if err != nil {
		return WrapErrorf(err, "failed to get referrer wallet")
	}

	wallet.Balance += ReferralBonusCents

	if err := txRepo.UpdateWallet(ctx, wallet); err != nil {
		return WrapErrorf(err, "failed to update wallet")
	}

	referenceID := fmt.Sprintf("referral_%s_%s", referrerUserID, refereeUserID)
	entry := &LedgerEntry{
		ID:               uuid.New().String(),
		Amount:           ReferralBonusCents,
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

	return nil
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
		MonthlyTransferLimit: int64(DefaultTransferLimit),
		MonthlyTransferred:   limit.TotalSentCentinels,
		Remaining:            int64(DefaultTransferLimit - limit.TransfersCount),
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

	totalEarned := float64(len(referrals)) * ReferralBonusSeals

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

	wallet.Balance += amountCentinels

	if err := txRepo.UpdateWallet(ctx, wallet); err != nil {
		return WrapErrorf(err, "failed to update wallet")
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

	return nil
}

func (s *service) ChargeForTaskCreation(ctx context.Context, userID, taskID string, cost int64) error {
	if cost <= 0 {
		return NewInvalidAmountError(CentinelsToSeals(cost))
	}

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

	if !wallet.HasSufficientBalance(cost) {
		return NewInsufficientFundsError(userID, CurrencySilverSeal, cost, wallet.Balance)
	}

	wallet.Balance -= cost
	if wallet.FreeBalance > 0 {
		deductFromFree := min(wallet.FreeBalance, cost)
		wallet.FreeBalance -= deductFromFree
	}

	if err := txRepo.UpdateWalletWithVersion(ctx, wallet, wallet.Version); err != nil {
		return WrapErrorf(err, "failed to update wallet")
	}

	entry := &LedgerEntry{
		ID:             uuid.New().String(),
		Amount:         cost,
		Currency:       CurrencySilverSeal,
		SenderWalletID: &wallet.ID,
		Category:       CategoryTaskCreation,
		ReferenceID:    fmt.Sprintf("task_create_%s", taskID),
		Metadata:       mustMarshalJSON(map[string]interface{}{"task_id": taskID}),
		CreatedAt:      time.Now(),
	}

	if err := txRepo.CreateLedgerEntry(ctx, entry); err != nil {
		return WrapErrorf(err, "failed to create ledger entry")
	}

	if err := tx.Commit(); err != nil {
		return WrapErrorf(err, "failed to commit transaction")
	}

	return nil
}

func (s *service) RewardForTaskCompletion(ctx context.Context, userID, taskID string, reward int64) error {
	if reward <= 0 {
		return NewInvalidAmountError(CentinelsToSeals(reward))
	}

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

	wallet.Balance += reward

	if err := txRepo.UpdateWallet(ctx, wallet); err != nil {
		return WrapErrorf(err, "failed to update wallet")
	}

	entry := &LedgerEntry{
		ID:               uuid.New().String(),
		Amount:           reward,
		Currency:         CurrencySilverSeal,
		ReceiverWalletID: &wallet.ID,
		Category:         CategoryTaskReward,
		ReferenceID:      fmt.Sprintf("task_reward_%s", taskID),
		Metadata:         mustMarshalJSON(map[string]interface{}{"task_id": taskID}),
		CreatedAt:        time.Now(),
	}

	if err := txRepo.CreateLedgerEntry(ctx, entry); err != nil {
		return WrapErrorf(err, "failed to create ledger entry")
	}

	if err := tx.Commit(); err != nil {
		return WrapErrorf(err, "failed to commit transaction")
	}

	return nil
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

	wallet.Balance += amountCentinels

	if err := txRepo.UpdateWallet(ctx, wallet); err != nil {
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
		ReferenceID:      fmt.Sprintf("admin_adjust_%s_%d", userID, time.Now().Unix()),
		Metadata:         mustMarshalJSON(map[string]interface{}{"reason": reason}),
		CreatedAt:        time.Now(),
	}

	if err := txRepo.CreateLedgerEntry(ctx, entry); err != nil {
		return WrapErrorf(err, "failed to create ledger entry")
	}

	if err := tx.Commit(); err != nil {
		return WrapErrorf(err, "failed to commit transaction")
	}

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

func (s *service) logViolation(ctx context.Context, userID string, violationType ViolationType, amountAttempted *int64, details map[string]interface{}) {
	violation := &ViolationLog{
		ID:              uuid.New().String(),
		UserID:          userID,
		ViolationType:   violationType,
		AmountAttempted: amountAttempted,
		Details:         mustMarshalJSON(details),
		CreatedAt:       time.Now(),
	}

	_ = s.repo.CreateViolationLog(ctx, violation)
}
