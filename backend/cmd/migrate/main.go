package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/brightbund-backend/internal/config"
	"github.com/brightbund-backend/internal/platform/database"
	"github.com/brightbund-backend/internal/platform/database/migrate"
	"github.com/jmoiron/sqlx"
	"github.com/joho/godotenv"
)

func main() {
	mode := flag.String("mode", "migrate", "mode: migrate | backfill-gold-weekly | reconcile-gold-weekly | backfill-gold-seasonal | reconcile-gold-seasonal")
	weeks := flag.Int("weeks", 12, "number of trailing ISO weeks for backfill/reconciliation")
	flag.Parse()

	// Load .env if present (dev convenience).
	_ = godotenv.Load(".env")

	configPath := os.Getenv("CONFIG_PATH")
	if configPath == "" {
		configPath = "config.yaml"
	}

	cfg, err := config.Load(configPath)
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	db, err := database.New(database.Config{
		Host:            cfg.Database.Host,
		Port:            cfg.Database.Port,
		User:            cfg.Database.User,
		Password:        cfg.Database.Password,
		DBName:          cfg.Database.Name,
		SSLMode:         cfg.Database.SSLMode,
		MaxOpenConns:    cfg.Database.MaxOpenConns,
		MaxIdleConns:    cfg.Database.MaxIdleConns,
		ConnMaxLifetime: cfg.Database.ConnMaxLifetime,
	})
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}
	defer db.Close()

	switch strings.ToLower(*mode) {
	case "migrate":
		// Apply all pending SQL migrations from /migrations.
		if err := migrate.Run(db.DB, "migrations"); err != nil {
			log.Fatalf("migrations failed: %v", err)
		}
		log.Println("migrations applied successfully")
	case "backfill-gold-weekly":
		if err := backfillGoldWeekly(db.DB, *weeks); err != nil {
			log.Fatalf("gold weekly backfill failed: %v", err)
		}
		log.Printf("gold weekly backfill completed for last %d week(s)\n", *weeks)
	case "reconcile-gold-weekly":
		if err := reconcileGoldWeekly(db.DB, *weeks); err != nil {
			log.Fatalf("gold weekly reconciliation failed: %v", err)
		}
	case "backfill-gold-seasonal":
		if err := backfillGoldSeasonal(db.DB, *weeks); err != nil {
			log.Fatalf("gold seasonal backfill failed: %v", err)
		}
		log.Printf("gold seasonal backfill completed for trailing window of %d week(s)\n", *weeks)
	case "reconcile-gold-seasonal":
		if err := reconcileGoldSeasonal(db.DB, *weeks); err != nil {
			log.Fatalf("gold seasonal reconciliation failed: %v", err)
		}
	default:
		log.Fatalf("unknown mode: %s", *mode)
	}
}

func backfillGoldWeekly(db *sqlx.DB, weeks int) error {
	if weeks <= 0 {
		weeks = 12
	}

	query := `
		INSERT INTO gold_reputation_period_stats (
			user_id, period_type, period_year, period_week, gold_received_centinels, computed_at
		)
		SELECT
			wr.user_id,
			'weekly' AS period_type,
			EXTRACT(isoyear FROM le.created_at)::int AS period_year,
			EXTRACT(week FROM le.created_at)::int AS period_week,
			SUM(le.amount)::bigint AS gold_received_centinels,
			NOW() AS computed_at
		FROM ledger_entries le
		JOIN wallets wr ON wr.id = le.receiver_wallet_id
		WHERE le.currency = 'GOLD_SEAL'
		  AND le.receiver_wallet_id IS NOT NULL
		  AND COALESCE(le.metadata->>'entry_role', '') = 'gold_credit'
		  AND le.created_at >= date_trunc('week', NOW()) - ($1::int * interval '1 week')
		GROUP BY
			wr.user_id,
			EXTRACT(isoyear FROM le.created_at)::int,
			EXTRACT(week FROM le.created_at)::int
		ON CONFLICT (user_id, period_type, period_year, period_week)
		DO UPDATE SET
			gold_received_centinels = EXCLUDED.gold_received_centinels,
			computed_at = NOW()
	`

	res, err := db.Exec(query, weeks)
	if err != nil {
		return fmt.Errorf("failed to execute backfill query: %w", err)
	}

	if affected, err := res.RowsAffected(); err == nil {
		log.Printf("gold weekly backfill rows affected: %d\n", affected)
	}

	return nil
}

