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

// GetAllRanks returns the list of all available ranks and their sub-levels
// @Summary Get all ranks
// @Description Returns the catalog of all ranks (Pearl to Supernova) including their thresholds and dynamic sub-level segments (C/B/A/S).
// @Tags ranks
// @Accept json
// @Produce json
// @Success 200 {object} RankListResponse
// @Failure 500 {object} map[string]string
// @Router /ranks [get]
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

// GetMyRank returns the current rank and progress details for the authenticated user
// @Summary Get current user rank
// @Description Returns the current rank, sub-level, and progress metrics based on the user's received Gold Seals.
// @Tags ranks
// @Accept json
// @Produce json
// @Security Bearer
// @Success 200 {object} CurrentRankResponse
// @Failure 401 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /ranks/me [get]
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
