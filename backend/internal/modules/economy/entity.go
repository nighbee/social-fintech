package economy

import (
	"database/sql"
	"encoding/json"
	"math"
	"time"
)

const (
	CentinelsPerSeal = 100
	// MaxFreeSilverSeals   = 5.0  -> Moved to config
	// MaxFreeSilverCents   = 500  -> Moved to config
	// DailyAccrualSeals    = 1.0  -> Moved to config
	// DailyAccrualCents    = 100  -> Moved to config
	AccrualIntervalHours = 48 // Every 2 days (48 hours)
	// ReferralBonusSeals   = 1.0  -> Moved to config
	// ReferralBonusCents   = 100  -> Moved to config
	// DefaultTransferLimit = 50   -> Moved to config
	// TransferCooldownSecs = 60   -> Moved to config
)

type CurrencyCode string

const (
	CurrencySilverSeal CurrencyCode = "SILVER_SEAL"
	CurrencyGoldSeal   CurrencyCode = "GOLD_SEAL"
)

func (c CurrencyCode) IsValid() bool {
	return c == CurrencySilverSeal || c == CurrencyGoldSeal
}

func (c CurrencyCode) String() string {
	return string(c)
}

type TransactionCategory string

const (
	CategoryDailyAccrual     TransactionCategory = "DAILY_ACCRUAL"
	CategoryReferralBonus    TransactionCategory = "REFERRAL_BONUS"
	CategorySignupBonus      TransactionCategory = "SIGNUP_BONUS"
	CategoryP2PTransfer      TransactionCategory = "P2P_TRANSFER"
	CategoryTaskCreation     TransactionCategory = "TASK_CREATION"
	CategoryIAPDeposit       TransactionCategory = "IAP_DEPOSIT"
	CategorySystemCorrection TransactionCategory = "SYSTEM_CORRECTION"
	CategoryTaskReward       TransactionCategory = "TASK_REWARD"
	CategoryTaskRefund       TransactionCategory = "TASK_REFUND"
	CategoryPostSeal         TransactionCategory = "POST_SEAL"
	CategoryTransfer         TransactionCategory = "transfer"
)

func (t TransactionCategory) IsValid() bool {
	switch t {
	case CategoryDailyAccrual, CategoryReferralBonus, CategorySignupBonus, CategoryP2PTransfer,
		CategoryTaskCreation, CategoryTaskRefund, CategoryIAPDeposit,
		CategorySystemCorrection, CategoryTaskReward, CategoryPostSeal,
		CategoryTransfer:
		return true
	}
	return false
}

func (t TransactionCategory) String() string {
	return string(t)
}

type Wallet struct {
	ID                  string       `db:"id" json:"id"`
	UserID              string       `db:"user_id" json:"user_id"`
	Currency            CurrencyCode `db:"currency" json:"currency"`
	Balance             int64        `db:"balance" json:"balance"`
	FreeBalance         int64        `db:"free_balance" json:"free_balance"`
	TotalSentAmount     int64        `db:"total_sent_amount" json:"total_sent_amount"`
	TotalReceivedAmount int64        `db:"total_received_amount" json:"total_received_amount"`
	LastDailyAccrualAt  *time.Time   `db:"last_daily_accrual_at" json:"last_daily_accrual_at,omitempty"`
	LastTransferAt      *time.Time   `db:"last_transfer_at" json:"last_transfer_at,omitempty"`
	Version             int64        `db:"version" json:"version"`
	CreatedAt           time.Time    `db:"created_at" json:"created_at"`
	UpdatedAt           time.Time    `db:"updated_at" json:"updated_at"`
}

func (w *Wallet) HasSufficientBalance(amount int64) bool {
	return w.Balance >= amount
}

func (w *Wallet) CanReceiveFreeAccrual(maxFreeCents int64) bool {
	return w.FreeBalance < maxFreeCents
}

func (w *Wallet) NeedsDailyAccrual(now time.Time) bool {
	if w.LastDailyAccrualAt == nil {
		return true
	}
	// Check if 48 hours (2 days) have passed since last accrual
	elapsed := now.Sub(*w.LastDailyAccrualAt)
	return elapsed >= time.Duration(AccrualIntervalHours)*time.Hour
}

