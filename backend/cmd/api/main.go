package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/brightbund-backend/internal/config"
	"github.com/brightbund-backend/internal/modules/auth"
	"github.com/brightbund-backend/internal/platform/cache"
	"github.com/brightbund-backend/internal/platform/database"
	"github.com/brightbund-backend/internal/server"
)

func main() {
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

	redisCache, err := cache.New(cache.Config{
		Address:      cfg.Redis.Address,
		Password:     cfg.Redis.Password,
		DB:           cfg.Redis.DB,
		PoolSize:     cfg.Redis.PoolSize,
		MinIdleConns: cfg.Redis.MinIdleConns,
	})
	if err != nil {
		log.Fatalf("failed to connect to redis: %v", err)
	}
	defer redisCache.Close()

	if err := db.HealthCheck(context.Background()); err != nil {
		log.Fatalf("db health check failed: %v", err)
	}
	if err := redisCache.HealthCheck(context.Background()); err != nil {
		log.Fatalf("redis health check failed: %v", err)
	}

	appleVerifier, err := auth.NewOIDCVerifier(auth.ProviderApple, cfg.OAuth.Apple.Issuer, cfg.OAuth.Apple.ClientID)
	if err != nil {
		log.Fatalf("apple verifier init failed: %v", err)
	}
	googleVerifier, err := auth.NewOIDCVerifier(auth.ProviderGoogle, cfg.OAuth.Google.Issuer, cfg.OAuth.Google.ClientID)
	if err != nil {
		log.Fatalf("google verifier init failed: %v", err)
	}

	jwtManager := auth.NewJWTManager(cfg.JWT.Secret, cfg.JWT.Expiration, cfg.JWT.RefreshExpiration)
	authRepo := auth.NewRepository(db.DB)
	authService := auth.NewService(authRepo, jwtManager, map[auth.ProviderType]auth.OAuthVerifier{
		auth.ProviderApple:  appleVerifier,
		auth.ProviderGoogle: googleVerifier,
	})
	authHandler := auth.NewHandler(authService)

	app := server.New(cfg, authHandler, jwtManager)

	addr := fmt.Sprintf(":%d", cfg.Server.Port)
	log.Printf("server starting on %s", addr)
	if err := app.Listen(addr); err != nil {
		log.Fatalf("server stopped: %v", err)
	}
}
