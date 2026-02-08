# BrightBund Economy Module - Transaction Storage & Processing

## Overview

The BrightBund economy system is a dual-currency financial platform that manages user wallets, transactions, and enforces anti-abuse measures. This document explains how transactions are stored and processed throughout the system.

---

## 1. Core Architecture

### 1.1 Database Schema

The economy system uses a **dual-table architecture**:

#### **Wallets Table** (Current State)
Stores the current balance for each user's currency wallets.

```sql
CREATE TABLE wallets (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    currency VARCHAR(20) CHECK (currency IN ('SILVER_SEAL', 'GOLD_SEAL')),
    balance BIGINT NOT NULL DEFAULT 0,          -- Total balance in centinels
    free_balance BIGINT NOT NULL DEFAULT 0,     -- Free silver from accruals (max 500)
    last_daily_accrual_at TIMESTAMP,            -- Last time user claimed daily accrual
    last_transfer_at TIMESTAMP,                 -- Last P2P transfer (for cooldown)
    version BIGINT NOT NULL DEFAULT 1,          -- Optimistic locking version
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    UNIQUE(user_id, currency)
);
```

**Key Fields:**
- `balance`: Stored in **centinels** (1 Seal = 100 centinels). This prevents floating-point errors.
- `free_balance`: Tracks "free" silver from daily accruals, capped at 500 centinels (5.00 Seals)
- `version`: Implements **optimistic locking** to prevent race conditions during concurrent updates

#### **Ledger Entries Table** (Immutable Transaction History)
The **source of truth** for all financial movements. This table is append-only and never updated.

```sql
CREATE TABLE ledger_entries (
    id UUID PRIMARY KEY,
    amount BIGINT NOT NULL CHECK (amount > 0),  -- Always positive (in centinels)
    currency VARCHAR(20) CHECK (currency IN ('SILVER_SEAL', 'GOLD_SEAL')),
    sender_wallet_id UUID REFERENCES wallets(id),    -- NULL = system mint
    receiver_wallet_id UUID REFERENCES wallets(id),  -- NULL = system burn
    category VARCHAR(50) NOT NULL,              -- Transaction type
    reference_id VARCHAR(128) NOT NULL UNIQUE,  -- Idempotency key
    metadata JSONB,                             -- Additional context
    created_at TIMESTAMP NOT NULL
);
```

**Key Features:**
- **Immutable**: Records are never updated or deleted
- **Idempotency**: `reference_id` ensures duplicate transactions are prevented
- **Directional**: Tracks both sender and receiver, allowing for:
  - System mints (sender = NULL, e.g., daily accrual)
  - System burns (receiver = NULL, e.g., task creation cost)
  - P2P transfers (both sender and receiver present)

---

## 2. Currency System

### 2.1 Two Currency Types

| Currency | Code | Purpose | How to Earn | Caps |
|----------|------|---------|-------------|------|
| **Silver Seal** | `SILVER_SEAL` | Free/earned currency | Daily accrual, referrals, task rewards | Free balance capped at 5.00 (500 centinels) |
| **Gold Seal** | `GOLD_SEAL` | Premium/paid currency | In-app purchases (IAP) | No cap |

### 2.2 Centinels - Integer-Based Currency

All amounts are stored as **integers in centinels** to avoid floating-point precision issues:

```
1.00 Seal = 100 centinels
0.50 Seal = 50 centinels
5.00 Seals = 500 centinels
```