type LedgerEntry struct {
	ID               string              `db:"id" json:"id"`
	Amount           int64               `db:"amount" json:"amount"`
	Currency         CurrencyCode        `db:"currency" json:"currency"`
	SenderWalletID   *string             `db:"sender_wallet_id" json:"sender_wallet_id,omitempty"`
	ReceiverWalletID *string             `db:"receiver_wallet_id" json:"receiver_wallet_id,omitempty"`
	Category         TransactionCategory `db:"category" json:"category"`
	ReferenceID      string              `db:"reference_id" json:"reference_id"`
	Metadata         json.RawMessage     `db:"metadata" json:"metadata,omitempty" swaggertype:"object"`
	CreatedAt        time.Time           `db:"created_at" json:"created_at"`
}

func (l *LedgerEntry) IsSystemMint() bool {
	return l.SenderWalletID == nil
}

func (l *LedgerEntry) IsSystemBurn() bool {
	return l.ReceiverWalletID == nil
}

type Referral struct {
	ID                 string    `db:"id" json:"id"`
	ReferrerUserID     string    `db:"referrer_user_id" json:"referrer_user_id"`
	RefereeUserID      string    `db:"referee_user_id" json:"referee_user_id"`
	BonusLedgerEntryID *string   `db:"bonus_ledger_entry_id" json:"bonus_ledger_entry_id,omitempty"`
	IsActive           bool      `db:"is_active" json:"is_active"`
	CreatedAt          time.Time `db:"created_at" json:"created_at"`
}

type TransferLimit struct {
	ID                 string    `db:"id" json:"id"`
	UserID             string    `db:"user_id" json:"user_id"`
	MonthYear          string    `db:"month_year" json:"month_year"`
	TransfersCount     int       `db:"transfers_count" json:"transfers_count"`
	TotalSentCentinels int64     `db:"total_sent_centinels" json:"total_sent_centinels"`
	CreatedAt          time.Time `db:"created_at" json:"created_at"`
	UpdatedAt          time.Time `db:"updated_at" json:"updated_at"`
}

func (t *TransferLimit) CanTransfer(limit int) bool {
	return t.TransfersCount < limit
}

func (t *TransferLimit) IncrementTransfer(amount int64) {
	t.TransfersCount++
	t.TotalSentCentinels += amount
}

type ViolationType string

const (
	ViolationCooldownBreach           ViolationType = "COOLDOWN_BREACH"
	ViolationRateLimitExceeded        ViolationType = "RATE_LIMIT_EXCEEDED"
	ViolationFreeSilverCap            ViolationType = "FREE_SILVER_CAP"
	ViolationMonthlyLimitExceeded     ViolationType = "MONTHLY_LIMIT_EXCEEDED"
	ViolationInsufficientFundsAttempt ViolationType = "INSUFFICIENT_FUNDS_ATTEMPT"
	ViolationRepeatTransferPattern    ViolationType = "REPEAT_TRANSFER_PATTERN"
)

type ViolationLog struct {
	ID              string          `db:"id" json:"id"`
	UserID          string          `db:"user_id" json:"user_id"`
	ViolationType   ViolationType   `db:"violation_type" json:"violation_type"`
	AmountAttempted *int64          `db:"amount_attempted" json:"amount_attempted,omitempty"`
	Details         json.RawMessage `db:"details" json:"details,omitempty" swaggertype:"object"`
	IPAddress       *string         `db:"ip_address" json:"ip_address,omitempty"`
	Endpoint        *string         `db:"endpoint" json:"endpoint,omitempty"`
	CreatedAt       time.Time       `db:"created_at" json:"created_at"`
}

type UserInteraction struct {
	SenderID       string    `db:"sender_id" json:"sender_id"`
	ReceiverID     string    `db:"receiver_id" json:"receiver_id"`
	TotalTransfers int64     `db:"total_transfers" json:"total_transfers"`
	TotalAmount    int64     `db:"total_amount" json:"total_amount"`
	LastAmount     int64     `db:"last_amount" json:"last_amount"`
	LastTransferAt time.Time `db:"last_transfer_at" json:"last_transfer_at"`
	CreatedAt      time.Time `db:"created_at" json:"created_at"`
	UpdatedAt      time.Time `db:"updated_at" json:"updated_at"`
}

type PairCooldown struct {
	SenderUserID   string    `db:"sender_user_id" json:"sender_user_id"`
	ReceiverUserID string    `db:"receiver_user_id" json:"receiver_user_id"`
	RepeatLevel    int       `db:"repeat_level" json:"repeat_level"`
	LastGrantAt    time.Time `db:"last_grant_at" json:"last_grant_at"`
	NextAllowedAt  time.Time `db:"next_allowed_at" json:"next_allowed_at"`
	CreatedAt      time.Time `db:"created_at" json:"created_at"`
	UpdatedAt      time.Time `db:"updated_at" json:"updated_at"`
}

