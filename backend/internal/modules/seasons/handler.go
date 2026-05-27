package seasons

import (
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

type Handler struct {
	service *Service
	snap    SnapshotProvider
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func NewHandlerWithSnap(service *Service, snap SnapshotProvider) *Handler {
	return &Handler{service: service, snap: snap}
}

func requireUserID(c *fiber.Ctx) (uuid.UUID, bool) {
	idStr, ok := c.Locals("user_id").(string)
	if !ok || idStr == "" {
		return uuid.Nil, false
	}
	id, err := uuid.Parse(idStr)
	if err != nil {
		return uuid.Nil, false
	}
	return id, true
}

func (h *Handler) GetCurrent(c *fiber.Ctx) error {
	if _, ok := requireUserID(c); !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	resp, err := h.service.GetCurrentSeason(c.Context(), time.Now().UTC())
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "current_season_failed"})
	}
	return c.JSON(resp)
}

func (h *Handler) GetMyArchive(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	limit := 50
	if v := c.Query("limit"); v != "" {
		if parsed, err := strconv.Atoi(v); err == nil {
			limit = parsed
		}
	}
	resp, err := h.service.GetUserArchive(c.Context(), userID, limit)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "archive_failed"})
	}
	return c.JSON(resp)
}

func (h *Handler) GetUserArchive(c *fiber.Ctx) error {
	if _, ok := requireUserID(c); !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	userID, err := uuid.Parse(c.Params("user_id"))
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_user_id"})
	}
	limit := 50
	if v := c.Query("limit"); v != "" {
		if parsed, err := strconv.Atoi(v); err == nil {
			limit = parsed
		}
	}
	resp, err := h.service.GetUserArchive(c.Context(), userID, limit)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "archive_failed"})
	}
	return c.JSON(resp)
}

func (h *Handler) AdminListSeasons(c *fiber.Ctx) error {
	resp, err := h.service.ListAllSeasons(c.Context())
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "seasons_list_failed"})
	}
	return c.JSON(resp)
}

func (h *Handler) AdminForceClose(c *fiber.Ctx) error {
	seasonID, err := uuid.Parse(c.Params("season_id"))
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_season_id"})
	}

	resp, err := h.service.ForceCloseSeason(c.Context(), seasonID, h.snap)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error":   "force_close_failed",
			"details": err.Error(),
		})
	}
	return c.JSON(resp)
}
