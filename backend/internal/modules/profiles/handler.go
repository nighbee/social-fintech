package profiles

import "github.com/gofiber/fiber/v2"

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) GetMyProfile(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}
	p, err := h.service.GetMyProfile(c.Context(), userID.(string))
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "profile_error"})
	}
	return c.JSON(p)
}

func (h *Handler) UpdateMyProfile(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	var req UpdateProfileRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_body"})
	}

	p, err := h.service.UpdateMyProfile(c.Context(), userID.(string), &req)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "profile_update_failed"})
	}
	return c.JSON(p)
}

func (h *Handler) GetPublicProfile(c *fiber.Ctx) error {
	targetID := c.Params("user_id")
	if targetID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_user_id"})
	}

	p, err := h.service.GetPublicProfile(c.Context(), targetID)
	if err != nil {
		if err == ErrProfilePrivate {
			return c.Status(403).JSON(fiber.Map{"error": "profile_private"})
		}
		if err == ErrProfileNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "profile_not_found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": "profile_error"})
	}

	return c.JSON(p)
}
