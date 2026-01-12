package database

import (
	"context"
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
)

type Config struct {
	Host            string
	Port            int
	User            string
	Password        string
	DBName          string
	SSLMode         string
	MaxOpenConns    int
	MaxIdleConns    int
	ConnMaxLifetime time.Duration
}

type Database struct {
	*sqlx.DB
}

func New(cfg Config) (*Database, error) {

	fmt.Println("🔍 DATABASE CONFIG:")
	fmt.Println("HOST:", cfg.Host)
	fmt.Println("PORT:", cfg.Port)
	fmt.Println("USER:", cfg.User)
	fmt.Println("PASSWORD:", cfg.Password)
	fmt.Println("DB:", cfg.DBName)
	fmt.Println("SSLMODE:", cfg.SSLMode)

	dsn := fmt.Sprintf(
		"host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		cfg.Host, cfg.Port, cfg.User, cfg.Password, cfg.DBName, cfg.SSLMode,
	)

	db, err := sqlx.Connect("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %w", err)
	}

	// коннекшн пул сразу настраиваем чтобы не было траблов со стороны одного юзера
	db.SetMaxOpenConns(cfg.MaxOpenConns)
	db.SetMaxIdleConns(cfg.MaxIdleConns)
	db.SetConnMaxLifetime(cfg.ConnMaxLifetime)
	db.SetConnMaxIdleTime(10 * time.Minute)

	// на будущее веркификация POSTGIS для проекта
	if err := verifyPostGIS(db); err != nil {
		return nil, fmt.Errorf("PostGIS verification failed: %w", err)
	}

	return &Database{DB: db}, nil
}

func verifyPostGIS(db *sqlx.DB) error {
	var version string
	query := "SELECT PostGIS_Version();"
	if err := db.Get(&version, query); err != nil {
		return fmt.Errorf("PostGIS not available: %w", err)
	}
	fmt.Printf("✅ PostGIS version: %s\n", version)
	return nil
}

func (db *Database) HealthCheck(ctx context.Context) error {
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()

	return db.PingContext(ctx)
}

func (db *Database) Close() error {
	return db.DB.Close()
}