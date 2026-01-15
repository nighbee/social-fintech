package middleware

import (
	"strings"

	"github.com/brightbund-backend/internal/modules/auth"
	"github.com/gofiber/fiber/v2"
)

func RequireAuth(jwt *auth.JWTManager) fiber.Handler {
	return func(c *fiber.Ctx) error {
		header := c.Get("Authorization")
		if header == "" || !strings.HasPrefix(header, "Bearer ") {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "missing_token"})
		}
		tokenStr := strings.TrimPrefix(header, "Bearer ")
		claims, err := jwt.VerifyAccess(tokenStr)
		if err != nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid_token"})
		}
		c.Locals("user_id", claims.Subject)
		c.Locals("session_id", claims.SessionID)
		return c.Next()
	}
}
