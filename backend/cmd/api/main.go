package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/brightbund-backend/internal/config"
	"github.com/brightbund-backend/internal/modules/auth"
	"github.com/brightbund-backend/internal/modules/chat"
	"github.com/brightbund-backend/internal/modules/economy"
	"github.com/brightbund-backend/internal/modules/feed"
	mapmodule "github.com/brightbund-backend/internal/modules/map"
	"github.com/brightbund-backend/internal/modules/notifications"
	"github.com/brightbund-backend/internal/modules/profiles"
	"github.com/brightbund-backend/internal/modules/seasons"
	"github.com/brightbund-backend/internal/modules/leaderboard"
	"github.com/brightbund-backend/internal/modules/ranks"
	"github.com/brightbund-backend/internal/modules/payment"
	"github.com/brightbund-backend/internal/modules/settings"
	"github.com/brightbund-backend/internal/platform/cache"
	"github.com/brightbund-backend/internal/platform/database"
	"github.com/brightbund-backend/internal/platform/database/migrate"
	"github.com/brightbund-backend/internal/platform/email"
	"github.com/brightbund-backend/internal/platform/logger"
	"github.com/brightbund-backend/internal/platform/storage"
	"github.com/brightbund-backend/internal/platform/vision"
	"github.com/brightbund-backend/internal/server"
	"github.com/google/uuid"
	"github.com/hibiken/asynq"
	"github.com/jmoiron/sqlx"
	"github.com/joho/godotenv"
	"github.com/brightbund-backend/internal/platform/eventbus"
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

// @BasePath /api/v1

// @securityDefinitions.apikey Bearer
// @in header
// @name Authorization
// @description Type "Bearer" followed by a space and your JWT Access Token (not UUID). Example: "Bearer eyJhbGci..."

