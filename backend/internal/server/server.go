package server

import (
	"strings"
	"time"

	"github.com/brightbund-backend/internal/config"
	"github.com/brightbund-backend/internal/modules/auth"
	"github.com/brightbund-backend/internal/modules/economy"
	"github.com/brightbund-backend/internal/server/middleware"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/limiter"
	"github.com/gofiber/fiber/v2/middleware/requestid"
	"go.uber.org/zap"

	_ "github.com/brightbund-backend/docs"
	swagger "github.com/swaggo/fiber-swagger"
)

// создает Fiber app, cors auth routes limiter и middleware для бэка
func New(cfg *config.Config, authHandler *auth.Handler, economyHandler *economy.Handler, jwt *auth.JWTManager, authRepo auth.Repository, logger *zap.Logger) *fiber.App {
	app := fiber.New(fiber.Config{
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
	})

	// Request ID для трейсинга
	app.Use(requestid.New())

	// Логирование всех запросов
	app.Use(middleware.Logger(logger))

	app.Use(cors.New(cors.Config{
		AllowOrigins:     strings.Join(cfg.CORS.AllowedOrigins, ","),
		AllowMethods:     strings.Join(cfg.CORS.AllowedMethods, ","),
		AllowHeaders:     strings.Join(cfg.CORS.AllowedHeaders, ","),
		ExposeHeaders:    strings.Join(cfg.CORS.ExposeHeaders, ","),
		AllowCredentials: cfg.CORS.AllowCredentials,
		MaxAge:           int(cfg.CORS.MaxAge.Seconds()),
	}))

	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"status": "ok"})
	})

	// Swagger documentation
	app.Get("/swagger/*", swagger.FiberWrapHandler())

	api := app.Group("/api/v1")
	authGroup := api.Group("/auth")

	authLim := limiter.New(limiter.Config{
		Max:        10,
		Expiration: 1 * time.Minute,
	})

	authGroup.Post("/login", authLim, authHandler.Login)
	authGroup.Post("/register-email", authLim, authHandler.RegisterEmail)
	authGroup.Post("/login-email", authLim, authHandler.LoginEmail)

	authGroup.Post("/phone/request", authLim, authHandler.RequestPhoneCode)
	authGroup.Post("/phone/verify", authLim, authHandler.VerifyPhoneCode)
	authGroup.Post("/register-phone", authLim, authHandler.RegisterPhone)

	authGroup.Post("/refresh", authLim, authHandler.Refresh)
	authGroup.Post("/logout", middleware.RequireAuth(jwt, authRepo), middleware.TouchSession(authRepo), authHandler.Logout)

	economyGroup := api.Group("/economy")
	economyGroup.Use(middleware.RequireAuth(jwt, authRepo))
	economyGroup.Use(middleware.TouchSession(authRepo))

	economyGroup.Get("/balance", economyHandler.GetBalance)
	economyGroup.Post("/transfer", economyHandler.TransferSeals)
	economyGroup.Get("/transactions", economyHandler.GetTransactionHistory)
	economyGroup.Post("/accrual/claim", economyHandler.ClaimDailyAccrual)
	economyGroup.Post("/seal/post/:postID", economyHandler.GiveSealToPost)
	economyGroup.Post("/seal/user/:userID", economyHandler.GiveSealToUser)
	economyGroup.Get("/limits", economyHandler.GetLimits)
	economyGroup.Get("/referral/stats", economyHandler.GetReferralStats)
	economyGroup.Post("/admin/adjust", economyHandler.AdminAdjustBalance)
	economyGroup.Get("/admin/violations", economyHandler.GetViolationLogs)

	return app
}
