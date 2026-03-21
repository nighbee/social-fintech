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

func validationErr(c *fiber.Ctx, msg string) error {
	return c.Status(400).JSON(fiber.Map{"error": "validation_error", "message": msg})
}

func requireUserID(c *fiber.Ctx) (string, bool) {
	id, ok := c.Locals("user_id").(string)
	return id, ok && id != ""
}

// CreateTask godoc
// @Summary Create a map task
// @Description Creates a task at the given coordinates. Charges 1–3 Silver Seals upfront.
// @Description The response includes `verification_code` which is shown ONLY to the creator
// @Description and must be shared with helpers out-of-band (via chat) to verify completion.
// @Description A 7-day cooldown applies between task creations per user.
// @Tags Tasks
// @Accept json
// @Produce json
// @Security Bearer
// @Param request body CreateTaskRequest true "Task creation payload"
// @Success 201 {object} CreateTaskResponse
// @Failure 400 {object} map[string]string "Validation error (invalid_title | invalid_reward | invalid_workers | invalid_coordinates)"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 402 {object} map[string]string "Insufficient Silver Seals"
// @Failure 429 {object} map[string]string "Cooldown active — must wait 7 days"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /tasks [post]
func (h *Handler) CreateTask(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	var req CreateTaskRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_body"})
	}

	task, err := h.service.CreateTask(c.Context(), userID, &req)
	if err != nil {
		switch err {
		case ErrInvalidTitle, ErrInvalidCoordinates, ErrInvalidReward, ErrInvalidWorkers:
			return validationErr(c, err.Error())
		case ErrCooldownActive:
			return c.Status(429).JSON(fiber.Map{"error": "cooldown_active", "message": err.Error()})
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

	return c.Status(201).JSON(task)
}

// GetNearbyTasks godoc
// @Summary Find tasks nearby
// @Description Returns open tasks within a given radius (metres) of the provided coordinates.
// @Tags Tasks
// @Produce json
// @Security Bearer
// @Param lat query number true "Latitude"
// @Param lon query number true "Longitude"
// @Param radius_m query number false "Radius in metres" default(2000)
// @Param limit query int false "Max results" default(50)
// @Success 200 {object} NearbyTasksResponse
// @Failure 400 {object} map[string]string "Invalid coordinates"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /tasks/nearby [get]
func (h *Handler) GetNearbyTasks(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
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

	resp, err := h.service.GetNearbyTasks(c.Context(), userID, lat, lon, radius, limit)
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

// GetAppliedTasks godoc
// @Summary Find tasks applied to
// @Description Returns tasks that the worker has applied to.
// @Tags Tasks
// @Produce json
// @Security Bearer
// @Success 200 {object} AppliedTasksResponse
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /tasks/applied [get]
func (h *Handler) GetAppliedTasks(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	resp, err := h.service.GetAppliedTasks(c.Context(), userID)
	if err != nil {
		logger.Error("failed to get applied tasks",
			zap.String("user_id", userID),
			zap.String("request_id", c.Get("X-Request-Id")),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "applied_tasks_fetch_failed"})
	}

	return c.JSON(resp)
}

// GetMyTasks godoc
// @Summary List tasks created by me
// @Description Returns all tasks where the caller is the creator.
// @Tags Tasks
// @Produce json
// @Security Bearer
// @Success 200 {object} AppliedTasksResponse
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /tasks/my [get]
func (h *Handler) GetMyTasks(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	resp, err := h.service.GetMyTasks(c.Context(), userID)
	if err != nil {
		logger.Error("failed to get my tasks",
			zap.String("user_id", userID),
			zap.String("request_id", c.Get("X-Request-Id")),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "my_tasks_fetch_failed"})
	}

	return c.JSON(resp)
}