func reconcileGoldWeekly(db *sqlx.DB, weeks int) error {
	if weeks <= 0 {
		weeks = 12
	}

	rows, err := db.Queryx(`
		WITH ledger AS (
			SELECT
				wr.user_id::text AS user_id,
				EXTRACT(isoyear FROM le.created_at)::int AS period_year,
				EXTRACT(week FROM le.created_at)::int AS period_week,
				SUM(le.amount)::bigint AS amount
			FROM ledger_entries le
			JOIN wallets wr ON wr.id = le.receiver_wallet_id
			WHERE le.currency = 'GOLD_SEAL'
			  AND le.receiver_wallet_id IS NOT NULL
			  AND COALESCE(le.metadata->>'entry_role', '') = 'gold_credit'
			  AND le.created_at >= date_trunc('week', NOW()) - ($1::int * interval '1 week')
			GROUP BY wr.user_id::text, EXTRACT(isoyear FROM le.created_at)::int, EXTRACT(week FROM le.created_at)::int
		),
		stats AS (
			SELECT
				user_id::text AS user_id,
				period_year,
				period_week,
				gold_received_centinels AS amount
			FROM gold_reputation_period_stats
			WHERE period_type = 'weekly'
			  AND make_date(period_year, 1, 4) + ((period_week - 1) * interval '1 week') >= date_trunc('week', NOW()) - ($1::int * interval '1 week')
		)
		SELECT
			COALESCE(l.user_id, s.user_id) AS user_id,
			COALESCE(l.period_year, s.period_year) AS period_year,
			COALESCE(l.period_week, s.period_week) AS period_week,
			COALESCE(l.amount, 0) AS ledger_amount,
			COALESCE(s.amount, 0) AS stats_amount,
			COALESCE(l.amount, 0) - COALESCE(s.amount, 0) AS diff
		FROM ledger l
		FULL OUTER JOIN stats s
		  ON l.user_id = s.user_id
		 AND l.period_year = s.period_year
		 AND l.period_week = s.period_week
		WHERE COALESCE(l.amount, 0) <> COALESCE(s.amount, 0)
		ORDER BY ABS(COALESCE(l.amount, 0) - COALESCE(s.amount, 0)) DESC, COALESCE(l.period_year, s.period_year) DESC, COALESCE(l.period_week, s.period_week) DESC
		LIMIT 100
	`, weeks)
	if err != nil {
		return fmt.Errorf("failed to execute reconciliation query: %w", err)
	}
	defer rows.Close()

	mismatches := 0
	for rows.Next() {
		var userID string
		var year, week int
		var ledgerAmount, statsAmount, diff int64
		if err := rows.Scan(&userID, &year, &week, &ledgerAmount, &statsAmount, &diff); err != nil {
			return fmt.Errorf("failed to scan reconciliation row: %w", err)
		}
		mismatches++
		log.Printf("reconcile mismatch user=%s year=%d week=%d ledger=%d stats=%d diff=%d\n", userID, year, week, ledgerAmount, statsAmount, diff)
	}

	if err := rows.Err(); err != nil {
		return fmt.Errorf("failed while iterating reconciliation rows: %w", err)
	}

	if mismatches == 0 {
		log.Printf("reconcile result: OK (no mismatches for last %d week(s))\n", weeks)
	} else {
		log.Printf("reconcile result: %d mismatch row(s) found for last %d week(s)\n", mismatches, weeks)
	}

	return nil
}

