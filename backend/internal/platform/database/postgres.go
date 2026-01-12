package database

import (
	"context"
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"
)

type Config struct {
	Host     string
	Port     int
	User     string
	Password string
	DBName    string
	SSLMode  string
}

type Database struct {
	*sqlx.DB
}

func New(cfg Config) (*Database, error) {
	dsn := fmt.Sprintf(
		"host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		cfg.Host, cfg.Port, cfg.User, cfg.Password, cfg.DBName, cfg.SSLMode,
	)

	//устанавливаем соединение
	db, err := sqlx.Connect("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to db %w", err)
	}

	// делаем коннекшн пул для базы данных
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)
	db.SetConnMaxIdleTime(10 * time.Minute)

	if err := verifyPostGIS(db); err != nil {
		return nil, fmt.Errorf("PostGIS verification failed: %w", err)
	}

	return &Database{DB: db}, nil
} 



//определяю POSTGIS для БД
func verifyPostGIS(db *sqlx.DB) error {
	var version string
	query := "SELECT PostGIS_Version();"
	if err := db.Get(&version, query); err != nil {
		return fmt.Errorf("POSTGIS problems with availibility of app: %w", err)
	}
	fmt.Printf("POSTGIS versdion: %s\n", version)
	return nil
}


func (db *Database)  HealthCheck(ctx context.Context) error {
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()

	return db.PingContext(ctx)
}

func (db *Database) Close() error {
	return db.DB.Close()
}