// GetTask godoc
// @Summary Get task details
// @Description Returns the details of a single task.
// @Tags Tasks
// @Produce json
// @Security Bearer
// @Param task_id path string true "Task ID"
// @Success 200 {object} TaskResponse
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 404 {object} map[string]string "Task not found"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /tasks/{task_id} [get]
func (h *Handler) GetTask(c *fiber.Ctx) error {
	_, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	taskID := c.Params("task_id")
	if taskID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_task_id"})
	}

	resp, err := h.service.GetTask(c.Context(), taskID)
	if err != nil {
		if err == ErrTaskNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "task_not_found"})
		}
		logger.Error("failed to get task",
			zap.String("task_id", taskID),
			zap.String("request_id", c.Get("X-Request-Id")),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "task_fetch_failed"})
	}

	return c.JSON(resp)
}

// CancelTask godoc
// @Summary Cancel a task (creator only)
// @Description Cancels an open task and refunds the Silver Seal charge to the creator.
// @Description Only allowed while no worker has been confirmed yet (workers_filled == 0).
// @Tags Tasks
// @Produce json
// @Security Bearer
// @Param task_id path string true "Task ID"
// @Success 200 {object} CancelTaskResponse
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 403 {object} map[string]string "Not the task creator"
// @Failure 404 {object} map[string]string "Task not found"
// @Failure 409 {object} map[string]string "Task already completed or cancelled, or has active workers"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /tasks/{task_id} [delete]
func (h *Handler) CancelTask(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	taskID := c.Params("task_id")
	if taskID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_task_id"})
	}

	resp, err := h.service.CancelTask(c.Context(), userID, taskID)
	if err != nil {
		switch err {
		case ErrTaskNotFound:
			return c.Status(404).JSON(fiber.Map{"error": "task_not_found"})
		case ErrNotTaskOwner:
			return c.Status(403).JSON(fiber.Map{"error": "forbidden"})
		case ErrTaskCompleted:
			return c.Status(409).JSON(fiber.Map{"error": "task_already_completed"})
		case ErrTaskCancelled:
			return c.Status(409).JSON(fiber.Map{"error": "task_already_cancelled"})
		case ErrTaskFull:
			return c.Status(409).JSON(fiber.Map{"error": "task_has_active_workers"})
		default:
			logger.Error("failed to cancel task",
				zap.String("task_id", taskID),
				zap.String("user_id", userID),
				zap.String("request_id", c.Get("X-Request-Id")),
				zap.Error(err),
			)
			return c.Status(500).JSON(fiber.Map{"error": "task_cancel_failed"})
		}
	}

	return c.JSON(resp)
}

// ApplyToTask godoc
// @Summary Apply to help with a task ("I can help")
// @Description User2 applies to help with the given task. Creates a pending application
// @Description and opens a direct chat between the applicant and the creator.
// @Tags Tasks
// @Produce json
// @Security Bearer
// @Param task_id path string true "Task ID"
// @Success 201 {object} ApplyToTaskResponse
// @Failure 400 {object} map[string]string "Cannot apply to your own task"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 404 {object} map[string]string "Task not found"
// @Failure 409 {object} map[string]string "Already applied | Task full | Task not open"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /tasks/{task_id}/apply [post]
func (h *Handler) ApplyToTask(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	taskID := c.Params("task_id")
	if taskID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_task_id"})
	}

	resp, err := h.service.ApplyToTask(c.Context(), userID, taskID)
	if err != nil {
		switch err {
		case ErrTaskNotFound:
			return c.Status(404).JSON(fiber.Map{"error": "task_not_found"})
		case ErrSelfComplete:
			return c.Status(400).JSON(fiber.Map{"error": "cannot_apply_to_own_task"})
		case ErrAlreadyApplied:
			return c.Status(409).JSON(fiber.Map{"error": "already_applied"})
		case ErrTaskFull:
			return c.Status(409).JSON(fiber.Map{"error": "task_full"})
		case ErrTaskCompleted:
			return c.Status(409).JSON(fiber.Map{"error": "task_already_completed"})
		case ErrTaskCancelled:
			return c.Status(409).JSON(fiber.Map{"error": "task_cancelled"})
		default:
			logger.Error("failed to apply to task",
				zap.String("task_id", taskID),
				zap.String("user_id", userID),
				zap.String("request_id", c.Get("X-Request-Id")),
				zap.Error(err),
			)
			return c.Status(500).JSON(fiber.Map{"error": "apply_failed"})
		}
	}

	return c.Status(201).JSON(resp)
}