func main() {
	// Р·Р°РіСЂСѓР¶Р°РµС‚ РєРѕРЅС„РёРі, РїРѕРґРєР»СЋС‡Р°РµС‚ Р±Рґ Рё РёРЅРёС‚ OAuth jwt
	_ = godotenv.Load(".env")

	configPath := os.Getenv("CONFIG_PATH")
	if configPath == "" {
		configPath = "config.yaml"
	}

	cfg, err := config.Load(configPath)
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	// РРЅРёС†РёР°Р»РёР·Р°С†РёСЏ СЃС‚СЂСѓРєС‚СѓСЂРёСЂРѕРІР°РЅРЅРѕРіРѕ Р»РѕРіРёСЂРѕРІР°РЅРёСЏ (Zap)
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

	if cfg.Server.AutoMigrate {
		if err := runStartupMigrations(db.DB); err != nil {
			logger.Fatal("auto migrations failed", zap.Error(err))
		}
		logger.Info("auto migrations applied successfully")
	}

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

	// Create Asynq client for background tasks (Video Processing)
	asynqClient := asynq.NewClient(asynq.RedisClientOpt{
		Addr:     cfg.Redis.Address,
		Password: cfg.Redis.Password,
		DB:       cfg.Redis.DB,
	})
	defer asynqClient.Close()
	logger.Info("asynq client initialized")

	if err := db.HealthCheck(context.Background()); err != nil {
		logger.Fatal("db health check failed", zap.Error(err))
	}
	if err := redisCache.HealthCheck(context.Background()); err != nil {
		logger.Fatal("redis health check failed", zap.Error(err))
	}

	logger.Info("health checks passed")

	var eventProducer *eventbus.Producer
	if cfg.EventBus.Enabled {
		eventProducer = eventbus.NewProducer(cfg.EventBus.Brokers, cfg.EventBus.Topics.SystemEvents, logger.Get())
		logger.Info("Kafka event bus producer initialized")
	}

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
	economyService := economy.NewService(economyRepo, cfg.Economy, profilesCache, eventProducer)
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

	// Wire the outbound email transport. Platform-level sender picks
	// SMTP when configured, otherwise a logging stub. Both auth and
	// settings consume it via tiny adapters so neither module depends
	// on the platform package directly.
	emailSender := email.NewSender(email.Config{
		Host:           cfg.SMTP.Host,
		Port:           cfg.SMTP.Port,
		Username:       cfg.SMTP.Username,
		Password:       cfg.SMTP.Password,
		FromAddress:    cfg.SMTP.FromAddress,
		FromName:       cfg.SMTP.FromName,
		UseStartTLS:    cfg.SMTP.UseStartTLS,
		UseImplicitTLS: cfg.SMTP.UseImplicitTLS,
	})
	authService.SetEmailSender(authEmailAdapter{sender: emailSender})
	authService.SetEventBus(eventProducer)

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

	mapRepo := mapmodule.NewRepository(db.DB)
	mapService := mapmodule.NewService(mapRepo, economyRepo, redisCache, eventProducer)

	profilesService := profiles.NewService(profilesRepo, storageClient, profilesCache, mapService)

	ranksRepo := ranks.NewRepository(db.DB)
	ranksService := ranks.NewService(ranksRepo)
	logger.Info("ranks module initialized")

	profilesHandler := profiles.NewHandler(profilesService, ranksService)
	logger.Info("profiles module initialized")
	ranksHandler := ranks.NewHandler(ranksService)
	logger.Info("ranks module initialized (handler)")
	mapHandler := mapmodule.NewHandler(mapService)
	logger.Info("map module initialized")

	// Feed Module Initialization
	feedRepo := feed.NewRepositoryWithAdaptiveGeo(db.DB, cfg.Storage.PublicURL, feed.AdaptiveGeoConfig{
		Enabled:            cfg.Feed.AdaptiveGeoEnabled,
		MaxKRing:           cfg.Feed.MaxKRing,
		Ring1RadiusKm:      cfg.Feed.Ring1RadiusKm,
		Ring2RadiusKm:      cfg.Feed.Ring2RadiusKm,
		Ring3RadiusKm:      cfg.Feed.Ring3RadiusKm,
		MinLocalPosts24h:   cfg.Feed.MinLocalPosts24h,
		MinLocalAuthors24h: cfg.Feed.MinLocalAuthors24h,
		MedLocalPosts24h:   cfg.Feed.MedLocalPosts24h,
		MedLocalAuthors24h: cfg.Feed.MedLocalAuthors24h,
		LocalShareLow:      cfg.Feed.LocalShareLow,
		LocalShareMedium:   cfg.Feed.LocalShareMedium,
		LocalShareHigh:     cfg.Feed.LocalShareHigh,
	})
	feedCache := feed.NewCacheRepository(redisCache)
	feedService := feed.NewService(feedRepo, feedCache, profilesRepo, asynqClient, eventProducer)

	// Initialize Vision Client
	var visionClient vision.Client
	vClient, err := vision.NewClient(context.Background())
	if err != nil {
		logger.Error("failed to initialize vision client (ADC not configured)", zap.Error(err))
	} else {
		visionClient = vClient
		logger.Info("Google Vision API client initialized via ADC")
	}

	// Workers have been moved to cmd/worker to unblock API event loop
	// Handlers that depended on workers directly are injected appropriately OR refactored
	// (Note: To keep this compiling safely right away, we will stub the feedWorker temporarily or pass nil if the handler supports it.
	// Feed handler needs to use Redis directly or a dedicated queue interface instead of the worker instance,
	// but for now we'll rely on the existing worker initialization for interface compliance if needed, just without .Start())

	feedWorker := feed.NewInteractionWorker(redisCache, feedRepo)
	feedHandler := feed.NewHandler(feedService, feedWorker, economyService, storageClient, visionClient, cfg.Storage.PublicURL, cfg.Storage.TempBucket)
	logger.Info("feed module initialized")

	settingsRepo := settings.NewRepository(db.DB)
	settingsAuthAdapter := settings.NewAuthAdapter(authRepo)
	settingsService := settings.NewService(settingsRepo, smsSender, settingsAuthAdapter)
	settingsService.SetEmailSender(settingsEmailAdapter{sender: emailSender})
	settingsService.SetSupportInbox(cfg.Support.Inbox)
	settingsHandler := settings.NewHandler(settingsService)
	settingsWorker := settings.NewWorker(settingsService)
	settingsWorker.Start()
	logger.Info("settings module initialized")

	chatRepo := chat.NewRepository(db.DB)
	chatHub := chat.NewHub(redisCache)
	chatHub.Start(context.Background())

	var pushNotifier chat.PushNotifier
	if eventProducer != nil {
		pushNotifier = chat.NewEventBusNotifier(eventProducer)
	}

	chatService := chat.NewService(chatRepo, settingsService, chatHub, pushNotifier)
	chatHandler := chat.NewHandler(chatService, chatHub, jwtManager, authRepo)
	mapService.SetChatIntegrator(chatService)
	logger.Info("chat module initialized")

	notificationsRepo := notifications.NewRepository(db.DB)
	notificationsService := notifications.NewService(notificationsRepo, eventProducer, redisCache)
	notificationsService.SetSettingsService(settingsService)
	notificationsHandler := notifications.NewHandler(notificationsService)
	logger.Info("notifications module initialized")

	// Wire the post-seal notifier so that when user A seals user B's
	// post, A receives "You moved [B] to position X in [region]".
	feedHandler.SetSealNotifier(&postSealNotifier{
		cache:    redisCache,
		mapRepo:  mapRepo,
		mapSvc:   mapService,
		authRepo: authRepo,
		notifier: notificationsService,
	})

	seasonsRepo := seasons.NewRepository(db.DB)
	seasonsService := seasons.NewService(seasonsRepo)
	seasonsService.SetEventBus(eventProducer)
	seasonsHandler := seasons.NewHandler(seasonsService)
	seasonsSnapshot := seasons.NewSnapshotProvider(db.DB)
	seasonsWorker := seasons.NewCloseWorker(seasonsService, seasonsSnapshot, time.Hour, logger.Get())
	seasonsWorker.Start()
	logger.Info("seasons module initialized")

	paymentRepo := payment.NewRepository(db.DB)
	paymentService := payment.NewService(paymentRepo, economyService, profilesRepo, eventProducer, logger.Get(), os.Getenv("REVENUECAT_WEBHOOK_TOKEN"))
	paymentHandler := payment.NewHandler(paymentService)
	logger.Info("payment module initialized")

	leaderboardRepo := leaderboard.NewRepository(db.DB)
	leaderboardService := leaderboard.NewService(leaderboardRepo, redisCache)
	leaderboardHandler := leaderboard.NewHandler(leaderboardService)
	logger.Info("leaderboard module initialized")

	app := server.New(cfg, authHandler, economyHandler, profilesHandler, mapHandler, feedHandler, settingsHandler, chatHandler, notificationsHandler, seasonsHandler, ranksHandler, paymentHandler, leaderboardHandler, jwtManager, authRepo, logger.Get())

	addr := fmt.Sprintf(":%d", cfg.Server.Port)
	logger.Info("server starting", zap.String("address", addr))

	// Listen for OS signals for graceful shutdown
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)

	go func() {
		if err := app.Listen(addr); err != nil {
			logger.Fatal("server stopped", zap.Error(err))
		}
	}()

	<-sigCh
	logger.Info("shutting down server...")
	settingsWorker.Stop()
	seasonsWorker.Stop()
	if eventProducer != nil {
		_ = eventProducer.Close()
	}

	if err := app.ShutdownWithTimeout(10 * time.Second); err != nil {
		logger.Error("server shutdown error", zap.Error(err))
	}

	logger.Info("shutdown complete")
}

