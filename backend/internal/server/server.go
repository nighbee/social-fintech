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
	"github.com/brightbund-backend/internal/server/middleware"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/limiter"
	"github.com/gofiber/fiber/v2/middleware/requestid"
	"go.uber.org/zap"

	_ "github.com/brightbund-backend/docs"
	swagger "github.com/swaggo/fiber-swagger"
)

func New(cfg *config.Config, authHandler *auth.Handler, economyHandler *economy.Handler, profilesHandler *profiles.Handler, mapHandler *mapmodule.Handler, feedHandler *feed.Handler, jwt *auth.JWTManager, authRepo auth.Repository, logger *zap.Logger) *fiber.App {
	app := fiber.New(fiber.Config{
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
		IdleTimeout:  cfg.Server.IdleTimeout,
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

	// Use Redis for rate limiter storage rather than in-memory
	authLim := limiter.New(limiter.Config{
		Max:        10,
		Expiration: 1 * time.Minute,
		// Note: Storage can be passed explicitly if a redis storage wrapper is initialized.
		// For now we add the property placeholder if we needed it:
		// Storage: redisStorage,
	})

	api.Get("/users/search", profilesHandler.SearchUsers)

	authGroup.Post("/login", authLim, authHandler.Login)
	authGroup.Post("/register-email", authLim, authHandler.RegisterEmail)
	authGroup.Post("/login-email", authLim, authHandler.LoginEmail)
	authGroup.Post("/check-email", authLim, authHandler.CheckEmail)

	// Legacy phone auth endpoints (custom OTP)
	authGroup.Post("/phone/request", authLim, authHandler.RequestPhoneCode)
	authGroup.Post("/phone/verify", authLim, authHandler.VerifyPhoneCode)
	authGroup.Post("/register-phone", authLim, authHandler.RegisterPhone)

	// Firebase phone auth endpoints (recommended)
	authGroup.Post("/firebase-phone-login", authLim, authHandler.FirebasePhoneAuth)
	authGroup.Post("/firebase-phone-register", authLim, authHandler.FirebasePhoneRegister)

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
	profilesGroup.Get("/search", profilesHandler.SearchProfilesForFeed)
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
	api.Get("/profiles/ranks", profilesHandler.GetAllRanks)

	// Feed & Interactions (Note: Feed router actually manages its own sub-routing in routes.go
	// but for consistency we can call a Feed register wrapper here or just inject the handler)
	// Since we defined feed.RegisterRoutes separately, we don't strictly need to mount feedHandler here manually,
	// but if server.go is the single source of truth for routing, we mount it directly instead.

	feedGroup := api.Group("/feed")
	feedGroup.Use(middleware.RequireAuth(jwt, authRepo))
	feedGroup.Use(middleware.TouchSession(authRepo))

	feedGroup.Get("/state", feedHandler.GetFeedState)
	feedGroup.Post("/state/sync", feedHandler.SyncFeedState)
	feedGroup.Get("/", feedHandler.GetFeed)

	// Notice: for Post creations and interactions, they typically fall under /posts
	// To keep RESTful:
	postGroup := api.Group("/posts")
	postGroup.Use(middleware.RequireAuth(jwt, authRepo))
	postGroup.Use(middleware.TouchSession(authRepo))

	postGroup.Post("/", feedHandler.CreatePost)
	postGroup.Get("/:post_id/comments", feedHandler.GetThreadedComments)
	postGroup.Post("/:post_id/comments", feedHandler.CreateComment)
	postGroup.Post("/:post_id/likes", feedHandler.ToggleLike)
	postGroup.Get("/:post_id/likes", feedHandler.GetLikes)
	postGroup.Get("/:post_id/seals", feedHandler.GetSeals)
	postGroup.Post("/:post_id/seals", feedHandler.SendSeal)

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

	// Legacy (deprecated) endpoint removed to enforce 2-step approval flow.

	// Map / Champions
	mapGroup.Post("/map/region", mapHandler.SetUserRegion)
	mapGroup.Get("/map/champions", mapHandler.GetRegionChampions)

	return app
}