// SubmitVerificationCode godoc
// @Summary Submit the 4-digit verification code (helper)
// @Description User2 enters the code they received from the creator in chat.
// @Description On success the application moves to `code_verified` status,
// @Description which enables the creator to confirm completion.
// @Tags Tasks
// @Accept json
// @Produce json
// @Security Bearer
// @Param task_id path string true "Task ID"
// @Param application_id path string true "Application ID"
// @Param request body SubmitVerificationCodeRequest true "4-digit code"
// @Success 200 {object} VerifyCodeResponse
// @Failure 400 {object} map[string]string "Wrong code"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 403 {object} map[string]string "Not the applicant"
// @Failure 404 {object} map[string]string "Application not found"
// @Failure 409 {object} map[string]string "Code already verified"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /tasks/{task_id}/applications/{application_id}/verify-code [post]
func (h *Handler) SubmitVerificationCode(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	taskID := c.Params("task_id")
	applicationID := c.Params("application_id")
	if taskID == "" || applicationID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_params"})
	}

	var req SubmitVerificationCodeRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_body"})
	}
	if len(req.Code) != 4 {
		return validationErr(c, "code must be exactly 4 digits")
	}

	resp, err := h.service.SubmitVerificationCode(c.Context(), userID, taskID, applicationID, req.Code)
	if err != nil {
		switch err {
		case ErrApplicationNotFound:
			return c.Status(404).JSON(fiber.Map{"error": "application_not_found"})
		case ErrNotApplicant:
			return c.Status(403).JSON(fiber.Map{"error": "forbidden"})
		case ErrInvalidCode:
			return c.Status(400).JSON(fiber.Map{"error": "invalid_code"})
		case ErrAlreadyVerified:
			return c.Status(409).JSON(fiber.Map{"error": "already_verified"})
		case ErrTaskNotFound:
			return c.Status(404).JSON(fiber.Map{"error": "task_not_found"})
		default:
			logger.Error("failed to verify code",
				zap.String("task_id", taskID),
				zap.String("application_id", applicationID),
				zap.String("user_id", userID),
				zap.String("request_id", c.Get("X-Request-Id")),
				zap.Error(err),
			)
			return c.Status(500).JSON(fiber.Map{"error": "verify_code_failed"})
		}
	}

	return c.JSON(resp)
}

// ConfirmCompletion godoc
// @Summary Confirm a helper completed the task (creator only)
// @Description User1 presses "Yes, this person helped me" in the confirmation popup.
// @Description The application must already be in `code_verified` status.
// @Description Triggers a Silver Seal transfer to the helper and increments `workers_filled`.
// @Description When `workers_filled` reaches `workers_needed` the task moves to `completed`.
// @Tags Tasks
// @Produce json
// @Security Bearer
// @Param task_id path string true "Task ID"
// @Param application_id path string true "Application ID"
// @Success 200 {object} ConfirmCompletionResponse
// @Failure 400 {object} map[string]string "Application not in code_verified state"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 403 {object} map[string]string "Not the task creator"
// @Failure 404 {object} map[string]string "Task or application not found"
// @Failure 409 {object} map[string]string "Task already completed or cancelled"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /tasks/{task_id}/applications/{application_id}/confirm [post]
func (h *Handler) ConfirmCompletion(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	taskID := c.Params("task_id")
	applicationID := c.Params("application_id")
	if taskID == "" || applicationID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_params"})
	}

	resp, err := h.service.ConfirmCompletion(c.Context(), userID, taskID, applicationID)
	if err != nil {
		switch err {
		case ErrTaskNotFound:
			return c.Status(404).JSON(fiber.Map{"error": "task_not_found"})
		case ErrApplicationNotFound:
			return c.Status(404).JSON(fiber.Map{"error": "application_not_found"})
		case ErrNotTaskOwner:
			return c.Status(403).JSON(fiber.Map{"error": "forbidden"})
		case ErrNotConfirmable:
			return c.Status(400).JSON(fiber.Map{"error": "application_not_code_verified"})
		case ErrTaskCompleted:
			return c.Status(409).JSON(fiber.Map{"error": "task_already_completed"})
		case ErrTaskCancelled:
			return c.Status(409).JSON(fiber.Map{"error": "task_cancelled"})
		default:
			logger.Error("failed to confirm completion",
				zap.String("task_id", taskID),
				zap.String("application_id", applicationID),
				zap.String("user_id", userID),
				zap.String("request_id", c.Get("X-Request-Id")),
				zap.Error(err),
			)
			return c.Status(500).JSON(fiber.Map{"error": "confirm_failed"})
		}
	}

	return c.JSON(resp)
}

