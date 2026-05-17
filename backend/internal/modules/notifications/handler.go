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
// @Description Returns notifications for the current user. Omit tab for the All tab.
// @Tags Notifications
// @Produce json
// @Security Bearer
// @Param tab    query string false "Tab filter: RECOGNITION, ACTIVITY, TASKS, RANK, SYSTEM"
// @Param cursor query string false "RFC3339 nano timestamp from previous page"
// @Param limit  query int    false "Page size (1-100)" default(30)
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

	var tabPtr *UITab
	if v := c.Query("tab"); v != "" {
		tab := UITab(v)
		tabPtr = &tab
	}

	resp, err := h.service.List(c.Context(), userID, tabPtr, cursorPtr, limit)
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

// RegisterDevice godoc
// @Summary Register a device token for push notifications
// @Description Adds or updates a push token for the authenticated user.
// @Tags Notifications
// @Accept json
// @Produce json
// @Security Bearer
// @Param body body RegisterDeviceRequest true "Device Token Data"
// @Success 204
// @Failure 400 {object} map[string]string
// @Router /notifications/devices [post]
func (h *Handler) RegisterDevice(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}

	var req RegisterDeviceRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_request"})
	}

	if req.Token == "" || req.Platform == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "token_and_platform_required"})
	}

	if err := h.service.RegisterDevice(c.Context(), userID, req); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "registration_failed"})
	}

	return c.SendStatus(fiber.StatusNoContent)
}

// UnregisterDevice godoc
// @Summary Unregister a device token
// @Description Deactivates a push token to stop receiving notifications on that device.
// @Tags Notifications
// @Produce json
// @Security Bearer
// @Param token path string true "Device Token"
// @Success 204
// @Router /notifications/devices/{token} [delete]
func (h *Handler) UnregisterDevice(c *fiber.Ctx) error {
	token := c.Params("token")
	if token == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "token_required"})
	}

	if err := h.service.UnregisterDevice(c.Context(), token); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "unregistration_failed"})
	}

	return c.SendStatus(fiber.StatusNoContent)
}