func backfillGoldSeasonal(db *sqlx.DB, weeks int) error {
	if weeks <= 0 {
		weeks = 12
	}

	query := `
		INSERT INTO gold_reputation_period_stats (
			user_id, period_type, period_year, period_week, gold_received_centinels, computed_at
		)
		SELECT
			wr.user_id,
			'seasonal' AS period_type,
			EXTRACT(year FROM le.created_at)::int AS period_year,
			EXTRACT(quarter FROM le.created_at)::int AS period_week,
			SUM(le.amount)::bigint AS gold_received_centinels,
			NOW() AS computed_at
		FROM ledger_entries le
		JOIN wallets wr ON wr.id = le.receiver_wallet_id
		WHERE le.currency = 'GOLD_SEAL'
		  AND le.receiver_wallet_id IS NOT NULL
		  AND COALESCE(le.metadata->>'entry_role', '') = 'gold_credit'
		  AND le.created_at >= date_trunc('week', NOW()) - ($1::int * interval '1 week')
		GROUP BY
			wr.user_id,
			EXTRACT(year FROM le.created_at)::int,
			EXTRACT(quarter FROM le.created_at)::int
		ON CONFLICT (user_id, period_type, period_year, period_week)
		DO UPDATE SET
			gold_received_centinels = EXCLUDED.gold_received_centinels,
			computed_at = NOW()
	`

	res, err := db.Exec(query, weeks)
	if err != nil {
		return fmt.Errorf("failed to execute seasonal backfill query: %w", err)
	}

	if affected, err := res.RowsAffected(); err == nil {
		log.Printf("gold seasonal backfill rows affected: %d\n", affected)
	}

	return nil
}

func reconcileGoldSeasonal(db *sqlx.DB, weeks int) error {
	if weeks <= 0 {
		weeks = 12
	}

	rows, err := db.Queryx(`
		WITH ledger AS (
			SELECT
				wr.user_id::text AS user_id,
				EXTRACT(year FROM le.created_at)::int AS period_year,
				EXTRACT(quarter FROM le.created_at)::int AS period_week,
				SUM(le.amount)::bigint AS amount
			FROM ledger_entries le
			JOIN wallets wr ON wr.id = le.receiver_wallet_id
			WHERE le.currency = 'GOLD_SEAL'
			  AND le.receiver_wallet_id IS NOT NULL
			  AND COALESCE(le.metadata->>'entry_role', '') = 'gold_credit'
			  AND le.created_at >= date_trunc('week', NOW()) - ($1::int * interval '1 week')
			GROUP BY wr.user_id::text, EXTRACT(year FROM le.created_at)::int, EXTRACT(quarter FROM le.created_at)::int
		),
		stats AS (
			SELECT
				user_id::text AS user_id,
				period_year,
				period_week,
				gold_received_centinels AS amount
			FROM gold_reputation_period_stats
			WHERE period_type = 'seasonal'
			  AND make_date(period_year, 1, 1) + ((period_week - 1) * interval '3 month') >= date_trunc('week', NOW()) - ($1::int * interval '1 week')
		)
		SELECT
			COALESCE(l.user_id, s.user_id) AS user_id,
			COALESCE(l.period_year, s.period_year) AS period_year,
			COALESCE(l.period_week, s.period_week) AS period_week,
			COALESCE(l.amount, 0) AS ledger_amount,
			COALESCE(s.amount, 0) AS stats_amount,
			COALESCE(l.amount, 0) - COALESCE(s.amount, 0) AS diff
		FROM ledger l
		FULL OUTER JOIN stats s
		  ON l.user_id = s.user_id
		 AND l.period_year = s.period_year
		 AND l.period_week = s.period_week
		WHERE COALESCE(l.amount, 0) <> COALESCE(s.amount, 0)
		ORDER BY ABS(COALESCE(l.amount, 0) - COALESCE(s.amount, 0)) DESC, COALESCE(l.period_year, s.period_year) DESC, COALESCE(l.period_week, s.period_week) DESC
		LIMIT 100
	`, weeks)
	if err != nil {
		return fmt.Errorf("failed to execute seasonal reconciliation query: %w", err)
	}
	defer rows.Close()

	mismatches := 0
	for rows.Next() {
		var userID string
		var year, season int
		var ledgerAmount, statsAmount, diff int64
		if err := rows.Scan(&userID, &year, &season, &ledgerAmount, &statsAmount, &diff); err != nil {
			return fmt.Errorf("failed to scan seasonal reconciliation row: %w", err)
		}
		mismatches++
		log.Printf("seasonal reconcile mismatch user=%s year=%d season=%d ledger=%d stats=%d diff=%d\n", userID, year, season, ledgerAmount, statsAmount, diff)
	}

	if err := rows.Err(); err != nil {
		return fmt.Errorf("failed while iterating seasonal reconciliation rows: %w", err)
	}

	if mismatches == 0 {
		log.Printf("seasonal reconcile result: OK (no mismatches for trailing window of %d week(s))\n", weeks)
	} else {
		log.Printf("seasonal reconcile result: %d mismatch row(s) found for trailing window of %d week(s)\n", mismatches, weeks)
	}

	return nil
}
