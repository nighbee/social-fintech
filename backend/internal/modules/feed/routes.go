package feed

import (
	"github.com/brightbund-backend/internal/modules/economy"
	"github.com/brightbund-backend/internal/modules/profiles"
	"github.com/brightbund-backend/internal/platform/cache"
	"github.com/hibiken/asynq"
	"github.com/gofiber/fiber/v2"
	"github.com/jmoiron/sqlx"
)

func RegisterRoutes(app *fiber.App, db *sqlx.DB, redisClient *cache.Cache, profilesRepo *profiles.Repository, economyService economy.Service, asynqClient *asynq.Client, storageClient ObjectStorage, publicURL, tempBucket string, authMiddleware fiber.Handler) {
	// Initialize layers
	repo := NewRepository(db, publicURL)
	cacheRepo := NewCacheRepository(redisClient)
	service := NewService(repo, cacheRepo, profilesRepo, asynqClient)
	// Start Background Workers
	interactionWorker := NewInteractionWorker(redisClient, repo)
	interactionWorker.Start()

	// Initialize layers
	handler := NewHandler(service, interactionWorker, economyService, storageClient, publicURL, tempBucket)

	// API Grouping
	api := app.Group("/api/v1/feed", authMiddleware)

	// Serve Media
	app.Static("/uploads", "./uploads")

	// --- Anti-Doomscroll Endpoints ---
	api.Get("/state", handler.GetFeedState)
	api.Post("/state/sync", handler.SyncFeedState)

	// --- Media Management ----
	api.Post("/media/upload", handler.UploadMedia)

	// --- Feed Retrieval Endpoints ---
	api.Get("/", handler.GetFeed)

	postGroup := app.Group("/api/v1/posts", authMiddleware)

	// --- Posts and Comments Endpoints ---
	postGroup.Post("/", handler.CreatePost)
	postGroup.Patch("/:post_id", handler.UpdatePost)
	postGroup.Delete("/:post_id", handler.DeletePost)
	postGroup.Get("/:post_id/comments", handler.GetThreadedComments)
	postGroup.Post("/:post_id/comments", handler.CreateComment)
	postGroup.Delete("/:post_id/comments/:comment_id", handler.DeleteComment)
	postGroup.Post("/:post_id/comments/:comment_id/report", handler.ReportComment)
	postGroup.Post("/:post_id/report", handler.ReportPost)

	// --- Interaction Endpoints ---
	postGroup.Get("/:post_id/likes", handler.GetLikes)
	postGroup.Post("/:post_id/likes", handler.ToggleLike)
	postGroup.Get("/:post_id/seals", handler.GetSeals)
	postGroup.Post("/:post_id/seals", handler.SendSeal)

	adminGroup := app.Group("/api/v1/admin", authMiddleware)
	adminGroup.Get("/reports", handler.GetAdminReports)
	adminGroup.Post("/reports/review", handler.ReviewReports)

	// In API group for generic ID
	api.Post("/comments/:comment_id/likes", handler.ToggleCommentLike)
}
