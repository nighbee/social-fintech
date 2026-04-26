package economy

import (
	"errors"
	"fmt"
	"time"
)

var (
	ErrWalletNotFound  = errors.New("wallet not found")
	ErrWalletExists    = errors.New("wallet already exists")
	ErrInvalidCurrency = errors.New("invalid currency type")
	ErrNegativeBalance = errors.New("balance cannot be negative")

	ErrInsufficientFunds    = errors.New("insufficient funds")
	ErrInvalidAmount        = errors.New("amount must be positive")
	ErrAmountTooHigh        = errors.New("amount exceeds maximum allowed")
	ErrTransferToSelf       = errors.New("cannot transfer to self")
	ErrInvalidRecipient     = errors.New("invalid recipient")
	ErrDuplicateTransaction = errors.New("duplicate transaction detected")
	ErrBalanceExceedsMax    = errors.New("balance would exceed maximum limit")

	ErrLedgerEntryNotFound   = errors.New("ledger entry not found")
	ErrInvalidIdempotencyKey = errors.New("invalid idempotency key")
	ErrIdempotencyConflict   = errors.New("idempotency key already used for different transaction")
	ErrConsecutiveDuplicate  = errors.New("you cannot send the exact same reason twice in a row to this user")

	ErrMonthlyLimitExceeded = errors.New("monthly transfer limit exceeded")
	ErrDailyLimitExceeded   = errors.New("daily transfer limit exceeded")
	ErrCooldownActive       = errors.New("transfer cooldown period active")
	ErrRateLimitExceeded    = errors.New("rate limit exceeded")

	ErrDailyAccrualClaimed      = errors.New("daily accrual already claimed today")
	ErrDailyAccrualNotAvailable = errors.New("daily accrual not available yet")
	ErrAccrualLimitReached      = errors.New("accrual limit reached")
	ErrFreeSilverCapReached     = errors.New("free silver cap reached")

	ErrGoldNotTransferable = errors.New("gold seals cannot be transferred between users")
	ErrSilverOnly          = errors.New("operation only supports silver seals")
	ErrGoldOnly            = errors.New("operation only supports gold seals")

	ErrInvalidPostAmount = errors.New("post seal amount must be between 1 and 10")
	ErrPostNotFound      = errors.New("post not found")
	ErrSealAlreadyGiven  = errors.New("seal already given to this post")

	ErrTaskNotFound           = errors.New("task not found")
	ErrInsufficientTaskBudget = errors.New("insufficient budget to create task")
	ErrTaskAlreadyPaid        = errors.New("task reward already paid")

	ErrPurchaseNotFound        = errors.New("purchase not found")
	ErrPurchaseAlreadyCredited = errors.New("purchase already credited")
	ErrInvalidReceipt          = errors.New("invalid purchase receipt")

	ErrReferralNotFound      = errors.New("referral not found")
	ErrReferralAlreadyExists = errors.New("user has already been referred")
	ErrSelfReferral          = errors.New("cannot refer yourself")

	ErrTransactionFailed     = errors.New("transaction failed")
	ErrDatabaseError         = errors.New("database error")
	ErrInvalidInput          = errors.New("invalid input")
	ErrUnauthorized          = errors.New("unauthorized operation")
	ErrOptimisticLockFailure = errors.New("wallet version mismatch")
	ErrOptimisticLock        = ErrOptimisticLockFailure
)

const (
	CodeInsufficientFunds    = "INSUFFICIENT_FUNDS"
	CodeFreeSilverCap        = "FREE_SILVER_CAP"
	CodeTransferLimit        = "TRANSFER_LIMIT"
	CodeDuplicateTransaction = "DUPLICATE_TRANSACTION"
	CodeRateLimited          = "RATE_LIMITED"
	CodeInvalidAmount        = "INVALID_AMOUNT"
	CodeWalletNotFound       = "WALLET_NOT_FOUND"
	CodeSelfTransfer         = "SELF_TRANSFER"
	CodeInvalidCurrency      = "INVALID_CURRENCY"
	CodeReferralExists       = "REFERRAL_EXISTS"
	CodeSelfReferral         = "SELF_REFERRAL"
	CodeDatabaseError        = "DATABASE_ERROR"
	CodeOptimisticLock       = "OPTIMISTIC_LOCK_FAILURE"
	CodeCooldownActive       = "COOLDOWN_ACTIVE"
	CodeDailyAccrualClaimed  = "DAILY_ACCRUAL_CLAIMED"
	CodeConsecutiveDuplicate = "CONSECUTIVE_DUPLICATE"
)

