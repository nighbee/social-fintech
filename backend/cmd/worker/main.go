package main

import (
	"log"
	"os"
	"os/signal"
	"sync"
	"syscall"

	"github.com/brightbund-backend/internal/config"
	"github.com/brightbund-backend/internal/modules/economy"
	"github.com/brightbund-backend/internal/modules/feed"
	mapmodule "github.com/brightbund-backend/internal/modules/map"
	"github.com/brightbund-backend/internal/modules/profiles"
	"github.com/brightbund-backend/internal/modules/settings"
	"github.com/brightbund-backend/internal/platform/cache"
	"github.com/brightbund-backend/internal/platform/database"
	"github.com/brightbund-backend/internal/platform/logger"
	"github.com/joho/godotenv"
	"go.uber.org/zap"
)

func main() {
	_ = godotenv.Load(".env")

	configPath := os.Getenv("CONFIG_PATH")
	if configPath == "" {
		configPath = "config.yaml"
	}

	cfg, err := config.Load(configPath)
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	if err := logger.Initialize(cfg.Logging); err != nil {
		log.Fatalf("failed to initialize logger: %v", err)
	}
	defer logger.Sync()

	logger.Info("starting BrightBund Background Workers")

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

	var profilesCache profiles.StatsCache
	if cfg.Cache.Enabled {
		profilesCache = profiles.NewCacheWrapperStatsCache(redisCache)
	}

	economyRepo := economy.NewRepository(db.DB)
	economyService := economy.NewService(economyRepo, cfg.Economy, profilesCache)
	economyWorker := economy.NewWorker(economyService, economyRepo, cfg.Economy)

	mapRepo := mapmodule.NewRepository(db.DB)
	mapWorker := mapmodule.NewWorker(redisCache, mapRepo, economyRepo)

	feedRepo := feed.NewRepository(db.DB, cfg.Storage.PublicURL)
	feedWorker := feed.NewInteractionWorker(redisCache, feedRepo)

	settingsRepo := settings.NewRepository(db.DB)
	settingsService := settings.NewService(settingsRepo, nil)
	settingsHardDeleteWorker := settings.NewHardDeleteWorker(settingsService)

	// Start workers
	economyWorker.Start()
	logger.Info("economy worker started")

	mapWorker.Start()
	logger.Info("map worker started")

	feedWorker.Start()
	logger.Info("feed interaction worker started")

	settingsHardDeleteWorker.Start()
	logger.Info("settings hard-delete worker started")

	// Wait for shutdown signals
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)

	<-sigCh
	logger.Info("shutting down workers...")

	var wg sync.WaitGroup
	wg.Add(4)

	go func() {
		defer wg.Done()
		economyWorker.Stop()
		logger.Info("economy worker stopped")
	}()

	go func() {
		defer wg.Done()
		mapWorker.Stop()
		logger.Info("map worker stopped")
	}()

	go func() {
		defer wg.Done()
		feedWorker.Stop()
		logger.Info("feed interaction worker stopped")
	}()

	go func() {
		defer wg.Done()
		settingsHardDeleteWorker.Stop()
		logger.Info("settings hard-delete worker stopped")
	}()

	wg.Wait()
	logger.Info("shutdown complete")
}
