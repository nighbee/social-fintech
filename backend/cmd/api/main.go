package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/brightbund-backend/internal/config"
	"github.com/brightbund-backend/internal/modules/auth"
	"github.com/brightbund-backend/internal/modules/economy"
	mapmodule "github.com/brightbund-backend/internal/modules/map"
	"github.com/brightbund-backend/internal/modules/profiles"
	"github.com/brightbund-backend/internal/modules/ranks"
	"github.com/brightbund-backend/internal/platform/cache"
	"github.com/brightbund-backend/internal/platform/database"
	"github.com/brightbund-backend/internal/platform/logger"
	"github.com/brightbund-backend/internal/platform/storage"
	"github.com/brightbund-backend/internal/server"
	"github.com/joho/godotenv"
	"go.uber.org/zap"
)

// @title BrightBund API
// @version 1.0
// @description API for the BrightBund social platform with economy, maps, chat, and gamification
// @termsOfService https://brightbund.com/terms

// @contact.name API Support
// @contact.email support@brightbund.com

// @license.name Proprietary
// @license.url https://brightbund.com/license

// @host localhost:8081
// @BasePath /api/v1

// @securityDefinitions.apikey Bearer
// @in header
// @name Authorization
// @description Type "Bearer" followed by a space and your JWT Access Token (not UUID). Example: "Bearer eyJhbGci..."

