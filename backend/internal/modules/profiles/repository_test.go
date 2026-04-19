package profiles

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/brightbund-backend/internal/platform/database/migrate"
	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
)

var testDB *sqlx.DB

func TestMain(m *testing.M) {
	dsn, ok := buildTestDSN()
	if !ok {
		fmt.Println("profiles tests skipped: TEST_DB_DSN or DB_* env not set")
		os.Exit(0)
	}

	db, err := sqlx.Connect("postgres", dsn)
	if err != nil {
		fmt.Printf("profiles tests skipped: db connect failed: %v\n", err)
		os.Exit(0)
	}

	migrationsDir, err := findMigrationsDir()
	if err != nil {
		fmt.Printf("profiles tests skipped: migrations dir not found: %v\n", err)
		_ = db.Close()
		os.Exit(0)
	}

	if err := migrate.Run(db, migrationsDir); err != nil {
		fmt.Printf("profiles tests skipped: migrations failed: %v\n", err)
		_ = db.Close()
		os.Exit(0)
	}

	testDB = db
	code := m.Run()
	_ = db.Close()
	os.Exit(code)
}

func TestSearchUsersByName(t *testing.T) {
	if testDB == nil {
		t.Skip("no test db")
	}

	ctx := context.Background()
	repo := NewRepository(testDB)

	users := []struct {
		id        string
		username  string
		firstName string
		lastName  string
		shadow    bool
	}{
		{id: uuid.NewString(), username: "captainbright", firstName: "Alice", lastName: "Wonderland", shadow: false},
		{id: uuid.NewString(), username: "alice_smith", firstName: "Alice", lastName: "Smith", shadow: false},
		{id: uuid.NewString(), username: "bob_wonder", firstName: "Bob", lastName: "Wonderland", shadow: false},
		{id: uuid.NewString(), username: "alice_shadow", firstName: "Alice", lastName: "Shadow", shadow: true},
	}

	// Insert users + profiles
	for idx, u := range users {
		_, err := testDB.ExecContext(ctx, `
			INSERT INTO users (
				id, email, username, first_name, last_name, is_shadow_banned,
				created_at, updated_at, last_active_at
			) VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW(), NOW())
		`, u.id, fmt.Sprintf("%s.%s@example.com", strings.ToLower(u.firstName), strings.ToLower(u.lastName)),
			u.username,
			u.firstName, u.lastName, u.shadow)
		if err != nil {
			t.Fatalf("insert user failed: %v", err)
		}

		displayName := u.firstName + " " + u.lastName
		if idx == 0 {
			displayName = "captainbright"
		}

		_, err = testDB.ExecContext(ctx, `
			INSERT INTO profiles (
				user_id, display_name, avatar_url, is_profile_public, created_at, updated_at
			) VALUES ($1, $2, $3, true, NOW(), NOW())
			ON CONFLICT (user_id) DO NOTHING
		`, u.id, displayName, "https://example.com/avatars/"+u.id+".jpg")
		if err != nil {
			t.Fatalf("insert profile failed: %v", err)
		}
	}

	// Cleanup
	t.Cleanup(func() {
		for _, u := range users {
			_, _ = testDB.ExecContext(ctx, `DELETE FROM profiles WHERE user_id = $1`, u.id)
			_, _ = testDB.ExecContext(ctx, `DELETE FROM users WHERE id = $1`, u.id)
		}
	})

	// Exact match on first + last
	res, err := repo.SearchUsersByName(ctx, "Ali", "Won", 20)
	if err != nil {
		t.Fatalf("search failed: %v", err)
	}
	if len(res) != 1 {
		t.Fatalf("expected 1 result, got %d", len(res))
	}
	if res[0].FirstName != "Alice" || res[0].LastName != "Wonderland" {
		t.Fatalf("unexpected result: %+v", res[0])
	}

	// First name only (lastName empty -> wildcard)
	res, err = repo.SearchUsersByName(ctx, "Ali", "", 20)
	if err != nil {
		t.Fatalf("search failed: %v", err)
	}
	if len(res) != 2 {
		t.Fatalf("expected 2 results (shadow user excluded), got %d", len(res))
	}

	res, err = repo.SearchUsersByName(ctx, "captain", "", 20)
	if err != nil {
		t.Fatalf("nickname search failed: %v", err)
	}
	if len(res) != 1 {
		t.Fatalf("expected 1 result for nickname search, got %d", len(res))
	}
	if res[0].Username != "captainbright" {
		t.Fatalf("unexpected nickname result: %+v", res[0])
	}
}

func buildTestDSN() (string, bool) {
	if dsn := os.Getenv("TEST_DB_DSN"); dsn != "" {
		return dsn, true
	}

	// Docker compose default for this repo: db exposed on localhost:5434
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
