package middleware

import (
	"github.com/brightbund-backend/internal/modules/auth"
	"github.com/gofiber/fiber/v2"
)

// RequireAdmin checks if the authenticated user has admin privileges
// Must be used AFTER RequireAuth middleware
func RequireAdmin(repo auth.Repository) fiber.Handler {
	return func(c *fiber.Ctx) error {
		userID := c.Locals("user_id")
		if userID == nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error":   "UNAUTHORIZED",
				"message": "User not authenticated",
			})
		}

		userIDStr, ok := userID.(string)
		if !ok {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error":   "UNAUTHORIZED",
				"message": "Invalid user ID",
			})
		}

		user, err := repo.GetUserByID(c.Context(), userIDStr)
		if err != nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error":   "UNAUTHORIZED",
				"message": "User not found",
			})
		}

		if !user.IsAdmin {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
				"error":   "FORBIDDEN",
				"message": "Admin privileges required",
				"code":    "ADMIN_REQUIRED",
			})
		}

		// Store admin status for potential use in handlers
		c.Locals("is_admin", true)
		return c.Next()
	}
}