func main() {
	// загружает конфиг, подключает бд и инит OAuth jwt
	_ = godotenv.Load(".env")

	configPath := os.Getenv("CONFIG_PATH")
	if configPath == "" {
		configPath = "config.yaml"
	}

	cfg, err := config.Load(configPath)
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	// Инициализация структурированного логирования (Zap)
	if err := logger.Initialize(cfg.Logging); err != nil {
		log.Fatalf("failed to initialize logger: %v", err)
	}
	defer logger.Sync()

	logger.Info("starting BrightBund API server",
		zap.String("environment", cfg.Server.Environment),
		zap.Int("port", cfg.Server.Port),
	)

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
		logger.Fatal("failed to connect to database", zap.Error(err))
	}
	defer db.Close()

	logger.Info("database connection established",
		zap.String("host", cfg.Database.Host),
		zap.Int("port", cfg.Database.Port),
		zap.String("database", cfg.Database.Name),
	)

	redisCache, err := cache.New(cache.Config{
		Address:      cfg.Redis.Address,
		Password:     cfg.Redis.Password,
		DB:           cfg.Redis.DB,
		PoolSize:     cfg.Redis.PoolSize,
		MinIdleConns: cfg.Redis.MinIdleConns,
	})
	if err != nil {
		logger.Fatal("failed to connect to redis", zap.Error(err))
	}
	defer redisCache.Close()

	logger.Info("redis connection established", zap.String("address", cfg.Redis.Address))

	if err := db.HealthCheck(context.Background()); err != nil {
		logger.Fatal("db health check failed", zap.Error(err))
	}
	if err := redisCache.HealthCheck(context.Background()); err != nil {
		logger.Fatal("redis health check failed", zap.Error(err))
	}

	logger.Info("health checks passed")

	verifiers := make(map[auth.ProviderType]auth.OAuthVerifier)

	appleVerifier, err := auth.NewOIDCVerifier(auth.ProviderApple, cfg.OAuth.Apple.Issuer, cfg.OAuth.Apple.ClientID)
	if err != nil {
		logger.Warn("apple verifier init failed (OAuth login disabled)", zap.Error(err))
	} else {
		verifiers[auth.ProviderApple] = appleVerifier
		logger.Info("Apple OAuth verifier initialized")
	}

	googleVerifier, err := auth.NewOIDCVerifier(auth.ProviderGoogle, cfg.OAuth.Google.Issuer, cfg.OAuth.Google.ClientID)
	if err != nil {
		logger.Warn("google verifier init failed (OAuth login disabled)", zap.Error(err))
	} else {
		verifiers[auth.ProviderGoogle] = googleVerifier
		logger.Info("Google OAuth verifier initialized")
	}

	jwtManager := auth.NewJWTManager(cfg.JWT.Secret, cfg.JWT.Expiration, cfg.JWT.RefreshExpiration)
	authRepo := auth.NewRepository(db.DB)

	// Initialize profile stats cache if caching is enabled
	var profilesCache profiles.StatsCache
	if cfg.Cache.Enabled {
		profilesCache = profiles.NewCacheWrapperStatsCache(redisCache)
		logger.Info("profile stats cache enabled",
			zap.Duration("ttl", cfg.Cache.ProfileStatsTTL),
		)
	}

	// Initialize economy module with cache invalidator
	economyRepo := economy.NewRepository(db.DB)
	economyService := economy.NewService(economyRepo, cfg.Economy, profilesCache)
	economyHandler := economy.NewHandler(economyService)
	logger.Info("economy module initialized")

	var smsSender auth.SMSSender
	if cfg.Firebase.Enabled {
		firebaseSender, err := auth.NewFirebaseSMSSender(context.Background(), cfg.Firebase.CredentialsPath)
		if err != nil {
			logger.Fatal("firebase SMS sender init failed", zap.Error(err))
		}
		smsSender = firebaseSender
		logger.Info("Firebase SMS sender initialized", zap.String("project_id", cfg.Firebase.ProjectID))
	} else {
		smsSender = auth.NewNoopSMSSender()
		logger.Info("Using NoopSMSSender (development mode - OTP codes logged to console)")
	}

	authService := auth.NewService(authRepo, jwtManager, map[auth.ProviderType]auth.OAuthVerifier{
		auth.ProviderApple:  appleVerifier,
		auth.ProviderGoogle: googleVerifier,
	}, smsSender, economyService)

	authHandler := auth.NewHandler(authService)

	if err := authService.EnsureAdmins(context.Background(), cfg.Admin.Emails); err != nil {
		logger.Error("failed to seed admins", zap.Error(err))
	}

	logger.Info("auth module initialized")

	var storageClient profiles.ObjectStorage
	if cfg.Storage.Endpoint != "" {
		minioClient, err := storage.NewMinioClient(cfg.Storage)
		if err != nil {
			logger.Warn("failed to initialize storage client, avatar uploads will be disabled", zap.Error(err))
		}
		storageClient = minioClient
		logger.Info("storage client initialized", zap.String("endpoint", cfg.Storage.Endpoint))
	}

	profilesRepo := profiles.NewRepository(db.DB)
	profilesService := profiles.NewService(profilesRepo, storageClient, profilesCache)

	ranksRepo := ranks.NewRepository(db.DB)
	ranksService := ranks.NewService(ranksRepo)
	logger.Info("ranks module initialized")

	profilesHandler := profiles.NewHandler(profilesService, ranksService)
	logger.Info("profiles module initialized")

	mapRepo := mapmodule.NewRepository(db.DB)
	mapService := mapmodule.NewService(mapRepo, economyRepo, redisCache)
	mapHandler := mapmodule.NewHandler(mapService)
	logger.Info("map module initialized")

	economyWorker := economy.NewWorker(economyService, economyRepo, cfg.Economy)
	economyWorker.Start()
	defer economyWorker.Stop()
	logger.Info("economy worker started")

	mapWorker := mapmodule.NewWorker(redisCache, mapRepo)
	mapWorker.Start()
	defer mapWorker.Stop()
	logger.Info("map worker started")

	app := server.New(cfg, authHandler, economyHandler, profilesHandler, mapHandler, jwtManager, authRepo, logger.Get())

	addr := fmt.Sprintf(":%d", cfg.Server.Port)
	logger.Info("server starting", zap.String("address", addr))

	if err := app.Listen(addr); err != nil {
		logger.Fatal("server stopped", zap.Error(err))
	}
}
