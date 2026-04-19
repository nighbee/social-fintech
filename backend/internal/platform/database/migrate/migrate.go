package migrate

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/jmoiron/sqlx"
)

func Run(db *sqlx.DB, migrationsDir string) error {
	if err := ensureSchemaMigrations(db); err != nil {
		return err
	}

	files, err := listSQLFiles(migrationsDir)
	if err != nil {
		return err
	}

	applied, err := appliedMigrations(db)
	if err != nil {
		return err
	}

	// Bootstrap: schema_migrations is empty but DB already has user tables,
	// meaning it was seeded via docker-entrypoint-initdb.d before this migrate
	// tool existed. Mark all files as applied so we don't re-run them.
	if len(applied) == 0 && dbHasUserTables(db) {
		for _, file := range files {
			_, err := db.Exec(
				`INSERT INTO schema_migrations (filename) VALUES ($1) ON CONFLICT DO NOTHING`,
				file,
			)
			if err != nil {
				return fmt.Errorf("bootstrap record %s: %w", file, err)
			}
		}
		fmt.Printf("bootstrap: marked %d existing migrations as applied\n", len(files))
		return nil
	}

	for _, file := range files {
		if applied[file] {
			continue
		}

		sqlBytes, err := os.ReadFile(file)
		if err != nil {
			return fmt.Errorf("read %s: %w", file, err)
		}

		if err := applyMigration(db, file, string(sqlBytes)); err != nil {
			return err
		}
	}

	return nil
}

func ensureSchemaMigrations(db *sqlx.DB) error {
	_, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS schema_migrations (
			filename   TEXT PRIMARY KEY,
			applied_at TIMESTAMP NOT NULL DEFAULT NOW()
		)
	`)
	return err
}

// dbHasUserTables returns true when the database was already bootstrapped
// via docker-entrypoint-initdb.d (checking for the wallets table).
func dbHasUserTables(db *sqlx.DB) bool {
	var exists bool
	_ = db.QueryRow(`
		SELECT EXISTS (
			SELECT 1 FROM information_schema.tables
			WHERE table_schema = 'public' AND table_name = 'wallets'
		)
	`).Scan(&exists)
	return exists
}

func listSQLFiles(dir string) ([]string, error) {
	var files []string
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		name := e.Name()
		if strings.HasSuffix(name, ".sql") {
			files = append(files, filepath.Join(dir, name))
		}
	}
	sort.Strings(files)
	return files, nil
}

func appliedMigrations(db *sqlx.DB) (map[string]bool, error) {
	rows, err := db.Queryx(`SELECT filename FROM schema_migrations`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	applied := make(map[string]bool)
	for rows.Next() {
		var filename string
		if err := rows.Scan(&filename); err != nil {
			return nil, err
		}
		applied[filename] = true
	}
	return applied, nil
}

func applyMigration(db *sqlx.DB, filename, sqlText string) error {
	// Some historical migration files contain explicit BEGIN/COMMIT blocks.
	// Running those inside an outer Go tx causes nested transaction issues
	// (e.g. "unexpected transaction status idle").
	if hasExplicitTransactionControl(sqlText) {
		if _, err := db.Exec(sqlText); err != nil {
			return fmt.Errorf("apply %s: %w", filename, err)
		}
		if _, err := db.Exec(`INSERT INTO schema_migrations (filename) VALUES ($1)`, filename); err != nil {
			return fmt.Errorf("record %s: %w", filename, err)
		}
		return nil
	}

	tx, err := db.Beginx()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if _, err := tx.Exec(sqlText); err != nil {
		return fmt.Errorf("apply %s: %w", filename, err)
	}

	if _, err := tx.Exec(`INSERT INTO schema_migrations (filename) VALUES ($1)`, filename); err != nil {
		return fmt.Errorf("record %s: %w", filename, err)
	}

	return tx.Commit()
}

func hasExplicitTransactionControl(sqlText string) bool {
	upper := strings.ToUpper(sqlText)
	return strings.Contains(upper, "\nBEGIN;") ||
		strings.Contains(upper, "\nCOMMIT;") ||
		strings.Contains(upper, "\nROLLBACK;")
}