type BalanceResponse struct {
	SilverBalance     float64    `json:"silver_balance" example:"4.50"`
	SilverFreeBalance float64    `json:"silver_free_balance" example:"3.00"`
	GoldBalance       float64    `json:"gold_balance" example:"10.00"`
	LastAccrualAt     *time.Time `json:"last_accrual_at,omitempty"`
}

type WalletResponse struct {
	UserID            string     `json:"user_id"`
	SilverBalance     int64      `json:"silver_balance"`
	GoldBalance       int64      `json:"gold_balance"`
	LastSilverAccrual *time.Time `json:"last_silver_accrual,omitempty"`
	UpdatedAt         time.Time  `json:"updated_at"`
}

type TransferRequest struct {
	RecipientUserID string  `json:"recipient_user_id" validate:"required,uuid" example:"550e8400-e29b-41d4-a716-446655440000"`
	Amount          float64 `json:"amount" validate:"required,gt=0" example:"1.50"`
	Currency        string  `json:"currency" validate:"required,oneof=SILVER_SEAL GOLD_SEAL" example:"SILVER_SEAL"`
	Reason          string  `json:"reason,omitempty" validate:"max=255" example:"Payment for task"`
	IdempotencyKey  string  `json:"idempotency_key,omitempty" validate:"omitempty,uuid"`
}

type TransferResponse struct {
	LedgerEntryID   string    `json:"ledger_entry_id" example:"123e4567-e89b-12d3-a456-426614174000"`
	SenderBalance   float64   `json:"sender_balance" example:"3.50"`
	ReceiverBalance float64   `json:"receiver_balance" example:"6.50"`
	CreatedNew      bool      `json:"created_new"`
	Timestamp       time.Time `json:"timestamp"`
}

type GiveSealToPostRequest struct {
	ReceiverUserID string `json:"receiver_user_id" validate:"required,uuid"`
	Amount         int64  `json:"amount" validate:"required,min=1,max=10"`
	Comment        string `json:"comment,omitempty" validate:"omitempty,max=500"`
	Currency       string `json:"currency" validate:"required,oneof=SILVER_SEAL GOLD_SEAL"`
	IdempotencyKey string `json:"idempotency_key,omitempty" validate:"omitempty,uuid"`
}

type GiveSealToUserRequest struct {
	Amount         float64 `json:"amount" validate:"required,gt=0"`
	Currency       string  `json:"currency" validate:"required,oneof=SILVER_SEAL GOLD_SEAL"`
	Message        *string `json:"message,omitempty" validate:"omitempty,max=200"`
	IdempotencyKey string  `json:"idempotency_key,omitempty" validate:"omitempty,uuid"`
}

type ClaimDailyAccrualRequest struct {
	IdempotencyKey string `json:"idempotency_key,omitempty"`
}

type AccrualResponse struct {
	Success    bool      `json:"success"`
	Amount     float64   `json:"amount"`
	NewBalance float64   `json:"new_balance"`
	NextClaim  time.Time `json:"next_claim"`
}

type AdjustBalanceRequest struct {
	UserID   string       `json:"user_id" validate:"required,uuid"`
	Currency CurrencyCode `json:"currency" validate:"required"`
	Amount   int64        `json:"amount" validate:"required"`
	Reason   string       `json:"reason" validate:"required,max=255"`
}

type TransactionHistoryRequest struct {
	Page     int    `query:"page" validate:"min=1" example:"1"`
	PageSize int    `query:"page_size" validate:"min=1,max=100" example:"20"`
	Category string `query:"category" example:"P2P_TRANSFER"`
	Currency string `query:"currency" example:"SILVER_SEAL"`
}

type TransactionHistoryResponse struct {
	Transactions []TransactionItem `json:"transactions"`
	Page         int               `json:"page"`
	PageSize     int               `json:"page_size"`
	Total        int64             `json:"total"`
}

type TransactionItem struct {
	ID        string              `json:"id"`
	Type      string              `json:"type"`
	Amount    float64             `json:"amount"`
	Currency  CurrencyCode        `json:"currency"`
	Category  TransactionCategory `json:"category"`
	OtherUser *UserInfo           `json:"other_user,omitempty"`
	Timestamp time.Time           `json:"timestamp"`
	Reference string              `json:"reference,omitempty"`
}

