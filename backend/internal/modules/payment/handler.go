package payment

import (
	"github.com/gofiber/fiber/v2"
)

type Handler struct {
	service Service
}

func NewHandler(service Service) *Handler {
	return &Handler{service: service}
}

// HandleWebhook handles the RevenueCat webhook
// @Summary RevenueCat Webhook
// @Description Receives IAP events from RevenueCat and publishes them to the event bus
// @Tags payment
// @Accept json
// @Produce json
// @Param Authorization header string true "RevenueCat Webhook Secret"
// @Param payload body RevenueCatWebhook true "RevenueCat Webhook Payload"
// @Success 200 {object} map[string]string
// @Failure 401 {object} map[string]string
// @Failure 400 {object} map[string]string
// @Router /payment/webhook [post]
func (h *Handler) HandleWebhook(c *fiber.Ctx) error {
	var payload RevenueCatWebhook
	if err := c.BodyParser(&payload); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "failed to parse request body",
		})
	}

	authToken := c.Get("Authorization")
	
	err := h.service.HandleRevenueCatWebhook(c.Context(), authToken, &payload)
	if err != nil {
		// If it's an auth error, return 401
		if err.Error() == "invalid authorization token" {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error": "unauthorized",
			})
		}
		
		// For other errors, we might still want to return 200 to RevenueCat to avoid retries 
		// if the error is non-recoverable, but usually 400/500 is fine for retries.
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"status": "received",
	})
}