func runStartupMigrations(db *sqlx.DB) error {
	paths := []string{
		"migrations",
		filepath.Join("backend", "migrations"),
		filepath.Join("..", "migrations"),
	}

	var errors []string
	for _, path := range paths {
		abs, _ := filepath.Abs(path)
		if _, err := os.Stat(path); err != nil {
			errors = append(errors, fmt.Sprintf("path %s (abs: %s): %v", path, abs, err))
			continue
		}
		if err := migrate.Run(db, path); err != nil {
			errors = append(errors, fmt.Sprintf("path %s: migration error: %v", path, err))
			continue
		}
		return nil
	}

	return fmt.Errorf("failed to run migrations from known paths: \n- %s", strings.Join(errors, "\n- "))
}

// authEmailAdapter satisfies auth.EmailSender by delegating to the
// platform-level email.Sender. Lives here (not in the auth package) so
// the auth module stays free of any platform/email import.
type authEmailAdapter struct {
	sender email.Sender
}

func (a authEmailAdapter) Send(ctx context.Context, to, subject, body string) error {
	return a.sender.Send(ctx, to, subject, body)
}

// settingsEmailAdapter mirrors authEmailAdapter for the settings module's
// EmailSender interface. The two interfaces are intentionally defined
// per-module to avoid a shared dependency, hence the duplicate adapter.
type settingsEmailAdapter struct {
	sender email.Sender
}

