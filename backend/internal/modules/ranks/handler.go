package ranks

import (
	"github.com/brightbund-backend/internal/platform/logger"
	"github.com/gofiber/fiber/v2"
	"go.uber.org/zap"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) GetAllRanks(c *fiber.Ctx) error {
	ranks, err := h.service.GetAllRanks(c.Context())
	if err != nil {
		logger.Error("failed to get all ranks",
			zap.String("request_id", c.Get("X-Request-Id")),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "failed to retrieve ranks"})
	}
	return c.JSON(ranks)
}

func (h *Handler) GetMyRank(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	rank, err := h.service.GetMyRank(c.Context(), userID.(string))
	if err != nil {
		logger.Error("failed to get user rank",
			zap.String("user_id", userID.(string)),
			zap.String("request_id", c.Get("X-Request-Id")),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "failed to retrieve rank"})
	}

	return c.JSON(rank)
}
