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
		if header == "" {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "missing_token"})
		}

		if !strings.HasPrefix(header, "Bearer ") {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error":   "invalid_token_format",
				"message": "token must be 'Bearer <token>'",
			})
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

		user, err := repo.GetUserByID(c.Context(), claims.Subject)
		if err != nil || user == nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid_session"})
		}
		if user.IsShadowBanned || strings.EqualFold(user.ActivationStatus, "blocked") {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "account_blocked"})
		}

		c.Locals("user_id", claims.Subject)
		c.Locals("session_id", claims.SessionID)
		return c.Next()
	}
}