// GetTaskApplications godoc
// @Summary List applicants for a task (creator only)
// @Description Returns all applications for the given task.
// @Description Only the task creator can call this endpoint.
// @Tags Tasks
// @Produce json
// @Security Bearer
// @Param task_id path string true "Task ID"
// @Success 200 {array} ApplicationResponse
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 403 {object} map[string]string "Not the task creator"
// @Failure 404 {object} map[string]string "Task not found"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /tasks/{task_id}/applications [get]
func (h *Handler) GetTaskApplications(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	taskID := c.Params("task_id")
	if taskID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_task_id"})
	}

	apps, err := h.service.GetTaskApplications(c.Context(), userID, taskID)
	if err != nil {
		switch err {
		case ErrTaskNotFound:
			return c.Status(404).JSON(fiber.Map{"error": "task_not_found"})
		case ErrNotTaskOwner:
			return c.Status(403).JSON(fiber.Map{"error": "forbidden"})
		default:
			logger.Error("failed to get task applications",
				zap.String("task_id", taskID),
				zap.String("user_id", userID),
				zap.String("request_id", c.Get("X-Request-Id")),
				zap.Error(err),
			)
			return c.Status(500).JSON(fiber.Map{"error": "fetch_applications_failed"})
		}
	}

	return c.JSON(apps)
}

// AcceptApplication godoc
// @Summary Accept a helper's application (creator only)
// @Description Marks an application as accepted, allowing the helper to proceed.
// @Tags Tasks
// @Produce json
// @Security Bearer
// @Param task_id path string true "Task ID"
// @Param application_id path string true "Application ID"
// @Success 200 {object} map[string]string "Success"
// @Failure 400 {object} map[string]string "Application not pending"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 403 {object} map[string]string "Not the task creator"
// @Failure 404 {object} map[string]string "Task or application not found"
// @Failure 409 {object} map[string]string "Task is already full"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /tasks/{task_id}/applications/{application_id}/accept [post]
func (h *Handler) AcceptApplication(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	taskID := c.Params("task_id")
	applicationID := c.Params("application_id")
	if taskID == "" || applicationID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_params"})
	}

	err := h.service.AcceptApplication(c.Context(), userID, taskID, applicationID)
	if err != nil {
		switch err {
		case ErrTaskNotFound:
			return c.Status(404).JSON(fiber.Map{"error": "task_not_found"})
		case ErrApplicationNotFound:
			return c.Status(404).JSON(fiber.Map{"error": "application_not_found"})
		case ErrNotTaskOwner:
			return c.Status(403).JSON(fiber.Map{"error": "forbidden"})
		case ErrTaskFull:
			return c.Status(409).JSON(fiber.Map{"error": "task_full"})
		default:
			// Using string match since simple fmt.Errorf was used in service
			if err.Error() == "application is not pending" {
				return c.Status(400).JSON(fiber.Map{"error": "application_not_pending"})
			}
			logger.Error("failed to accept application",
				zap.String("task_id", taskID),
				zap.String("application_id", applicationID),
				zap.String("user_id", userID),
				zap.String("request_id", c.Get("X-Request-Id")),
				zap.Error(err),
			)
			return c.Status(500).JSON(fiber.Map{"error": "accept_failed"})
		}
	}

	return c.JSON(fiber.Map{"status": "accepted"})
}

