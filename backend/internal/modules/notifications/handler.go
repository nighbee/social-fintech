package notifications

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

// List godoc
// @Summary List notifications
// @Description Returns notifications for the current user, newest first.
// @Description Cursor is the RFC3339 nano timestamp of the last item from the previous page.
// @Tags Notifications
// @Produce json
// @Security Bearer
// @Param cursor query string false "RFC3339 nano timestamp from previous page"
// @Param limit query int false "Page size (1-100)" default(30)
// @Success 200 {object} ListResponse
// @Failure 401 {object} map[string]string
// @Router /notifications [get]
func (h *Handler) List(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}

	limit := 30
	if v := c.Query("limit"); v != "" {
		if parsed, err := strconv.Atoi(v); err == nil {
			limit = parsed
		}
	}

	var cursorPtr *time.Time
	if v := c.Query("cursor"); v != "" {
		t, err := time.Parse(time.RFC3339Nano, v)
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_cursor"})
		}
		cursorPtr = &t
	}

	resp, err := h.service.List(c.Context(), userID, cursorPtr, limit)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "list_failed"})
	}
	return c.JSON(resp)
}

// UnreadCount godoc
// @Summary Unread count
// @Description Returns the unread notification count for the current user.
// @Tags Notifications
// @Produce json
// @Security Bearer
// @Success 200 {object} UnreadCountResponse
// @Router /notifications/unread-count [get]
func (h *Handler) UnreadCount(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	count, err := h.service.UnreadCount(c.Context(), userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "count_failed"})
	}
	return c.JSON(UnreadCountResponse{Count: count})
}

// MarkRead godoc
// @Summary Mark a notification as read
// @Tags Notifications
// @Produce json
// @Security Bearer
// @Param id path string true "Notification ID"
// @Success 204
// @Router /notifications/{id}/read [post]
func (h *Handler) MarkRead(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_id"})
	}
	if err := h.service.MarkRead(c.Context(), userID, id); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "mark_read_failed"})
	}
	return c.SendStatus(fiber.StatusNoContent)
}

// MarkAllRead godoc
// @Summary Mark all notifications as read
// @Tags Notifications
// @Produce json
// @Security Bearer
// @Success 204
// @Router /notifications/read-all [post]
func (h *Handler) MarkAllRead(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	if err := h.service.MarkAllRead(c.Context(), userID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "mark_all_failed"})
	}
	return c.SendStatus(fiber.StatusNoContent)
}