type InsufficientFundsErr struct {
	UserID    string
	Currency  CurrencyCode
	Required  int64
	Available int64
}

func (e *InsufficientFundsErr) Error() string {
	return fmt.Sprintf("insufficient %s: required %.2f, available %.2f",
		e.Currency, CentinelsToSeals(e.Required), CentinelsToSeals(e.Available))
}

func NewInsufficientFundsError(userID string, currency CurrencyCode, required, available int64) *InsufficientFundsErr {
	return &InsufficientFundsErr{
		UserID:    userID,
		Currency:  currency,
		Required:  required,
		Available: available,
	}
}

type MonthlyLimitErr struct {
	UserID       string
	TargetUserID string
	Currency     CurrencyCode
	Limit        int64
	Current      int64
	Attempted    int64
	NextReset    time.Time
}

func (e *MonthlyLimitErr) Error() string {
	return fmt.Sprintf("monthly transfer limit exceeded: %d/%d used, attempted %d more",
		e.Current, e.Limit, e.Attempted)
}

func NewMonthlyLimitError(userID string, targetUserID string, currency CurrencyCode, limit, current, attempted int64) *MonthlyLimitErr {
	now := time.Now()
	nextReset := time.Date(now.Year(), now.Month()+1, 1, 0, 0, 0, 0, time.UTC)
	return &MonthlyLimitErr{
		UserID:       userID,
		TargetUserID: targetUserID,
		Currency:     currency,
		Limit:        limit,
		Current:      current,
		Attempted:    attempted,
		NextReset:    nextReset,
	}
}

type CooldownErr struct {
	LastTransfer     time.Time
	CooldownDuration time.Duration
	RetryAfter       time.Time
	RepeatLevel      int
}

func (e *CooldownErr) Error() string {
	return fmt.Sprintf("transfer cooldown active, retry after %s", e.RetryAfter.Format(time.RFC3339))
}

func NewCooldownError(lastTransfer time.Time, cooldownDuration time.Duration, repeatLevel int) *CooldownErr {
	return &CooldownErr{
		LastTransfer:     lastTransfer,
		CooldownDuration: cooldownDuration,
		RetryAfter:       lastTransfer.Add(cooldownDuration),
		RepeatLevel:      repeatLevel,
	}
}

type DailyAccrualErr struct {
	NextClaim time.Time
}

func (e *DailyAccrualErr) Error() string {
	return fmt.Sprintf("daily accrual already claimed, next claim available at %s", e.NextClaim.Format(time.RFC3339))
}

func NewDailyAccrualError(nextClaim time.Time) *DailyAccrualErr {
	return &DailyAccrualErr{
		NextClaim: nextClaim,
	}
}

type FreeSilverCapErr struct{}

func (e *FreeSilverCapErr) Error() string {
	return "free silver cap of 5.00 seals reached"
}

func NewFreeSilverCapError() *FreeSilverCapErr {
	return &FreeSilverCapErr{}
}

func NewInvalidAmountError(amount float64) error {
	return NewValidationError("amount", fmt.Sprintf("invalid amount: %.2f", amount))
}

func NewInvalidCurrencyError(currency string) error {
	return NewValidationError("currency", fmt.Sprintf("invalid currency: %s", currency))
}

func NewSelfTransferError() error {
	return ErrTransferToSelf
}

func NewSelfReferralError() error {
	return ErrSelfReferral
}

func NewReferralExistsError() error {
	return ErrReferralAlreadyExists
}

type ValidationErr struct {
	Field   string
	Message string
}

