package middleware

import (
	"strings"

	"github.com/brightbund-backend/internal/modules/auth"
	"github.com/gofiber/fiber/v2"
)

// проверяет access jwt и проверяет сессии в бд, кладет user_id/sessiob_id
func RequireAuth(jwt *auth.JWTManager, repo auth.Repository) fiber.Handler {
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

		session, err := repo.GetSessionByID(c.Context(), claims.SessionID)
		if err != nil || session == nil || session.RevokedAt != nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid_session"})
		}
		if session.UserID != claims.Subject {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid_session"})
		}

		c.Locals("user_id", claims.Subject)
		c.Locals("session_id", claims.SessionID)
		return c.Next()
	}
}
