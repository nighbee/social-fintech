package middleware

import (
	"time"

	"github.com/brightbund-backend/internal/modules/auth"
	"github.com/gofiber/fiber/v2"
)

// просто обновляет last_active_at для сессии и пользователя
func TouchSession(repo auth.Repository) fiber.Handler {
	return func(c *fiber.Ctx) error {
		err := c.Next()

		sessionID, _ := c.Locals("session_id").(string)
		userID, _ := c.Locals("user_id").(string)
		if sessionID == "" && userID == "" {
			return err
		}

		now := time.Now()
		if sessionID != "" {
			_ = repo.TouchSession(c.Context(), sessionID, now)
		}
		if userID != "" {
			_ = repo.TouchUser(c.Context(), userID, now)
		}
		return err
	}
}
