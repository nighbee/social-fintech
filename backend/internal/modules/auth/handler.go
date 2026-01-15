package auth

import "github.com/gofiber/fiber/v2"

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) Login(c *fiber.Ctx) error {
	var req LoginRequest
	
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}
	if req.DeviceID == "" || req.ProviderToken == "" || req.ProviderType == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "missing_fields"})
	}


	resp, err := h.service.Login(c.Context(), req, c.IP())
	if err != nil {
		switch err {
		case ErrInvalidProviderToken:
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid_provider_token"})
		case ErrEmailRequired:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "email_required"})
		default:
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "server_error"})
		}
	}

	return c.JSON(resp)
}

func (h *Handler) Refresh(c *fiber.Ctx) error {
	var req RefreshRequest
	if err := c.BodyParser(&req); err != nil || req.RefreshToken == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}

	resp, err := h.service.Refresh(c.Context(), req.RefreshToken)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid_refresh"})
	}

	return c.JSON(resp)
}

func (h *Handler) Logout(c *fiber.Ctx) error {
	sessionID, ok := c.Locals("session_id").(string)
	if !ok || sessionID == "" {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	} 

	if err := h.service.Logout(c.Context(), sessionID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "server_err"})
	}

	return c.SendStatus(fiber.StatusNoContent)
}