func (e *ValidationErr) Error() string {
	return fmt.Sprintf("validation error on field '%s': %s", e.Field, e.Message)
}

func NewValidationError(field, message string) *ValidationErr {
	return &ValidationErr{
		Field:   field,
		Message: message,
	}
}

type TransactionErr struct {
	Operation string
	Reason    string
	Err       error
}

func (e *TransactionErr) Error() string {
	if e.Err != nil {
		return fmt.Sprintf("transaction failed during %s: %s (%v)", e.Operation, e.Reason, e.Err)
	}
	return fmt.Sprintf("transaction failed during %s: %s", e.Operation, e.Reason)
}

func (e *TransactionErr) Unwrap() error {
	return e.Err
}

func NewTransactionError(operation, reason string, err error) *TransactionErr {
	return &TransactionErr{
		Operation: operation,
		Reason:    reason,
		Err:       err,
	}
}

type EconomyError struct {
	Err     error
	Code    string
	Message string
	Status  int
}

func (e *EconomyError) Error() string {
	if e.Message != "" {
		return e.Message
	}
	return e.Err.Error()
}

func (e *EconomyError) Unwrap() error {
	return e.Err
}

func NewEconomyError(err error, code string, message string, status int) *EconomyError {
	return &EconomyError{
		Err:     err,
		Code:    code,
		Message: message,
		Status:  status,
	}
}

func IsInsufficientFunds(err error) bool {
	if err == nil {
		return false
	}
	var insufficientErr *InsufficientFundsErr
	return errors.Is(err, ErrInsufficientFunds) || errors.As(err, &insufficientErr)
}

func IsMonthlyLimitExceeded(err error) bool {
	if err == nil {
		return false
	}
	var limitErr *MonthlyLimitErr
	return errors.Is(err, ErrMonthlyLimitExceeded) || errors.As(err, &limitErr)
}

func IsCooldownActive(err error) bool {
	if err == nil {
		return false
	}
	var cooldownErr *CooldownErr
	return errors.Is(err, ErrCooldownActive) || errors.As(err, &cooldownErr)
}

func IsDailyAccrualClaimed(err error) bool {
	if err == nil {
		return false
	}
	var accrualErr *DailyAccrualErr
	return errors.Is(err, ErrDailyAccrualClaimed) || errors.As(err, &accrualErr)
}

func IsDailyAccrualError(err error) bool {
	return IsDailyAccrualClaimed(err)
}

func IsFreeSilverCapError(err error) bool {
	if err == nil {
		return false
	}
	var capErr *FreeSilverCapErr
	return errors.Is(err, ErrFreeSilverCapReached) || errors.As(err, &capErr)
}

func IsValidationError(err error) bool {
	if err == nil {
		return false
	}
	var validationErr *ValidationErr
	return errors.As(err, &validationErr)
}

func IsNotFoundError(err error) bool {
	if err == nil {
		return false
	}
	return errors.Is(err, ErrWalletNotFound) ||
		errors.Is(err, ErrLedgerEntryNotFound) ||
		errors.Is(err, ErrPostNotFound) ||
		errors.Is(err, ErrTaskNotFound) ||
		errors.Is(err, ErrPurchaseNotFound)
}

func IsDuplicateError(err error) bool {
	if err == nil {
		return false
	}
	return errors.Is(err, ErrDuplicateTransaction) ||
		errors.Is(err, ErrWalletExists) ||
		errors.Is(err, ErrSealAlreadyGiven) ||
		errors.Is(err, ErrPurchaseAlreadyCredited) ||
		errors.Is(err, ErrIdempotencyConflict)
}

func IsEconomyError(err error) (*EconomyError, bool) {
	var economyErr *EconomyError
	ok := errors.As(err, &economyErr)
	return economyErr, ok
}

func WrapError(err error, message string) error {
	if err == nil {
		return nil
	}
	return fmt.Errorf("%s: %w", message, err)
}

func WrapErrorf(err error, format string, args ...interface{}) error {
	if err == nil {
		return nil
	}
	message := fmt.Sprintf(format, args...)
	return fmt.Errorf("%s: %w", message, err)
}
