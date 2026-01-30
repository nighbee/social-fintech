package economy

import "time"

// структура логов для абьюза чтобы понимать юзера и время абьюза
type ViolationLog struct {
	ID            string    `db:"id" json:"id"`
	UserID        string    `db:"user_id" json:"user_id"`
	ViolationType string    `db:"violation_type" json:"violation_type"`
	Endpoint      string    `db:"endpoint" json:"endpoint"`
	CreatedAt     time.Time `db:"created_at" json:"created_at"`
}

// трекает активити между сендером и ресивером
// повторные трансферы тоже чекаются
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


// currency for system
type Currency string


const (
	CurrencySilver Currency = "SILVER"
	CurrencyGold Currency = "GOLD"
)

// ledger dir

type EntryType string

const (
	EntryTypeDebit EntryType = "DEBIT"
	EntryTypeCredit EntryType = "CREDIT"
)

// wallet for balance
type Wallet struct {
	UserID string `db:"user_id" json:"user_id"`
	SilverBalance int64 `db:"silver_balance" json:"silver_balance"`
	GoldBalance int64 `db:"gold_balance" json:"gold_balance"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
	UpdatedAt time.Time `db:"updated_at" json:"updated_at"`
}

//ledger for records
type LedgerEntry struct {
	ID string `db:"id" json:"id"`
	TransactionID string `db:"transaction_id" json:"transaction_id"`
	AccountID string `db:"account_id" json:"account_id"`
	Amount int64 `db:"amount" json:"amount"`
	Currency Currency `db:"currency" json:"currency"`
	Type EntryType `db:"type" json:"type"`
	Reason string `db:"reason" json:"reason"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
}

// its from api (sender is derived from auth)
type TransferRequest struct {
	ToUserID string `json:"to_user_id"`
	Amount int64 `json:"amount"` //minor units said gpt
	Currency Currency `json:"currency"` // silver or gold
	Reason string `json:"reason"`
}

type TransferResponse struct {
	TransactionID string `json:"transaction_id"`
	FromUserID string `json:"from_user_id"`
	ToUserID string `kson:"to_user_id"`
	Amount int64 `json:"amount"`
	Currency Currency `json:"currency"`
	Reason string `json:"reason"`
	CreatedAt time.Time `json:"created_at"`
}

// DailyAccrualResult summarizes a daily accrual run.
type DailyAccrualResult struct {
	ProcessedUsers int
	AccruedUsers   int
	TotalUnits     int64
}