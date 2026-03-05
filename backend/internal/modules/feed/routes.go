package feed

import (
	"github.com/brightbund-backend/internal/modules/economy"
	"github.com/brightbund-backend/internal/modules/profiles"
	"github.com/brightbund-backend/internal/platform/cache"
	"github.com/gofiber/fiber/v2"
	"github.com/jmoiron/sqlx"
)

func RegisterRoutes(app *fiber.App, db *sqlx.DB, redisClient *cache.Cache, profilesRepo *profiles.Repository, economyService economy.Service, authMiddleware fiber.Handler) {
	// Initialize layers
	repo := NewRepository(db)
	cacheRepo := NewCacheRepository(redisClient)
	service := NewService(repo, cacheRepo, profilesRepo)
	// Start Background Workers
	interactionWorker := NewInteractionWorker(redisClient, repo)
	interactionWorker.Start()

	// Initialize layers
	handler := NewHandler(service, interactionWorker, economyService)

	// API Grouping
	api := app.Group("/api/v1/feed", authMiddleware)

	// --- Anti-Doomscroll Endpoints ---
	api.Get("/state", handler.GetFeedState)
	api.Post("/state/sync", handler.SyncFeedState)

	// --- Feed Retrieval Endpoints ---
	api.Get("/", handler.GetFeed)

	postGroup := app.Group("/api/v1/posts", authMiddleware)

	// --- Posts and Comments Endpoints ---
	postGroup.Post("/", handler.CreatePost)
	postGroup.Get("/:post_id/comments", handler.GetThreadedComments)
	postGroup.Post("/:post_id/comments", handler.CreateComment)

	// --- Interaction Endpoints ---
	postGroup.Get("/:post_id/likes", handler.GetLikes)
	postGroup.Post("/:post_id/likes", handler.ToggleLike)
	postGroup.Get("/:post_id/seals", handler.GetSeals)
	postGroup.Post("/:post_id/seals", handler.SendSeal)
}
