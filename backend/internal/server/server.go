package server

import (
	"strings"
	"time"

	"github.com/brightbund-backend/internal/config"
	"github.com/brightbund-backend/internal/modules/auth"
	"github.com/brightbund-backend/internal/modules/economy"
	"github.com/brightbund-backend/internal/modules/feed"
	mapmodule "github.com/brightbund-backend/internal/modules/map"
	"github.com/brightbund-backend/internal/modules/profiles"
	"github.com/brightbund-backend/internal/modules/settings"
	"github.com/brightbund-backend/internal/platform/observability"
	"github.com/brightbund-backend/internal/server/middleware"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/limiter"
	"github.com/gofiber/fiber/v2/middleware/requestid"
	"go.uber.org/zap"

	_ "github.com/brightbund-backend/docs"
	swagger "github.com/swaggo/fiber-swagger"
)

func New(cfg *config.Config, authHandler *auth.Handler, economyHandler *economy.Handler, profilesHandler *profiles.Handler, mapHandler *mapmodule.Handler, feedHandler *feed.Handler, settingsHandler *settings.Handler, jwt *auth.JWTManager, authRepo auth.Repository, logger *zap.Logger) *fiber.App {
	app := fiber.New(fiber.Config{
		ReadTimeout:     cfg.Server.ReadTimeout,
		WriteTimeout:    cfg.Server.WriteTimeout,
		IdleTimeout:     cfg.Server.IdleTimeout,
		BodyLimit:       500 * 1024 * 1024, // 500 MB
		ReadBufferSize:  16 * 1024,
		WriteBufferSize: 16 * 1024,
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
	api.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"status": "ok", "version": "v1"})
	})

	app.Static("/uploads", "./uploads")
	authGroup := api.Group("/auth")

	// Use Redis for rate limiter storage rather than in-memory
	authLim := limiter.New(limiter.Config{
		Max:        10,
		Expiration: 1 * time.Minute,
		// Note: Storage can be passed explicitly if a redis storage wrapper is initialized.
		// For now we add the property placeholder if we needed it:
		// Storage: redisStorage,
	})
	registerLim := limiter.New(limiter.Config{
		Max:        3,
		Expiration: 10 * time.Minute,
		KeyGenerator: func(c *fiber.Ctx) string {
			return "register-ip:" + c.IP()
		},
	})

	api.Get("/users/search", profilesHandler.SearchUsers)

	authGroup.Post("/login", authLim, authHandler.Login)
	authGroup.Post("/register-email", registerLim, authHandler.RegisterEmail)
	authGroup.Post("/login-email", authLim, authHandler.LoginEmail)
	authGroup.Post("/check-email", authLim, authHandler.CheckEmail)

	// Legacy phone auth endpoints (custom OTP)
	authGroup.Post("/phone/request", authLim, authHandler.RequestPhoneCode)
	authGroup.Post("/phone/verify", authLim, authHandler.VerifyPhoneCode)
	authGroup.Post("/register-phone", registerLim, authHandler.RegisterPhone)

	// Firebase phone auth endpoints (recommended)
	authGroup.Post("/firebase-phone-login", authLim, authHandler.FirebasePhoneAuth)
	authGroup.Post("/firebase-phone-register", registerLim, authHandler.FirebasePhoneRegister)

	authGroup.Post("/refresh", authLim, authHandler.Refresh)
	authGroup.Post("/logout", middleware.RequireAuth(jwt, authRepo), middleware.TouchSession(authRepo), authHandler.Logout)

	economyGroup := api.Group("/economy")
	economyGroup.Use(middleware.RequireAuth(jwt, authRepo))
	economyGroup.Use(middleware.TouchSession(authRepo))

	economyGroup.Get("/balance", economyHandler.GetBalance)
	economyGroup.Post("/transfer", economyHandler.TransferSeals)
	economyGroup.Get("/transactions", economyHandler.GetTransactionHistory)
	economyGroup.Post("/accrual/claim", economyHandler.ClaimDailyAccrual)
	economyGroup.Post("/posts/:postID/seals", economyHandler.GiveSealToPost)
	economyGroup.Post("/users/:userID/gift", economyHandler.GiveSealToUser)
	economyGroup.Get("/limits", economyHandler.GetLimits)
	economyGroup.Get("/referral/stats", economyHandler.GetReferralStats)

	// Admin-only routes
	adminGroup := economyGroup.Group("/admin")
	adminGroup.Use(middleware.RequireAdmin(authRepo))
	adminGroup.Post("/adjust", economyHandler.AdminAdjustBalance)
	adminGroup.Get("/violations", economyHandler.GetViolationLogs)

	// Public profiles routes
	api.Get("/profiles/ranks", profilesHandler.GetAllRanks)

	// Profiles routes
	profilesGroup := api.Group("/profiles")
	profilesGroup.Use(middleware.RequireAuth(jwt, authRepo))
	profilesGroup.Use(middleware.TouchSession(authRepo))

	profilesGroup.Get("/me", profilesHandler.GetMyProfile)
	profilesGroup.Patch("/me", profilesHandler.UpdateMyProfile)
	profilesGroup.Post("/me/avatar", profilesHandler.UploadAvatar)
	profilesGroup.Get("/me/stats", profilesHandler.GetMyStats)
	profilesGroup.Get("/me/allies", profilesHandler.GetMyAllies)
	profilesGroup.Delete("/me", profilesHandler.DeleteMyProfile)
	// Global profile search removed (not part of product scope).
	// profilesGroup.Get("/search", profilesHandler.SearchProfilesForFeed)
	// Profile posts grid & list (must be before /:user_id to avoid Fiber routing ambiguity)
	profilesGroup.Get("/me/posts", feedHandler.GetMyPostsGrid)
	profilesGroup.Get("/me/posts/list", feedHandler.GetMyPostsList)
	profilesGroup.Get("/:user_id", profilesHandler.GetPublicProfile)
	profilesGroup.Get("/:user_id/stats", profilesHandler.GetPublicStats)
	profilesGroup.Get("/:user_id/posts", feedHandler.GetUserPostsGrid)
	profilesGroup.Get("/:user_id/posts/list", feedHandler.GetUserPostsList)
	profilesGroup.Get("/:user_id/relationship", profilesHandler.GetRelationshipStatus)
	profilesGroup.Post("/:user_id/allies", profilesHandler.AddAlly)
	profilesGroup.Delete("/:user_id/allies", profilesHandler.RemoveAlly)
	profilesGroup.Get("/:user_id/allies", profilesHandler.GetAllies)

	// Moderation
	profilesGroup.Post("/:user_id/block", profilesHandler.BlockUser)
	profilesGroup.Delete("/:user_id/block", profilesHandler.UnblockUser)
	profilesGroup.Post("/:user_id/restrict", profilesHandler.RestrictUser)
	profilesGroup.Delete("/:user_id/restrict", profilesHandler.UnrestrictUser)
	profilesGroup.Post("/:user_id/report", profilesHandler.ReportUser)

	profilesGroup.Get("/me/rank", profilesHandler.GetMyRank)

	// Feed & Interactions (Note: Feed router actually manages its own sub-routing in routes.go
	// but for consistency we can call a Feed register wrapper here or just inject the handler)
	// Since we defined feed.RegisterRoutes separately, we don't strictly need to mount feedHandler here manually,
	// but if server.go is the single source of truth for routing, we mount it directly instead.

	feedGroup := api.Group("/feed")
	feedGroup.Use(middleware.RequireAuth(jwt, authRepo))
	feedGroup.Use(middleware.TouchSession(authRepo))

	feedGroup.Get("/state", feedHandler.GetFeedState)
	feedGroup.Post("/state/sync", feedHandler.SyncFeedState)
	feedGroup.Post("/media/upload", feedHandler.UploadMedia)
	feedGroup.Get("/", feedHandler.GetFeed)
	feedGroup.Post("/comments/:comment_id/likes", feedHandler.ToggleCommentLike)

	// Notice: for Post creations and interactions, they typically fall under /posts
	// To keep RESTful:
	postGroup := api.Group("/posts")
	postGroup.Use(middleware.RequireAuth(jwt, authRepo))
	postGroup.Use(middleware.TouchSession(authRepo))

	postGroup.Post("/", feedHandler.CreatePost)
	postGroup.Patch("/:post_id", feedHandler.UpdatePost)
	postGroup.Delete("/:post_id", feedHandler.DeletePost)
	postGroup.Get("/:post_id/comments", feedHandler.GetThreadedComments)
	postGroup.Post("/:post_id/comments", feedHandler.CreateComment)
	postGroup.Delete("/:post_id/comments/:comment_id", feedHandler.DeleteComment)
	postGroup.Post("/:post_id/comments/:comment_id/report", feedHandler.ReportComment)
	postGroup.Post("/:post_id/report", feedHandler.ReportPost)
	postGroup.Post("/:post_id/likes", feedHandler.ToggleLike)
	postGroup.Get("/:post_id/likes", feedHandler.GetLikes)
	postGroup.Get("/:post_id/seals", feedHandler.GetSeals)
	postGroup.Post("/:post_id/seals", feedHandler.SendSeal)

	feedAdminGroup := api.Group("/admin")
	feedAdminGroup.Use(middleware.RequireAuth(jwt, authRepo))
	feedAdminGroup.Use(middleware.TouchSession(authRepo))
	feedAdminGroup.Use(middleware.RequireAdmin(authRepo))
	feedAdminGroup.Get("/reports", feedHandler.GetAdminReports)
	feedAdminGroup.Get("/ops/metrics", func(c *fiber.Ctx) error {
		return c.JSON(observability.Snapshot())
	})
	feedAdminGroup.Get("/ops/metrics/prometheus", func(c *fiber.Ctx) error {
		c.Set("Content-Type", "text/plain; version=0.0.4")
		return c.SendString(observability.PrometheusText())
	})

	settingsGroup := api.Group("/settings")
	settingsGroup.Use(middleware.RequireAuth(jwt, authRepo))
	settingsGroup.Use(middleware.TouchSession(authRepo))

	settingsSensitiveLimiter := limiter.New(limiter.Config{
		Max:        5,
		Expiration: 1 * time.Hour,
		KeyGenerator: func(c *fiber.Ctx) string {
			if userID, ok := c.Locals("user_id").(string); ok && userID != "" {
				return "settings-sensitive:" + userID
			}
			return "settings-sensitive-ip:" + c.IP()
		},
	})

	settingsGroup.Get("/security", settingsHandler.GetSecurity)
	settingsGroup.Patch("/security/password", settingsHandler.ChangePassword)
	settingsGroup.Get("/security/2fa", settingsHandler.GetTwoFA)
	settingsGroup.Post("/security/2fa/enable", settingsSensitiveLimiter, settingsHandler.EnableTwoFA)
	settingsGroup.Post("/security/2fa/disable", settingsSensitiveLimiter, settingsHandler.DisableTwoFA)
	settingsGroup.Get("/security/sessions", settingsHandler.GetSessions)
	settingsGroup.Delete("/security/sessions/:id", settingsHandler.DeleteSession)
	settingsGroup.Delete("/security/sessions", settingsHandler.DeleteAllSessions)

	settingsGroup.Post("/security/delete-account/reason", settingsSensitiveLimiter, settingsHandler.DeleteAccountReason)
	settingsGroup.Post("/security/delete-account/verify", settingsSensitiveLimiter, settingsHandler.DeleteAccountVerify)
	settingsGroup.Delete("/security/delete-account", settingsSensitiveLimiter, settingsHandler.DeleteAccountFinalize)

	settingsGroup.Get("/feed", settingsHandler.GetFeedSettings)
	settingsGroup.Patch("/feed", settingsHandler.PatchFeedSettings)

	settingsGroup.Get("/interactions", settingsHandler.GetInteractions)
	settingsGroup.Get("/interactions/messages", settingsHandler.GetMessagesSettings)
	settingsGroup.Patch("/interactions/messages", settingsHandler.PatchMessagesSettings)
	settingsGroup.Post("/interactions/messages", settingsHandler.PatchMessagesSettings)
	settingsGroup.Post("/interactions/messages/keywords", settingsHandler.AddMessageKeyword)
	settingsGroup.Delete("/interactions/messages/keywords/:id", settingsHandler.DeleteMessageKeyword)
	settingsGroup.Get("/interactions/comments", settingsHandler.GetCommentsSettings)
	settingsGroup.Patch("/interactions/comments", settingsHandler.PatchCommentsSettings)
	settingsGroup.Get("/interactions/mentions", settingsHandler.GetMentionsSettings)
	settingsGroup.Patch("/interactions/mentions", settingsHandler.PatchMentionsSettings)
	settingsGroup.Get("/interactions/blocked", settingsHandler.GetBlockedUsers)
	settingsGroup.Delete("/interactions/blocked/:userId", settingsHandler.UnblockUser)

	settingsGroup.Post("/support/bugs", settingsHandler.ReportBug)

	// Map & Tasks routes
	mapGroup := api.Group("/")
	mapGroup.Use(middleware.RequireAuth(jwt, authRepo))
	mapGroup.Use(middleware.TouchSession(authRepo))

	// Task CRUD
	mapGroup.Post("/tasks", mapHandler.CreateTask)
	mapGroup.Get("/tasks/my", mapHandler.GetMyTasks) // Placed before /:task_id
	mapGroup.Get("/tasks/applied", mapHandler.GetAppliedTasks)
	mapGroup.Get("/tasks/nearby", mapHandler.GetNearbyTasks)
	mapGroup.Get("/tasks/:task_id", mapHandler.GetTask) // Placed after specific routes
	mapGroup.Delete("/tasks/:task_id", mapHandler.CancelTask)

	// Task application flow: apply → accept/reject → verify-code → confirm
	mapGroup.Post("/tasks/:task_id/apply", mapHandler.ApplyToTask)
	mapGroup.Post("/tasks/:task_id/applications/:application_id/accept", mapHandler.AcceptApplication)
	mapGroup.Post("/tasks/:task_id/applications/:application_id/reject", mapHandler.RejectApplication)
	mapGroup.Delete("/tasks/:task_id/applications/:application_id", mapHandler.WithdrawApplication)
	mapGroup.Post("/tasks/:task_id/applications/:application_id/verify-code", mapHandler.SubmitVerificationCode)
	mapGroup.Post("/tasks/:task_id/applications/:application_id/confirm", mapHandler.ConfirmCompletion)
	mapGroup.Get("/tasks/:task_id/applications", mapHandler.GetTaskApplications)
	mapGroup.Get("/tasks/:task_id/applications/:application_id", mapHandler.GetApplication)

	// Legacy (deprecated) endpoint removed to enforce 2-step approval flow.

	// Map / Champions & Geo Lookup
	mapGroup.Post("/map/region", mapHandler.SetUserRegion)
	mapGroup.Get("/map/champions", mapHandler.GetRegionChampions)
	mapGroup.Get("/map/h3/:h3_index/admin", mapHandler.GetH3AdminHierarchy)

	return app
}
