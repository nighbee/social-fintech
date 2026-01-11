package main

import (
	"fmt"
	"log"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	swagger "github.com/swaggo/fiber-swagger"

	_ "github.com/brightbund-backend/docs"
)

// @title BrightBund API
// @version 1.0
// @description API for the BrightBund social platform with economy, maps, chat, and gamification
// @termsOfService http://swagger.io/terms/

// @contact.name API Support
// @contact.email support@brightbund.com

// @license.name MIT
// @license.url https://opensource.org/licenses/MIT

// @host localhost:8081
// @BasePath /api/v1
// @schemes http https

// @securityDefinitions.apikey Bearer
// @in header
// @name Authorization
// @description Type "Bearer" followed by a space and JWT token

func main() {
	app := fiber.New(fiber.Config{
		AppName: "BrightBund API v1.0",
	})

	// Middleware
	app.Use(logger.New())
	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowHeaders: "Origin, Content-Type, Accept, Authorization",
	}))

	// Root endpoint
	app.Get("/", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"message": "BrightBund API is running",
			"version": "1.0.0",
			"docs":    "/swagger/index.html",
		})
	})

	// Swagger documentation
	app.Get("/swagger/*", swagger.WrapHandler)

	// API v1 routes
	api := app.Group("/api/v1")

	// Health check
	api.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"status":  "healthy",
			"service": "brightbund-api",
		})
	})

	// Placeholder routes (to be implemented)
	api.Get("/ping", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"message": "pong"})
	})

	fmt.Println("🚀 Server starting on port 8080...")
	fmt.Println("📚 Swagger docs: http://localhost:8081/swagger/index.html")
	log.Fatal(app.Listen(":8080"))
}