// RejectApplication godoc
// @Summary Reject a helper's application (creator only)
// @Description Marks an application as rejected.
// @Tags Tasks
// @Produce json
// @Security Bearer
// @Param task_id path string true "Task ID"
// @Param application_id path string true "Application ID"
// @Success 200 {object} map[string]string "Success"
// @Failure 400 {object} map[string]string "Application not pending"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 403 {object} map[string]string "Not the task creator"
// @Failure 404 {object} map[string]string "Task or application not found"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /tasks/{task_id}/applications/{application_id}/reject [post]
func (h *Handler) RejectApplication(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	taskID := c.Params("task_id")
	applicationID := c.Params("application_id")
	if taskID == "" || applicationID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_params"})
	}

	err := h.service.RejectApplication(c.Context(), userID, taskID, applicationID)
	if err != nil {
		switch err {
		case ErrTaskNotFound:
			return c.Status(404).JSON(fiber.Map{"error": "task_not_found"})
		case ErrApplicationNotFound:
			return c.Status(404).JSON(fiber.Map{"error": "application_not_found"})
		case ErrNotTaskOwner:
			return c.Status(403).JSON(fiber.Map{"error": "forbidden"})
		default:
			if err.Error() == "application is not pending" {
				return c.Status(400).JSON(fiber.Map{"error": "application_not_pending"})
			}
			logger.Error("failed to reject application",
				zap.String("task_id", taskID),
				zap.String("application_id", applicationID),
				zap.String("user_id", userID),
				zap.String("request_id", c.Get("X-Request-Id")),
				zap.Error(err),
			)
			return c.Status(500).JSON(fiber.Map{"error": "reject_failed"})
		}
	}

	return c.JSON(fiber.Map{"status": "rejected"})
}

// WithdrawApplication godoc
// @Summary Withdraw an application (helper only)
// @Description Executor withdraws/cancels their pending or accepted application, removing it from the task.
// @Tags Tasks
// @Produce json
// @Security Bearer
// @Param task_id path string true "Task ID"
// @Param application_id path string true "Application ID"
// @Success 200 {object} map[string]string "Success"
// @Failure 400 {object} map[string]string "Cannot withdraw"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 403 {object} map[string]string "Not the applicant"
// @Failure 404 {object} map[string]string "Task or application not found"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /tasks/{task_id}/applications/{application_id} [delete]
func (h *Handler) WithdrawApplication(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	taskID := c.Params("task_id")
	applicationID := c.Params("application_id")
	if taskID == "" || applicationID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_params"})
	}

	err := h.service.WithdrawApplication(c.Context(), userID, taskID, applicationID)
	if err != nil {
		switch err {
		case ErrApplicationNotFound:
			return c.Status(404).JSON(fiber.Map{"error": "application_not_found"})
		case ErrNotApplicant:
			return c.Status(403).JSON(fiber.Map{"error": "forbidden_not_applicant"})
		default:
			if err.Error() == "cannot withdraw after code verified or confirmed" {
				return c.Status(400).JSON(fiber.Map{"error": "cannot_withdraw_now"})
			}
			logger.Error("failed to withdraw application",
				zap.String("task_id", taskID),
				zap.String("application_id", applicationID),
				zap.String("user_id", userID),
				zap.String("request_id", c.Get("X-Request-Id")),
				zap.Error(err),
			)
			return c.Status(500).JSON(fiber.Map{"error": "withdraw_failed"})
		}
	}

	return c.JSON(fiber.Map{"status": "withdrawn"})
}