func (a settingsEmailAdapter) Send(ctx context.Context, to, subject, body string) error {
	return a.sender.Send(ctx, to, subject, body)
}

// postSealNotifier implements feed.SealNotifier. After a successful seal
// it computes the recipient's leaderboard rank and fires a notification
// to the *sender* matching the founder spec
// "You moved [username] to position X in [city/country]."
//
// All lookups are best-effort: missing H3 / leaderboard / metadata
// degrades gracefully into a notification without those fields rather
// than failing.
type postSealNotifier struct {
	cache    *cache.Cache
	mapRepo  mapmodule.Repository
	mapSvc   *mapmodule.Service
	authRepo auth.Repository
	notifier *notifications.Service
}

func (p *postSealNotifier) NotifyPostSealed(ctx context.Context, actorID, recipientID uuid.UUID) error {
	if p == nil || p.notifier == nil {
		return nil
	}

	// Recipient profile вЂ” needed for the username string in the title.
	recipientUser, err := p.authRepo.GetUserByID(ctx, recipientID.String())
	if err != nil || recipientUser == nil {
		return nil
	}
	username := recipientUser.Username
	if username == "" {
		username = strings.TrimSpace(recipientUser.FirstName + " " + recipientUser.LastName)
	}
	if username == "" {
		username = "your ally"
	}

	// Recipient region вЂ” pick the most granular H3 cell available so we
	// resolve to the smallest meaningful place name (city в†’ region в†’ country).
	regionState, _ := p.mapRepo.GetUserRegionState(ctx, recipientID.String())
	scope := "region"
	leaderboardKey := ""
	h3Index := ""
	year, week := time.Now().UTC().ISOWeek()
	if regionState != nil {
		switch {
		case regionState.H3Res5 != nil && *regionState.H3Res5 != "":
			h3Index = *regionState.H3Res5
			leaderboardKey = fmt.Sprintf("leaderboard:arena:%s:week:%d:%d", h3Index, year, week)
			scope = "city"
		case regionState.H3Res4 != nil && *regionState.H3Res4 != "":
			h3Index = *regionState.H3Res4
			leaderboardKey = fmt.Sprintf("leaderboard:city:%s:week:%d:%d", h3Index, year, week)
			scope = "city"
		case regionState.H3Res2 != nil && *regionState.H3Res2 != "":
			h3Index = *regionState.H3Res2
			leaderboardKey = fmt.Sprintf("leaderboard:country:%s:week:%d:%d", h3Index, year, week)
			scope = "country"
		}
	}

	// Position lookup: ZRevRank is 0-based, so add 1 for human display.
	position := 0
	if leaderboardKey != "" && p.cache != nil {
		if rank, err := p.cache.ZRevRank(ctx, leaderboardKey, recipientID.String()); err == nil {
			position = int(rank) + 1
		}
	}

	region := ""
	if h3Index != "" {
		if meta, err := p.mapSvc.ResolveH3ToLocation(ctx, h3Index); err == nil && meta != nil {
			switch scope {
			case "country":
				region = meta.CountryName
			default:
				if meta.CityName != "" {
					region = meta.CityName
				} else if meta.RegionName != "" {
					region = meta.RegionName
				} else {
					region = meta.CountryName
				}
			}
		}
	}

	// If we couldn't infer a position the message would read "to position 0",
	// which is worse than no notification вЂ” skip it instead.
	if position == 0 {
		return nil
	}

	return p.notifier.NotifyMovedUser(ctx, actorID, recipientID, username, scope, region, position)
}
