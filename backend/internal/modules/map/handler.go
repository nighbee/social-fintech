package mapmodule

import (
	"strconv"
	"time"

	"github.com/brightbund-backend/internal/modules/economy"
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

// CreateTask godoc
// @Summary Create a map task
// @Description Creates a task with location and charges Silver Seals
// @Tags Tasks
// @Accept json
// @Produce json
// @Security Bearer
// @Param request body CreateTaskRequest true "Task creation payload"
// @Success 200 {object} TaskResponse
// @Failure 400 {object} map[string]string "Validation error"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 402 {object} map[string]string "Insufficient funds"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /tasks [post]
func (h *Handler) CreateTask(c *fiber.Ctx) error {
	userID, ok := c.Locals("user_id").(string)
	if !ok || userID == "" {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	var req CreateTaskRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_body"})
	}

	task, err := h.service.CreateTask(c.Context(), userID, &req)
	if err != nil {
		if err == ErrInvalidCoordinates || err == ErrInvalidReward || err == ErrInvalidTitle {
			return c.Status(400).JSON(fiber.Map{"error": "validation_error", "message": err.Error()})
		}
		if economy.IsInsufficientFunds(err) {
			return c.Status(402).JSON(fiber.Map{"error": "insufficient_funds"})
		}
		logger.Error("failed to create task",
			zap.String("user_id", userID),
			zap.String("request_id", c.Get("X-Request-Id")),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "task_create_failed"})
	}

	return c.JSON(task)
}

// GetNearbyTasks godoc
// @Summary Find tasks nearby
// @Description Returns active tasks within a radius (meters)
// @Tags Tasks
// @Accept json
// @Produce json
// @Security Bearer
// @Param lat query number true "Latitude"
// @Param lon query number true "Longitude"
// @Param radius_m query number false "Radius in meters" default(2000)
// @Param limit query int false "Limit" default(50)
// @Success 200 {object} NearbyTasksResponse
// @Failure 400 {object} map[string]string "Validation error"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /tasks/nearby [get]
func (h *Handler) GetNearbyTasks(c *fiber.Ctx) error {
	if _, ok := c.Locals("user_id").(string); !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	lat, err := strconv.ParseFloat(c.Query("lat"), 64)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_lat"})
	}
	lon, err := strconv.ParseFloat(c.Query("lon"), 64)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_lon"})
	}

	radius := 2000.0
	if v := c.Query("radius_m"); v != "" {
		if parsed, err := strconv.ParseFloat(v, 64); err == nil {
			radius = parsed
		}
	}
	limit := c.QueryInt("limit", 50)

	resp, err := h.service.GetNearbyTasks(c.Context(), lat, lon, radius, limit)
	if err != nil {
		if err == ErrInvalidCoordinates {
			return c.Status(400).JSON(fiber.Map{"error": "invalid_coordinates"})
		}
		logger.Error("failed to get nearby tasks",
			zap.String("request_id", c.Get("X-Request-Id")),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "tasks_fetch_failed"})
	}

	return c.JSON(resp)
}

// CompleteTask godoc
// @Summary Complete a task
// @Description Marks task as completed and rewards the user
// @Tags Tasks
// @Produce json
// @Security Bearer
// @Param task_id path string true "Task ID"
// @Success 200 {object} TaskCompletionResponse
// @Failure 400 {object} map[string]string "Validation error"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 404 {object} map[string]string "Task not found"
// @Failure 409 {object} map[string]string "Task already completed"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /tasks/{task_id}/complete [post]
func (h *Handler) CompleteTask(c *fiber.Ctx) error {
	userID, ok := c.Locals("user_id").(string)
	if !ok || userID == "" {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	taskID := c.Params("task_id")
	if taskID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_task_id"})
	}

	resp, err := h.service.CompleteTask(c.Context(), userID, taskID)
	if err != nil {
		switch err {
		case ErrTaskNotFound:
			return c.Status(404).JSON(fiber.Map{"error": "task_not_found"})
		case ErrTaskCompleted:
			return c.Status(409).JSON(fiber.Map{"error": "task_already_completed"})
		case ErrSelfComplete:
			return c.Status(400).JSON(fiber.Map{"error": "cannot_complete_own_task"})
		default:
			logger.Error("failed to complete task",
				zap.String("task_id", taskID),
				zap.String("user_id", userID),
				zap.String("request_id", c.Get("X-Request-Id")),
				zap.Error(err),
			)
			return c.Status(500).JSON(fiber.Map{"error": "task_complete_failed"})
		}
	}

	return c.JSON(resp)
}

// SetUserRegion godoc
// @Summary Set user region using H3
// @Description Assigns H3 cells based on current location and privacy settings
// @Tags Map
// @Accept json
// @Produce json
// @Security Bearer
// @Param request body RegionAssignmentRequest true "Region assignment"
// @Success 200 {object} RegionAssignmentResponse
// @Failure 400 {object} map[string]string "Validation error"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /map/region [post]
func (h *Handler) SetUserRegion(c *fiber.Ctx) error {
	userID, ok := c.Locals("user_id").(string)
	if !ok || userID == "" {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	var req RegionAssignmentRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_body"})
	}

	resp, err := h.service.SetUserRegion(c.Context(), userID, &req)
	if err != nil {
		if err == ErrInvalidCoordinates {
			return c.Status(400).JSON(fiber.Map{"error": "invalid_coordinates"})
		}
		logger.Error("failed to set user region",
			zap.String("user_id", userID),
			zap.String("request_id", c.Get("X-Request-Id")),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "region_update_failed"})
	}

	return c.JSON(resp)
}

// GetRegionChampions godoc
// @Summary Get champions for H3 cells
// @Description Returns champions for a set of H3 indices at a given resolution/week
// @Tags Map
// @Produce json
// @Security Bearer
// @Param h3 query string true "Comma-separated H3 indexes"
// @Param resolution query int true "H3 resolution"
// @Param year query int true "Year"
// @Param week query int true "ISO week number"
// @Success 200 {array} ChampionPin
// @Failure 400 {object} map[string]string "Validation error"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /map/champions [get]
func (h *Handler) GetRegionChampions(c *fiber.Ctx) error {
	if _, ok := c.Locals("user_id").(string); !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	raw := c.Query("h3")
	if raw == "" {
		return c.Status(400).JSON(fiber.Map{"error": "missing_h3"})
	}
	resolution := c.QueryInt("resolution", 5)
	year := c.QueryInt("year", time.Now().Year())
	_, week := time.Now().ISOWeek()
	week = c.QueryInt("week", week)

	h3Indexes := splitCSV(raw)
	pins, err := h.service.GetRegionChampions(c.Context(), h3Indexes, resolution, year, week)
	if err != nil {
		logger.Error("failed to get region champions",
			zap.String("request_id", c.Get("X-Request-Id")),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "champions_fetch_failed"})
	}

	return c.JSON(pins)
}

func splitCSV(raw string) []string {
	var out []string
	start := 0
	for i := 0; i <= len(raw); i++ {
		if i == len(raw) || raw[i] == ',' {
			if i > start {
				out = append(out, raw[start:i])
			}
			start = i + 1
		}
	}
	return out
}