**Conversion Functions** (from [entity.go](backend/internal/modules/economy/entity.go#L10-L11)):
```go
const CentinelsPerSeal = 100

func SealsToCentinels(seals float64) int64 {
    return int64(math.Round(seals * CentinelsPerSeal))
}

func CentinelsToSeals(centinels int64) float64 {
    return float64(centinels) / CentinelsPerSeal
}
```

---

## 3. Transaction Categories

Every ledger entry is categorized to track the source/purpose of funds:

| Category | Code | Description | Sender | Receiver |
|----------|------|-------------|--------|----------|
| **Daily Accrual** | `DAILY_ACCRUAL` | Free 1.00 Silver every 48 hours | NULL (system) | User wallet |
| **Referral Bonus** | `REFERRAL_BONUS` | 1.00 Silver for inviting a new user | NULL (system) | Referrer wallet |
| **P2P Transfer** | `P2P_TRANSFER` | User-to-user transfers | Sender wallet | Receiver wallet |
| **Task Creation** | `TASK_CREATION` | Cost to create a map task | User wallet | NULL (system burn) |
| **Task Reward** | `TASK_REWARD` | Earning for completing a task | NULL (system) | User wallet |
| **IAP Deposit** | `IAP_DEPOSIT` | In-app purchase (Apple/Google) | NULL (system) | User wallet |
| **Post Seal** | `POST_SEAL` | Giving 1-10 seals to a post | User wallet | NULL (system burn) |
| **System Correction** | `SYSTEM_CORRECTION` | Admin manual adjustment | Varies | Varies |

---

## 4. Transaction Processing Flow

### 4.1 General Transaction Pattern

All financial operations follow this **atomic transaction pattern**:

```go
// 1. Begin database transaction
tx, err := s.repo.BeginTx(ctx)
defer tx.Rollback()

// 2. Load wallets with FOR UPDATE (locks for current transaction)
senderWallet := txRepo.GetWallet(ctx, senderID, currency)
receiverWallet := txRepo.GetOrCreateWallet(ctx, receiverID, currency)

// 3. Validate business rules
if !senderWallet.HasSufficientBalance(amount) {
    return InsufficientFundsError
}

// 4. Update wallet balances
senderWallet.Balance -= amount
receiverWallet.Balance += amount

// 5. Use optimistic locking to update wallets
txRepo.UpdateWalletWithVersion(ctx, senderWallet, senderWallet.Version)
txRepo.UpdateWalletWithVersion(ctx, receiverWallet, receiverWallet.Version)

// 6. Create immutable ledger entry
ledgerEntry := &LedgerEntry{
    ID:               uuid.New(),
    Amount:           amount,
    Currency:         currency,
    SenderWalletID:   &senderWallet.ID,
    ReceiverWalletID: &receiverWallet.ID,
    Category:         CategoryP2PTransfer,
    ReferenceID:      idempotencyKey,
    CreatedAt:        time.Now(),
}
txRepo.CreateLedgerEntry(ctx, ledgerEntry)

// 7. Commit transaction
tx.Commit()
```

### 4.2 Optimistic Locking for Concurrency

The system uses **optimistic locking** to handle concurrent wallet updates:

```go
func (r *repository) UpdateWalletWithVersion(ctx, wallet *Wallet, expectedVersion int64) error {
    query := `
        UPDATE wallets
        SET balance = $1,
            version = version + 1,
            updated_at = NOW()
        WHERE id = $2 AND version = $3
        RETURNING version
    `
    
    err := sqlx.GetContext(ctx, r.executor, &newVersion, query,
        wallet.Balance, wallet.ID, expectedVersion)
    
    if err == sql.ErrNoRows {
        return ErrOptimisticLock  // Someone else modified this wallet
    }
    
    wallet.Version = newVersion
    return nil
}
```

**How it works:**
1. Load wallet with current version (e.g., version = 5)
2. Calculate new balance
3. Update ONLY if version is still 5
4. If another transaction incremented version to 6, update fails
5. Entire transaction rolls back, client must retry

---

## 5. Transaction History Storage

### 5.1 Where Transaction History is Stored

Transaction history is stored in the **`ledger_entries`** table. This table is:

- **Append-only**: Records are never updated or deleted
- **Complete audit trail**: Every financial movement is recorded
- **Bidirectional**: Can be queried from sender or receiver perspective

### 5.2 Querying Transaction History

Users can retrieve their transaction history via the service layer:

```go
func (s *service) GetTransactionHistory(ctx context.Context, userID string, 
    req *TransactionHistoryRequest) (*TransactionHistoryResponse, error)
```

**SQL Query** (from [repository.go](backend/internal/modules/economy/repository.go#L184-L217)):
```sql
SELECT le.id, le.amount, le.currency, le.sender_wallet_id, le.receiver_wallet_id,
       le.category, le.reference_id, le.metadata, le.created_at
FROM ledger_entries le
LEFT JOIN wallets ws ON le.sender_wallet_id = ws.id
LEFT JOIN wallets wr ON le.receiver_wallet_id = wr.id
WHERE le.currency = $1
  AND (ws.user_id = $2 OR wr.user_id = $2)  -- User is sender OR receiver
ORDER BY le.created_at DESC
LIMIT $3 OFFSET $4
```

**Features:**
- **Pagination**: Supports limit/offset for efficient loading
- **Filtering**: Can filter by currency and/or category
- **Bidirectional**: Shows both sent and received transactions
- **Type Detection**: Service layer determines if transaction was SENT or RECEIVED:

```go
txType := "RECEIVED"
if entry.SenderWalletID != nil {
    if wallet != nil && *entry.SenderWalletID == wallet.ID {
        txType = "SENT"
    }
}
```

### 5.3 Metadata Storage

Each ledger entry includes a **`metadata` JSONB** field for storing contextual information:

**Examples:**
- P2P Transfer: `{"reason": "Thanks for the help!"}`
- Referral Bonus: `{"referee_id": "uuid-of-new-user"}`
- Task Creation: `{"task_id": "task-uuid", "task_title": "Clean the park"}`
- Post Seal: `{"post_id": "post-uuid"}`

This allows rich transaction history displays in the UI.

---

## 6. Anti-Abuse & Security Measures

### 6.1 Idempotency Protection

Every transaction requires a **unique reference ID** to prevent duplicate processing:

```go
referenceID := "transfer_userA_userB_1675201234"

// Check if this reference ID was already processed
existing, err := txRepo.GetLedgerEntryByReferenceID(ctx, referenceID)
if existing != nil {
    // Already processed - return existing result
    return existingResponse
}

// First time processing - continue with transaction
```

**Reference ID Patterns:**
- Daily Accrual: `accrual_<userID>_<date>`
- P2P Transfer: `transfer_<senderID>_<receiverID>_<timestamp>`
- IAP Deposit: Apple/Google receipt ID
- Referral: `referral_<referrerID>_<refereeID>`

### 6.2 Transfer Limits & Cooldowns

#### **Monthly Transfer Limit**
Users are limited to **50 P2P transfers per month** (tracked in `transfer_limits` table):

```sql
CREATE TABLE transfer_limits (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    month_year VARCHAR(7) NOT NULL,  -- e.g., "2026-01"
    transfers_count INT NOT NULL DEFAULT 0,
    total_sent_centinels BIGINT NOT NULL DEFAULT 0,
    UNIQUE(user_id, month_year)
);
```

**Enforcement** (from [service.go](backend/internal/modules/economy/service.go#L107-L119)):
```go
limit, err := txRepo.GetOrCreateTransferLimit(ctx, senderUserID, monthYear)
if !limit.CanTransfer() {  // limit.TransfersCount >= 50
    s.logViolation(ctx, senderUserID, ViolationMonthlyLimitExceeded, ...)
    return NewMonthlyLimitError(...)
}

// After successful transfer
limit.IncrementTransfer(amountCents)
txRepo.UpdateTransferLimit(ctx, limit)
```

#### **Transfer Cooldown**
Users must wait **60 seconds** between P2P transfers:

```go
if senderWallet.LastTransferAt != nil {
    elapsed := time.Since(*senderWallet.LastTransferAt)
    if elapsed < 60 * time.Second {
        s.logViolation(ctx, senderUserID, ViolationCooldownBreach, ...)
        return NewCooldownError(...)
    }
}

// After successful transfer
now := time.Now()
senderWallet.LastTransferAt = &now
```

### 6.3 Free Silver Cap

To prevent exploitation, free silver from daily accruals is **capped at 5.00 Seals (500 centinels)**:

```go
if wallet.FreeBalance >= MaxFreeSilverCents {  // 500
    s.logViolation(ctx, userID, ViolationFreeSilverCap, ...)
    return NewFreeSilverCapError()
}

// When user spends silver, prioritize spending free balance first
if currency == CurrencySilverSeal && wallet.FreeBalance > 0 {
    deductFromFree := min(wallet.FreeBalance, amountCents)
    wallet.FreeBalance -= deductFromFree
}
```

### 6.4 Violation Logging

All rule violations are logged in the `economy_violations` table for audit and anti-fraud analysis:

```sql
CREATE TABLE economy_violations (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    violation_type VARCHAR(50) NOT NULL,
    amount_attempted BIGINT,
    details JSONB,
    ip_address VARCHAR(45),
    created_at TIMESTAMP,
    endpoint VARCHAR(255)
);
```

**Violation Types:**
- `COOLDOWN_BREACH`: Attempted transfer before 60s cooldown
- `MONTHLY_LIMIT_EXCEEDED`: Attempted 51st transfer in a month
- `FREE_SILVER_CAP`: Attempted to claim accrual while at 5.00 free silver
- `INSUFFICIENT_FUNDS_ATTEMPT`: Attempted to spend more than balance
- `REPEAT_TRANSFER_PATTERN`: Same amount to same user 5+ times in 24h

---

## 7. Specific Transaction Types

### 7.1 Daily Accrual (Free Silver)

**Rules:**
- Amount: 1.00 Silver Seal (100 centinels)
- Frequency: Every **48 hours** (not daily, despite the name)
- Cap: User's `free_balance` cannot exceed 5.00 Seals

**Flow** (from [service.go](backend/internal/modules/economy/service.go#L402-L488)):

```go
func (s *service) ClaimDailyAccrual(ctx, userID, idempotencyKey) {
    wallet := GetOrCreateWallet(userID, SILVER_SEAL)
    
    // Check if 48 hours passed since last claim
    if !wallet.NeedsDailyAccrual(now) {
        return DailyAccrualError(nextClaim)
    }
    
    // Check free silver cap
    if wallet.FreeBalance >= MaxFreeSilverCents {
        return FreeSilverCapError
    }
    
    // Credit both balances
    wallet.Balance += 100
    wallet.FreeBalance += 100
    wallet.LastDailyAccrualAt = now
    UpdateWalletWithVersion(wallet)
    
    // Create ledger entry (system mint)
    CreateLedgerEntry(&LedgerEntry{
        Amount:           100,
        Currency:         SILVER_SEAL,
        SenderWalletID:   nil,  // System mint
        ReceiverWalletID: wallet.ID,
        Category:         DAILY_ACCRUAL,
        ReferenceID:      "accrual_<userID>_<date>",
    })
}
```

**Ledger Entry Example:**
```json
{
  "id": "uuid",
  "amount": 100,
  "currency": "SILVER_SEAL",
  "sender_wallet_id": null,
  "receiver_wallet_id": "wallet-uuid",
  "category": "DAILY_ACCRUAL",
  "reference_id": "accrual_user123_2026-02-02",
  "metadata": {},
  "created_at": "2026-02-02T10:30:00Z"
}
```

### 7.2 P2P Transfer (User to User)

**Rules:**
- Amount: Any positive value (user must have sufficient balance)
- Cooldown: 60 seconds between transfers
- Monthly Limit: 50 transfers per month
- Self-Transfer: Not allowed

**Flow** (from [service.go](backend/internal/modules/economy/service.go#L76-L224)):

```go
func (s *service) TransferSeals(ctx, senderUserID, req) {
    // Validations
    ValidateAmount(req.Amount)
    ValidateCurrency(req.Currency)
    CheckSelfTransfer(senderUserID, req.RecipientUserID)
    
    // Check limits
    limit := GetOrCreateTransferLimit(senderUserID, monthYear)
    if !limit.CanTransfer() { return MonthlyLimitError }
    
    // Check cooldown
    if time.Since(senderWallet.LastTransferAt) < 60s {
        return CooldownError
    }
    
    // Check balance
    if !senderWallet.HasSufficientBalance(amountCents) {
        return InsufficientFundsError
    }
    
    // Execute transfer
    senderWallet.Balance -= amountCents
    if senderWallet.FreeBalance > 0 {
        // Deduct from free balance first
        deductFromFree = min(senderWallet.FreeBalance, amountCents)
        senderWallet.FreeBalance -= deductFromFree
    }
    senderWallet.LastTransferAt = now
    
    receiverWallet.Balance += amountCents
    
    UpdateWalletWithVersion(senderWallet)
    UpdateWalletWithVersion(receiverWallet)
    
    // Create ledger entry
    CreateLedgerEntry(&LedgerEntry{
        Amount:           amountCents,
        Currency:         currency,
        SenderWalletID:   senderWallet.ID,
        ReceiverWalletID: receiverWallet.ID,
        Category:         P2P_TRANSFER,
        ReferenceID:      idempotencyKey,
        Metadata:         {"reason": req.Reason},
    })
    
    // Update transfer limit
    limit.IncrementTransfer(amountCents)
    UpdateTransferLimit(limit)
    
    // Track user interaction (for abuse detection)
    UpsertUserInteraction(senderUserID, receiverID, amountCents)
}
```

**Ledger Entry Example:**
```json
{
  "id": "uuid",
  "amount": 250,
  "currency": "SILVER_SEAL",
  "sender_wallet_id": "sender-wallet-uuid",
  "receiver_wallet_id": "receiver-wallet-uuid",
  "category": "P2P_TRANSFER",
  "reference_id": "transfer_userA_userB_1675201234",
  "metadata": {"reason": "Thanks for the help!"},
  "created_at": "2026-02-02T10:30:00Z"
}
```

### 7.3 Referral Bonus

**Rules:**
- Amount: 1.00 Silver Seal (100 centinels)
- Trigger: When a new user signs up using a referral code
- Limit: Each new user can only be referred once
- Recipient: The referrer (existing user)

**Flow** (from [service.go](backend/internal/modules/economy/service.go#L494-L561)):

```go
func (s *service) ProcessReferralBonus(ctx, referrerUserID, refereeUserID) {
    // Validate
    if referrerUserID == refereeUserID { return SelfReferralError }
    
    // Check if referee was already referred
    existing := GetReferralByReferee(refereeUserID)
    if existing != nil { return ReferralExistsError }
    
    // Credit referrer
    referrerWallet := GetOrCreateWallet(referrerUserID, SILVER_SEAL)
    referrerWallet.Balance += 100
    UpdateWalletWithVersion(referrerWallet)
    
    // Create ledger entry (system mint)
    entry := CreateLedgerEntry(&LedgerEntry{
        Amount:           100,
        Currency:         SILVER_SEAL,
        SenderWalletID:   nil,  // System mint
        ReceiverWalletID: referrerWallet.ID,
        Category:         REFERRAL_BONUS,
        ReferenceID:      "referral_<referrerID>_<refereeID>",
        Metadata:         {"referee_id": refereeUserID},
    })
    
    // Track referral relationship
    CreateReferral(&Referral{
        ReferrerUserID:     referrerUserID,
        RefereeUserID:      refereeUserID,
        BonusLedgerEntryID: entry.ID,
        IsActive:           true,
    })
}
```

**Database Tables:**
```sql
-- referrals table tracks who invited whom
CREATE TABLE referrals (
    id UUID PRIMARY KEY,
    referrer_user_id UUID NOT NULL,        -- User who invited
    referee_user_id UUID NOT NULL UNIQUE,  -- New user (can only be referred once)
    bonus_ledger_entry_id UUID,            -- Link to ledger entry
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP
);
```

### 7.4 IAP Deposit (In-App Purchase)

**Rules:**
- Amount: Determined by purchase package
- Currency: Usually GOLD_SEAL (premium)
- Idempotency: Apple/Google receipt ID used as reference ID
- Verification: Receipt should be verified by payment module before calling

**Flow** (from [service.go](backend/internal/modules/economy/service.go#L626-L671)):

```go
func (s *service) ProcessIAPDeposit(ctx, userID, amountCentinels, currency, receiptID) {
    // Check for duplicate
    existing := GetLedgerEntryByReferenceID(receiptID)
    if existing != nil { return nil }  // Already processed
    
    // Credit user
    wallet := GetOrCreateWallet(userID, currency)
    wallet.Balance += amountCentinels
    UpdateWalletWithVersion(wallet)
    
    // Create ledger entry (system mint)
    CreateLedgerEntry(&LedgerEntry{
        Amount:           amountCentinels,
        Currency:         currency,
        SenderWalletID:   nil,  // System mint
        ReceiverWalletID: wallet.ID,
        Category:         IAP_DEPOSIT,
        ReferenceID:      receiptID,
        Metadata:         {"platform": "apple", "product_id": "..."},
    })
}
```

### 7.5 Task Creation (Spending)

**Rules:**
- Amount: Configurable cost per task (e.g., 1.00 Silver)
- Effect: Deducts from user balance (system burn)
- Purpose: Users pay to create tasks on the map

**Flow** (from [service.go](backend/internal/modules/economy/service.go#L673-L720)):

```go
func (s *service) ChargeForTaskCreation(ctx, userID, taskID, cost) {
    wallet := GetWallet(userID, SILVER_SEAL)
    
    // Check balance
    if !wallet.HasSufficientBalance(cost) {
        return InsufficientFundsError
    }
    
    // Deduct balance
    wallet.Balance -= cost
    if wallet.FreeBalance > 0 {
        deductFromFree = min(wallet.FreeBalance, cost)
        wallet.FreeBalance -= deductFromFree
    }
    UpdateWalletWithVersion(wallet)
    
    // Create ledger entry (system burn)
    CreateLedgerEntry(&LedgerEntry{
        Amount:           cost,
        Currency:         SILVER_SEAL,
        SenderWalletID:   wallet.ID,
        ReceiverWalletID: nil,  // System burn
        Category:         TASK_CREATION,
        ReferenceID:      "task_creation_<taskID>",
        Metadata:         {"task_id": taskID},
    })
}
```

---

## 8. Database Indexes

The system uses strategic indexes for performance:

```sql
-- Wallets
CREATE UNIQUE INDEX idx_wallets_user_currency ON wallets(user_id, currency);

-- Ledger Entries (Transaction History)
CREATE INDEX idx_ledger_entries_sender ON ledger_entries(sender_wallet_id);
CREATE INDEX idx_ledger_entries_receiver ON ledger_entries(receiver_wallet_id);
CREATE INDEX idx_ledger_entries_created_at ON ledger_entries(created_at DESC);
CREATE UNIQUE INDEX idx_ledger_reference_unique ON ledger_entries(reference_id);

-- Transfer Limits
CREATE UNIQUE INDEX idx_transfer_limits_user_month ON transfer_limits(user_id, month_year);

-- Referrals
CREATE INDEX idx_referrals_referrer ON referrals(referrer_user_id);
CREATE UNIQUE INDEX idx_referrals_referee ON referrals(referee_user_id);

-- Violations
CREATE INDEX idx_economy_violations_user ON economy_violations(user_id);
CREATE INDEX idx_economy_violations_type ON economy_violations(violation_type);
CREATE INDEX idx_economy_violations_created ON economy_violations(created_at DESC);
```

---

## 9. Data Flow Summary

```
┌─────────────────────────────────────────────────────────────┐
│                      USER ACTION                            │
│  (Transfer, Claim Accrual, Buy IAP, Create Task, etc.)     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                 SERVICE LAYER                               │
│  1. Begin DB Transaction                                    │
│  2. Load Wallets (with FOR UPDATE lock)                     │
│  3. Validate Business Rules                                 │
│     - Balance check                                         │
│     - Rate limits                                           │
│     - Cooldowns                                             │
│     - Anti-abuse checks                                     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              REPOSITORY LAYER                               │
│  4. Update Wallet Balances (with optimistic locking)        │
│  5. Create Ledger Entry (immutable record)                  │
│  6. Update Auxiliary Tables (limits, referrals, etc.)       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   DATABASE                                  │
│  ┌──────────────┐  ┌─────────────────┐  ┌────────────────┐ │
│  │   WALLETS    │  │ LEDGER_ENTRIES  │  │ TRANSFER_LIMITS│ │
│  │ (Current)    │  │ (History)       │  │ (Anti-Abuse)   │ │
│  │              │  │                 │  │                │ │
│  │ - Balance    │  │ - Amount        │  │ - Count/Month  │ │
│  │ - Version    │  │ - Sender        │  │ - Total Sent   │ │
│  │ - Last Tx    │  │ - Receiver      │  └────────────────┘ │
│  └──────────────┘  │ - Category      │                      │
│                    │ - Reference ID  │  ┌────────────────┐ │
│                    │ - Metadata      │  │  VIOLATIONS    │ │
│                    │ - Created At    │  │  (Audit Log)   │ │
│                    └─────────────────┘  └────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## 10. Key Design Principles

### 10.1 Immutability
- Ledger entries are **never updated or deleted**
- Complete audit trail for compliance and dispute resolution
- Balance reconstruction possible from ledger history

### 10.2 Idempotency
- Every transaction requires a unique `reference_id`
- Prevents duplicate processing from network retries
- Enables safe retries in distributed systems

### 10.3 Atomicity
- All operations wrapped in database transactions
- Either everything succeeds or everything rolls back
- No partial states (e.g., sender debited but receiver not credited)

### 10.4 Consistency
- Optimistic locking prevents race conditions
- Version field ensures concurrent updates fail safely
- Constraints enforce business rules at database level

### 10.5 Performance
- Strategic indexes on query patterns
- Integer arithmetic (centinels) faster than floating-point
- Pagination for large result sets

### 10.6 Security
- Rate limits and cooldowns prevent abuse
- Violation logging for fraud detection
- Free silver cap prevents exploitation
- Balance validation before every transaction

---

## 11. Common Query Patterns

### 11.1 Get User's Transaction History
```sql
-- All transactions for user (sent + received)
SELECT le.*, ws.user_id as sender_user, wr.user_id as receiver_user
FROM ledger_entries le
LEFT JOIN wallets ws ON le.sender_wallet_id = ws.id
LEFT JOIN wallets wr ON le.receiver_wallet_id = wr.id
WHERE le.currency = 'SILVER_SEAL'
  AND (ws.user_id = 'user-uuid' OR wr.user_id = 'user-uuid')
ORDER BY le.created_at DESC
LIMIT 20;
```

### 11.2 Calculate User's Total Earned from Referrals
```sql
SELECT COUNT(*) * 100 as total_earned_centinels
FROM referrals
WHERE referrer_user_id = 'user-uuid'
  AND is_active = true;
```

### 11.3 Audit Trail for Specific Transaction
```sql
-- Find all details about a specific transaction
SELECT 
    le.*,
    ws.user_id as sender_user_id,
    wr.user_id as receiver_user_id,
    ws.balance as sender_balance_after,
    wr.balance as receiver_balance_after
FROM ledger_entries le
LEFT JOIN wallets ws ON le.sender_wallet_id = ws.id
LEFT JOIN wallets wr ON le.receiver_wallet_id = wr.id
WHERE le.id = 'ledger-entry-uuid';
```

### 11.4 Monthly Transfer Report
```sql
SELECT 
    month_year,
    transfers_count,
    total_sent_centinels / 100.0 as total_sent_seals
FROM transfer_limits
WHERE user_id = 'user-uuid'
ORDER BY month_year DESC;
```

### 11.5 Fraud Detection - Suspicious Patterns
```sql
-- Users with many violation logs
SELECT 
    user_id,
    violation_type,
    COUNT(*) as violation_count
FROM economy_violations
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY user_id, violation_type
HAVING COUNT(*) > 10
ORDER BY violation_count DESC;
```

---

## 12. API Endpoints

The economy module exposes these key endpoints (defined in [handler.go](backend/internal/modules/economy/handler.go)):

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/economy/balance` | GET | Get user's wallet balances |
| `/economy/transfer` | POST | P2P transfer to another user |
| `/economy/history` | GET | Transaction history with pagination |
| `/economy/accrual/claim` | POST | Claim daily accrual |
| `/economy/limits` | GET | Check transfer limits and cooldowns |
| `/economy/referrals` | GET | Referral stats and history |
| `/economy/seal/post` | POST | Give seal(s) to a post |
| `/economy/seal/user` | POST | Give seal(s) directly to a user |

---

## 13. Future Considerations

### 13.1 Potential Enhancements
- **Blockchain Integration**: Export ledger entries to blockchain for transparency
- **Wallet Snapshots**: Periodic balance snapshots for faster balance queries
- **Transaction Reversals**: Support for refunds/chargebacks (requires new ledger entries)
- **Multi-Currency Wallets**: Support for additional currencies
- **Transaction Tags**: User-defined tags for personal budgeting

### 13.2 Scalability
- **Read Replicas**: Route transaction history queries to read replicas
- **Partitioning**: Partition `ledger_entries` by date for massive scale
- **Caching**: Cache wallet balances in Redis for high-traffic scenarios
- **Event Sourcing**: Publish ledger events to message queue for real-time updates

---

## Summary

The BrightBund economy system uses a **dual-table architecture**:

1. **`wallets`** table stores the **current state** (balances, versions)
2. **`ledger_entries`** table stores the **immutable transaction history**

Every financial operation is:
- **Atomic**: Wrapped in database transactions
- **Idempotent**: Protected by unique reference IDs
- **Auditable**: Logged in ledger_entries forever
- **Secure**: Protected by rate limits, cooldowns, and violation logging

The system supports:
- Two currencies (Silver Seal, Gold Seal)
- Multiple transaction types (daily accrual, P2P, IAP, tasks, referrals)
- Comprehensive anti-abuse measures
- Full transaction history with pagination and filtering
- Optimistic locking for concurrency safety

All amounts are stored as **integer centinels** to avoid floating-point errors, and the system is designed for horizontal scalability with proper indexing and query optimization.
