package server

import (
	"fmt"

	"github.com/brightbund-backend/internal/config"
	"github.com/brightbund-backend/internal/modules/auth"
	"github.com/brightbund-backend/internal/server/middleware"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
)

func New(cfg *config.Config, authHandler *auth.Handler, jwt *auth.JWTManager) *fiber.App {
	app := fiber.New(fiber.Config{
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
	})

	app.Use(cors.New(cors.Config{
		AllowOrigins:     fmt.Sprintf("%v", cfg.CORS.AllowedOrigins),
		AllowMethods:     fmt.Sprintf("%v", cfg.CORS.AllowedMethods),
		AllowHeaders:     fmt.Sprintf("%v", cfg.CORS.AllowedHeaders),
		ExposeHeaders:    fmt.Sprintf("%v", cfg.CORS.ExposeHeaders),
		AllowCredentials: cfg.CORS.AllowCredentials,
		MaxAge:           int(cfg.CORS.MaxAge.Seconds()),
	}))

	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"status": "ok"})
	})

	api := app.Group("/api/v1")
	authGroup := api.Group("/auth")
	authGroup.Post("/login", authHandler.Login)
	authGroup.Post("/refresh", authHandler.Refresh)
	authGroup.Post("/logout", middleware.RequireAuth(jwt), authHandler.Logout)

	return app
}
