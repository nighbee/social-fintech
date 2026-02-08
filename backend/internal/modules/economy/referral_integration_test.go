package economy

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"

	"github.com/brightbund-backend/internal/config"
	"github.com/brightbund-backend/internal/platform/database/migrate"
	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
)

func TestProcessReferralBonus_WritesLedgerAndWallet(t *testing.T) {
	db := openTestDB(t)
	defer db.Close()

	ctx := context.Background()

	referrerID := uuid.NewString()
	refereeID := uuid.NewString()

	if err := insertTestUser(ctx, db, referrerID, "Ref", "Owner"); err != nil {
		t.Fatalf("insert referrer failed: %v", err)
	}
	if err := insertTestUser(ctx, db, refereeID, "Ref", "Friend"); err != nil {
		t.Fatalf("insert referee failed: %v", err)
	}

	t.Cleanup(func() {
		_, _ = db.ExecContext(ctx, `DELETE FROM referrals WHERE referrer_user_id = $1 OR referee_user_id = $1`, referrerID)
		_, _ = db.ExecContext(ctx, `DELETE FROM referrals WHERE referrer_user_id = $1 OR referee_user_id = $1`, refereeID)
		_, _ = db.ExecContext(ctx, `DELETE FROM ledger_entries WHERE reference_id = $1`, fmt.Sprintf("referral_%s_%s", referrerID, refereeID))
		_, _ = db.ExecContext(ctx, `DELETE FROM wallets WHERE user_id IN ($1, $2)`, referrerID, refereeID)
		_, _ = db.ExecContext(ctx, `DELETE FROM users WHERE id IN ($1, $2)`, referrerID, refereeID)
	})

	repo := NewRepository(db)
	cfg := config.EconomyConfig{
		ReferralBonusCents: 100,
	}
	svc := NewService(repo, cfg)

	if err := svc.ProcessReferralBonus(ctx, referrerID, refereeID); err != nil {
		t.Fatalf("ProcessReferralBonus failed: %v", err)
	}

	// Wallet balance updated
	var balance int64
	err := db.GetContext(ctx, &balance, `
		SELECT balance FROM wallets
		WHERE user_id = $1 AND currency = 'SILVER_SEAL'
	`, referrerID)
	if err != nil {
		t.Fatalf("wallet fetch failed: %v", err)
	}
	if balance != cfg.ReferralBonusCents {
		t.Fatalf("expected referrer balance %d, got %d", cfg.ReferralBonusCents, balance)
	}

	// Ledger entry exists with correct receiver and category
	refID := fmt.Sprintf("referral_%s_%s", referrerID, refereeID)
	type entryRow struct {
		ID               string `db:"id"`
		Amount           int64  `db:"amount"`
		Category         string `db:"category"`
		ReceiverWalletID string `db:"receiver_wallet_id"`
	}
	var entry entryRow
	err = db.GetContext(ctx, &entry, `
		SELECT id, amount, category, receiver_wallet_id
		FROM ledger_entries
		WHERE reference_id = $1
	`, refID)
	if err != nil {
		t.Fatalf("ledger entry not found: %v", err)
	}
	if entry.Amount != cfg.ReferralBonusCents {
		t.Fatalf("expected ledger amount %d, got %d", cfg.ReferralBonusCents, entry.Amount)
	}
	if entry.Category != string(CategoryReferralBonus) {
		t.Fatalf("expected category %s, got %s", CategoryReferralBonus, entry.Category)
	}

	// Referral row exists and points to ledger entry
	type referralRow struct {
		ID                 string `db:"id"`
		BonusLedgerEntryID string `db:"bonus_ledger_entry_id"`
	}
	var ref referralRow
	err = db.GetContext(ctx, &ref, `
		SELECT id, bonus_ledger_entry_id
		FROM referrals
		WHERE referrer_user_id = $1 AND referee_user_id = $2
	`, referrerID, refereeID)
	if err != nil {
		t.Fatalf("referral row not found: %v", err)
	}
	if ref.BonusLedgerEntryID != entry.ID {
		t.Fatalf("expected referral.bonus_ledger_entry_id = %s, got %s", entry.ID, ref.BonusLedgerEntryID)
	}
}

func openTestDB(t *testing.T) *sqlx.DB {
	t.Helper()

	dsn, ok := buildTestDSN()
	if !ok {
		t.Skip("TEST_DB_DSN or DB_* not set")
	}

	db, err := sqlx.Connect("postgres", dsn)
	if err != nil {
		t.Skipf("db connect failed: %v", err)
	}

	migrationsDir, err := findMigrationsDir()
	if err != nil {
		t.Skipf("migrations dir not found: %v", err)
	}
	if err := migrate.Run(db, migrationsDir); err != nil {
		t.Skipf("migrations failed: %v", err)
	}

	return db
}

func insertTestUser(ctx context.Context, db *sqlx.DB, id, first, last string) error {
	username := "u_" + strings.ReplaceAll(id, "-", "")[:12]
	email := fmt.Sprintf("%s.%s@ref.test", strings.ToLower(first), strings.ToLower(last))
	_, err := db.ExecContext(ctx, `
		INSERT INTO users (
			id, email, username, first_name, last_name, is_shadow_banned,
			created_at, updated_at, last_active_at
		) VALUES ($1, $2, $3, $4, $5, false, NOW(), NOW(), NOW())
	`, id, email, username, first, last)
	return err
}

func buildTestDSN() (string, bool) {
	if dsn := os.Getenv("TEST_DB_DSN"); dsn != "" {
		return dsn, true
	}

	host := getenvDefault("DB_HOST", "localhost")
	port := getenvDefault("DB_PORT", "5434")
	user := getenvDefault("DB_USER", "user")
	pass := getenvDefault("DB_PASSWORD", "password")
	name := getenvDefault("DB_NAME", "brightbund")
	ssl := getenvDefault("DB_SSLMODE", "disable")

	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		host, port, user, pass, name, ssl)
	return dsn, true
}

func getenvDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func findMigrationsDir() (string, error) {
	_, thisFile, _, ok := runtime.Caller(0)
	if !ok {
		return "", fmt.Errorf("cannot locate test file")
	}

	dir := filepath.Dir(thisFile)
	for i := 0; i < 6; i++ {
		candidate := filepath.Join(dir, "..", "..", "..", "..", "migrations")
		candidate = filepath.Clean(candidate)
		if stat, err := os.Stat(candidate); err == nil && stat.IsDir() {
			return candidate, nil
		}
		dir = filepath.Dir(dir)
	}
	return "", fmt.Errorf("migrations dir not found")
}

// tiny helper to silence unused import warning in case of future edits
var _ = time.Now
