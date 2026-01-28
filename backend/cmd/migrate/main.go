package main

import (
	"log"
	"os"

	"github.com/brightbund-backend/internal/config"
	"github.com/brightbund-backend/internal/platform/database"
	"github.com/brightbund-backend/internal/platform/database/migrate"
	"github.com/joho/godotenv"
)

func main() {
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

	// Apply all pending SQL migrations from /migrations.
	if err := migrate.Run(db.DB, "migrations"); err != nil {
		log.Fatalf("migrations failed: %v", err)
	}

	log.Println("migrations applied successfully")
}
