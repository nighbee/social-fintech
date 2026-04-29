package seasons

import (
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
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

// GetCurrent godoc
// @Summary Current season status
// @Description Returns the currently-active 6-month season window with seconds remaining.
// @Tags Seasons
// @Produce json
// @Security Bearer
// @Success 200 {object} CurrentSeasonResponse
// @Router /seasons/current [get]
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

// GetMyArchive godoc
// @Summary Personal season archive
// @Description Returns the caller's archived per-season standings, newest first.
// @Description Powers the "Архив" tab inside the profile screen.
// @Tags Seasons
// @Produce json
// @Security Bearer
// @Param limit query int false "Max items (default 50, max 200)"
// @Success 200 {object} ArchiveResponse
// @Router /seasons/me/archive [get]
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

// GetUserArchive godoc
// @Summary Public season archive for a user
// @Description Same as /seasons/me/archive but for a specified user id.
// @Tags Seasons
// @Produce json
// @Security Bearer
// @Param user_id path string true "User UUID"
// @Param limit query int false "Max items (default 50, max 200)"
// @Success 200 {object} ArchiveResponse
// @Router /seasons/users/{user_id}/archive [get]
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