type UserInfo struct {
	ID       string `json:"id"`
	Username string `json:"username"`
	Avatar   string `json:"avatar,omitempty"`
}

type ErrorResponse struct {
	Error   string `json:"error" example:"INSUFFICIENT_FUNDS"`
	Message string `json:"message,omitempty" example:"You don't have enough Seals"`
	Code    string `json:"code,omitempty" example:"INSUFFICIENT_FUNDS"`
}

type ReferralStatsResponse struct {
	TotalReferrals  int        `json:"total_referrals"`
	ActiveReferrals int        `json:"active_referrals"`
	TotalEarned     float64    `json:"total_earned"`
	Referrals       []Referral `json:"referrals,omitempty"`
}

type LimitsResponse struct {
	MonthlyTransferLimit int64      `json:"monthly_transfer_limit"`
	MonthlyTransferred   int64      `json:"monthly_transferred"`
	Remaining            int64      `json:"remaining"`
	NextReset            time.Time  `json:"next_reset"`
	DailyAccrualClaimed  bool       `json:"daily_accrual_claimed"`
	NextAccrual          *time.Time `json:"next_accrual,omitempty"`
}

type SealGiver struct {
	UserID    string    `json:"user_id"`
	Username  string    `json:"username"`
	AvatarURL string    `json:"avatar_url"`
	Amount    int64     `json:"amount"`
	GivenAt   time.Time `json:"given_at"`
}

type ViolationLogsResponse struct {
	Violations []*ViolationLog `json:"violations"`
	Page       int             `json:"page"`
	PageSize   int             `json:"page_size"`
	Total      int             `json:"total"`
}

func CentinelsToSeals(centinels int64) float64 {
	return float64(centinels) / float64(CentinelsPerSeal)
}

func SealsToCentinels(seals float64) int64 {
	return int64(math.Round(seals * float64(CentinelsPerSeal)))
}

func FormatMonthYear(t time.Time) string {
	return t.Format("2006-01")
}

func ToBalanceResponse(silverWallet, goldWallet *Wallet) *BalanceResponse {
	response := &BalanceResponse{
		SilverBalance:     0,
		SilverFreeBalance: 0,
		GoldBalance:       0,
	}

	if silverWallet != nil {
		response.SilverBalance = CentinelsToSeals(silverWallet.Balance)
		response.SilverFreeBalance = CentinelsToSeals(silverWallet.FreeBalance)
		response.LastAccrualAt = silverWallet.LastDailyAccrualAt
	}

	if goldWallet != nil {
		response.GoldBalance = CentinelsToSeals(goldWallet.Balance)
	}

	return response
}

func ToWalletResponse(silverWallet, goldWallet *Wallet, userID string) *WalletResponse {
	response := &WalletResponse{
		UserID:        userID,
		SilverBalance: 0,
		GoldBalance:   0,
		UpdatedAt:     time.Now(),
	}

	if silverWallet != nil {
		response.SilverBalance = silverWallet.Balance
		response.LastSilverAccrual = silverWallet.LastDailyAccrualAt
		response.UpdatedAt = silverWallet.UpdatedAt
	}

	if goldWallet != nil {
		response.GoldBalance = goldWallet.Balance
		if goldWallet.UpdatedAt.After(response.UpdatedAt) {
			response.UpdatedAt = goldWallet.UpdatedAt
		}
	}

	return response
}

func StringPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func TimePtr(t time.Time) *time.Time {
	return &t
}

func StringOrEmpty(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func NullString(s *string) sql.NullString {
	if s == nil || *s == "" {
		return sql.NullString{Valid: false}
	}
	return sql.NullString{String: *s, Valid: true}
}

func NullTime(t *time.Time) sql.NullTime {
	if t == nil {
		return sql.NullTime{Valid: false}
	}
	return sql.NullTime{Time: *t, Valid: true}
}

func NullStringToPtr(ns sql.NullString) *string {
	if !ns.Valid {
		return nil
	}
	return &ns.String
}

func NullTimeToPtr(nt sql.NullTime) *time.Time {
	if !nt.Valid {
		return nil
	}
	return &nt.Time
}

// DailyAccrualResult summarizes a daily accrual run.
type DailyAccrualResult struct {
	ProcessedUsers int
	AccruedUsers   int
	TotalUnits     int64
}