// CompleteTask is the legacy single-actor completion path.
// Deprecated: kept only for backward compatibility (no route registered).
func (h *Handler) CompleteTask(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
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
			logger.Error("failed to complete task (legacy)",
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
// @Description Assigns H3 cells (res 2/4/5) based on current location and privacy settings
// @Tags Map
// @Accept json
// @Produce json
// @Security Bearer
// @Param request body RegionAssignmentRequest true "Region assignment"
// @Success 200 {object} RegionAssignmentResponse
// @Failure 400 {object} map[string]string "Invalid coordinates"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /map/region [post]
func (h *Handler) SetUserRegion(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
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
// @Description Returns the current champion for each of the supplied H3 cell indices
// @Description at the given resolution and ISO week. Used by the Flutter map to render
// @Description champion pins on the visible viewport.
// @Tags Map
// @Produce json
// @Security Bearer
// @Param h3 query string true "Comma-separated H3 cell IDs (e.g. 852830803fffffff,852830813fffffff)"
// @Param resolution query int false "H3 resolution (2=country, 4=city, 5=district)" default(5)
// @Param year query int false "Year (defaults to current)"
// @Param week query int false "ISO week number (defaults to current)"
// @Success 200 {array} ChampionPin
// @Failure 400 {object} map[string]string "Missing h3 parameter"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /map/champions [get]
func (h *Handler) GetRegionChampions(c *fiber.Ctx) error {
	if _, ok := requireUserID(c); !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	raw := c.Query("h3")
	if raw == "" {
		return c.Status(400).JSON(fiber.Map{"error": "missing_h3"})
	}
	resolution := c.QueryInt("resolution", 5)
	explicitYear := c.Query("year") != ""
	explicitWeek := c.Query("week") != ""
	currentYear, currentWeek := time.Now().ISOWeek()
	year := c.QueryInt("year", currentYear)
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

	// If the client did not request a specific week and current week is empty,
	// fall back to previous ISO week so Monday starts still show latest champions.
	if len(pins) == 0 && !explicitYear && !explicitWeek {
		prevYear, prevWeek := previousISOWeek(currentYear, currentWeek)
		pins, err = h.service.GetRegionChampions(
			c.Context(),
			h3Indexes,
			resolution,
			prevYear,
			prevWeek,
		)
		if err != nil {
			logger.Error("failed to get previous-week region champions",
				zap.String("request_id", c.Get("X-Request-Id")),
				zap.Error(err),
			)
			return c.Status(500).JSON(fiber.Map{"error": "champions_fetch_failed"})
		}
	}

	return c.JSON(pins)
}

// GetH3AdminHierarchy godoc
// @Summary Resolve H3 cell to administrative regions
// @Description Returns the city, region, and country for a given H3 cell index.
// @Description This endpoint performs a spatial lookup against the administrative_boundaries table
// @Description using the H3 cell's center point. Result is cached in h3_geo_metadata for repeated lookups.
// @Tags Map
// @Produce json
// @Security Bearer
// @Param h3_index path string true "H3 cell index (any resolution)"
// @Success 200 {object} H3AdminLookupResponse
// @Failure 400 {object} map[string]string "Invalid H3 index"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 404 {object} map[string]string "H3 index could not be resolved to admin boundaries"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /map/h3/{h3_index}/admin [get]
func (h *Handler) GetH3AdminHierarchy(c *fiber.Ctx) error {
	if _, ok := requireUserID(c); !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	h3Index := c.Params("h3_index")
	if h3Index == "" {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_h3_index"})
	}

	metadata, err := h.service.ResolveH3ToLocation(c.Context(), h3Index)
	if err != nil {
		logger.Error("failed to resolve H3 to admin hierarchy",
			zap.String("h3_index", h3Index),
			zap.String("request_id", c.Get("X-Request-Id")),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "h3_resolve_failed"})
	}

	if metadata == nil || (metadata.CityName == "" && metadata.CountryName == "") {
		return c.Status(404).JSON(fiber.Map{"error": "h3_not_in_boundaries"})
	}

	resp := &H3AdminLookupResponse{
		H3Index:     h3Index,
		CityName:    metadata.CityName,
		RegionName:  metadata.RegionName,
		CountryName: metadata.CountryName,
		CountryCode: metadata.CountryCode,
		ResolvedAt:  metadata.ResolvedAt.Format("2006-01-02T15:04:05Z"),
	}

	return c.JSON(resp)
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

func previousISOWeek(year, week int) (int, int) {
	if week > 1 {
		return year, week - 1
	}

	prevYear := year - 1
	// ISO week for Dec 28 is always the last ISO week of the year.
	_, lastWeek := time.Date(prevYear, time.December, 28, 0, 0, 0, 0, time.UTC).ISOWeek()
	return prevYear, lastWeek
}
