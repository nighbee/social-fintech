package economy

import (
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

type Handler struct {
	service Service
}

func NewHandler(service Service) *Handler {
	return &Handler{
		service: service,
	}
}

// GetBalance godoc
// @Summary Get user wallet balance
// @Description Returns the current balance for Silver and Gold Seals
// @Tags Economy
// @Accept json
// @Produce json
// @Security Bearer
// @Success 200 {object} BalanceResponse
// @Failure 401 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /economy/balance [get]
func (h *Handler) GetBalance(c *fiber.Ctx) error {
	userID, err := getUserIDFromContext(c)
	if err != nil {
		return sendError(c, 401, "UNAUTHORIZED", "Unauthorized")
	}

	balance, err := h.service.GetUserBalance(c.Context(), userID)
	if err != nil {
		return handleServiceError(c, err)
	}

	return c.JSON(balance)
}

// TransferSeals godoc
// @Summary Transfer Seals to another user (P2P)
// @Description Send Silver or Gold Seals to another user
// @Tags Economy
// @Accept json
// @Produce json
// @Security Bearer
// @Param request body TransferRequest true "Transfer details"
// @Success 200 {object} TransferResponse
// @Failure 400 {object} ErrorResponse
// @Failure 402 {object} ErrorResponse "Insufficient funds"
// @Failure 429 {object} ErrorResponse "Transfer limit exceeded"
// @Failure 500 {object} ErrorResponse
// @Router /economy/transfer [post]
func (h *Handler) TransferSeals(c *fiber.Ctx) error {
	userID, err := getUserIDFromContext(c)
	if err != nil {
		return sendError(c, 401, "UNAUTHORIZED", "Unauthorized")
	}

	var req TransferRequest
	if err := c.BodyParser(&req); err != nil {
		return sendError(c, 400, "INVALID_REQUEST", "Invalid request body")
	}

	if req.RecipientUserID == userID {
		return sendError(c, 400, "SELF_TRANSFER", "Cannot transfer to yourself")
	}

	if req.IdempotencyKey == "" {
		req.IdempotencyKey = uuid.New().String()
	}

	response, err := h.service.TransferSeals(c.Context(), userID, &req)
	if err != nil {
		return handleServiceError(c, err)
	}

	return c.JSON(response)
}

// GetTransactionHistory godoc
// @Summary Get transaction history
// @Description Returns paginated transaction history for the authenticated user
// @Tags Economy
// @Accept json
// @Produce json
// @Security Bearer
// @Param page query int false "Page number" default(1)
// @Param page_size query int false "Items per page" default(20)
// @Param category query string false "Filter by category"
// @Success 200 {object} TransactionHistoryResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /economy/history [get]
func (h *Handler) GetTransactionHistory(c *fiber.Ctx) error {
	userID, err := getUserIDFromContext(c)
	if err != nil {
		return sendError(c, 401, "UNAUTHORIZED", "Unauthorized")
	}

	var req TransactionHistoryRequest
	if err := c.QueryParser(&req); err != nil {
		return sendError(c, 400, "INVALID_REQUEST", "Invalid query parameters")
	}

	if req.Page == 0 {
		req.Page = 1
	}
	if req.PageSize == 0 {
		req.PageSize = 20
	}

	history, err := h.service.GetTransactionHistory(c.Context(), userID, &req)
	if err != nil {
		return handleServiceError(c, err)
	}

	return c.JSON(history)
}

// GiveSealToPost godoc
// @Summary Give Seals to a post
// @Description Give 1-10 Seals to a post in the feed
// @Tags Economy
// @Accept json
// @Produce json
// @Security Bearer
// @Param post_id path string true "Post ID"
// @Param request body GiveSealToPostRequest true "Seal amount and currency"
// @Success 200 {object} TransferResponse
// @Failure 400 {object} ErrorResponse
// @Failure 402 {object} ErrorResponse "Insufficient funds"
// @Failure 500 {object} ErrorResponse
// @Router /economy/posts/{post_id}/seals [post]
func (h *Handler) GiveSealToPost(c *fiber.Ctx) error {
	userID, err := getUserIDFromContext(c)
	if err != nil {
		return sendError(c, 401, "UNAUTHORIZED", "Unauthorized")
	}

	postID := c.Params("postID")
	if postID == "" {
		return sendError(c, 400, "INVALID_POST_ID", "Post ID is required")
	}

	var req GiveSealToPostRequest
	if err := c.BodyParser(&req); err != nil {
		return sendError(c, 400, "INVALID_REQUEST", "Invalid request body")
	}

	if req.Amount < 1 || req.Amount > 10 {
		return sendError(c, 400, "INVALID_AMOUNT", "Amount must be between 1 and 10")
	}

	if req.IdempotencyKey == "" {
		req.IdempotencyKey = uuid.New().String()
	}

	response, err := h.service.GiveSealToPost(c.Context(), userID, postID, &req)
	if err != nil {
		return handleServiceError(c, err)
	}

	return c.JSON(response)
}

// GiveSealToUser godoc
// @Summary Gift Seals to another user
// @Description Send Seals as a gift to another user
// @Tags Economy
// @Accept json
// @Produce json
// @Security Bearer
// @Param user_id path string true "Recipient User ID"
// @Param request body GiveSealToUserRequest true "Gift details"
// @Success 200 {object} TransferResponse
// @Failure 400 {object} ErrorResponse
// @Failure 402 {object} ErrorResponse "Insufficient funds"
// @Failure 500 {object} ErrorResponse
// @Router /economy/users/{user_id}/gift [post]
func (h *Handler) GiveSealToUser(c *fiber.Ctx) error {
	userID, err := getUserIDFromContext(c)
	if err != nil {
		return sendError(c, 401, "UNAUTHORIZED", "Unauthorized")
	}

	recipientID := c.Params("userID")
	if recipientID == "" {
		return sendError(c, 400, "INVALID_USER_ID", "User ID is required")
	}

	if recipientID == userID {
		return sendError(c, 400, "SELF_TRANSFER", "Cannot gift to yourself")
	}

	var req GiveSealToUserRequest
	if err := c.BodyParser(&req); err != nil {
		return sendError(c, 400, "INVALID_REQUEST", "Invalid request body")
	}

	if req.IdempotencyKey == "" {
		req.IdempotencyKey = uuid.New().String()
	}

	response, err := h.service.GiveSealToUser(c.Context(), userID, recipientID, &req)
	if err != nil {
		return handleServiceError(c, err)
	}

	return c.JSON(response)
}

// GetLimits godoc
// @Summary Get transfer limits and accrual status
// @Description Returns monthly transfer limits and daily accrual status
// @Tags Economy
// @Accept json
// @Produce json
// @Security Bearer
// @Success 200 {object} LimitsResponse
// @Failure 401 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /economy/limits [get]
func (h *Handler) GetLimits(c *fiber.Ctx) error {
	userID, err := getUserIDFromContext(c)
	if err != nil {
		return sendError(c, 401, "UNAUTHORIZED", "Unauthorized")
	}

	limits, err := h.service.GetLimits(c.Context(), userID)
	if err != nil {
		return handleServiceError(c, err)
	}

	return c.JSON(limits)
}

// GetReferralStats godoc
// @Summary Get referral statistics
// @Description Returns referral statistics for the authenticated user
// @Tags Economy
// @Accept json
// @Produce json
// @Security Bearer
// @Success 200 {object} ReferralStatsResponse
// @Failure 401 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /economy/referrals/stats [get]
func (h *Handler) GetReferralStats(c *fiber.Ctx) error {
	userID, err := getUserIDFromContext(c)
	if err != nil {
		return sendError(c, 401, "UNAUTHORIZED", "Unauthorized")
	}

	stats, err := h.service.GetReferralStats(c.Context(), userID)
	if err != nil {
		return handleServiceError(c, err)
	}

	return c.JSON(stats)
}

// ClaimDailyAccrual godoc
// @Summary Claim daily free Silver accrual
// @Description Claim 0.50 Silver Seal daily bonus (max 5.00 free balance)
// @Tags Economy
// @Accept json
// @Produce json
// @Security Bearer
// @Param request body ClaimDailyAccrualRequest false "Optional idempotency key"
// @Success 200 {object} AccrualResponse
// @Failure 400 {object} ErrorResponse "Already claimed today or cap reached"
// @Failure 401 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /economy/accrual/claim [post]
func (h *Handler) ClaimDailyAccrual(c *fiber.Ctx) error {
	userID, err := getUserIDFromContext(c)
	if err != nil {
		return sendError(c, 401, "UNAUTHORIZED", "Unauthorized")
	}

	var req ClaimDailyAccrualRequest
	if err := c.BodyParser(&req); err != nil {
		req.IdempotencyKey = ""
	}

	if req.IdempotencyKey == "" {
		req.IdempotencyKey = uuid.New().String()
	}

	response, err := h.service.ClaimDailyAccrual(c.Context(), userID, req.IdempotencyKey)
	if err != nil {
		return handleServiceError(c, err)
	}

	return c.JSON(response)
}

// AdminAdjustBalance godoc
// @Summary Admin: Adjust user balance
// @Description Manually adjust a user's balance (admin only)
// @Tags Economy Admin
// @Accept json
// @Produce json
// @Security Bearer
// @Param request body AdjustBalanceRequest true "Adjustment details"
// @Success 200 {object} BalanceResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 403 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /economy/admin/adjust [post]
func (h *Handler) AdminAdjustBalance(c *fiber.Ctx) error {
	var reqRaw map[string]interface{}
	if err := c.BodyParser(&reqRaw); err != nil {
		return sendError(c, 400, "INVALID_REQUEST", "Invalid request body")
	}

	userID, ok := reqRaw["user_id"].(string)
	if !ok || userID == "" {
		return sendError(c, 400, "INVALID_USER_ID", "User ID is required")
	}

	currencyStr, ok := reqRaw["currency"].(string)
	if !ok || currencyStr == "" {
		return sendError(c, 400, "INVALID_CURRENCY", "Currency is required")
	}
	currency := CurrencyCode(currencyStr)

	reason, ok := reqRaw["reason"].(string)
	if !ok || reason == "" {
		return sendError(c, 400, "INVALID_REASON", "Reason is required")
	}

	var amountCents int64
	switch v := reqRaw["amount"].(type) {
	case float64:
		amountCents = SealsToCentinels(v)
	case int64:
		amountCents = v
	case int:
		amountCents = int64(v)
	default:
		return sendError(c, 400, "INVALID_AMOUNT", "Amount must be a number")
	}

	err := h.service.AdminAdjustBalance(c.Context(), userID, amountCents, currency, reason)
	if err != nil {
		return handleServiceError(c, err)
	}

	balance, err := h.service.GetUserBalance(c.Context(), userID)
	if err != nil {
		return handleServiceError(c, err)
	}

	return c.JSON(balance)
}

// GetViolationLogs godoc
// @Summary Admin: Get user violation logs
// @Description Retrieve economy violation audit logs for a specific user (admin only)
// @Tags Economy Admin
// @Accept json
// @Produce json
// @Security Bearer
// @Param user_id query string true "User ID"
// @Param page query int false "Page number" default(1)
// @Param page_size query int false "Items per page" default(20)
// @Success 200 {object} ViolationLogsResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 403 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /economy/admin/violations [get]
func (h *Handler) GetViolationLogs(c *fiber.Ctx) error {
	userID := c.Query("user_id")
	if userID == "" {
		return sendError(c, 400, "INVALID_USER_ID", "User ID is required")
	}

	page := c.QueryInt("page", 1)
	pageSize := c.QueryInt("page_size", 20)

	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}

	offset := (page - 1) * pageSize
	violations, total, err := h.service.GetViolationLogs(c.Context(), userID, pageSize, offset)
	if err != nil {
		return handleServiceError(c, err)
	}

	return c.JSON(ViolationLogsResponse{
		Violations: violations,
		Page:       page,
		PageSize:   pageSize,
		Total:      total,
	})
}

func getUserIDFromContext(c *fiber.Ctx) (string, error) {
	userID := c.Locals("user_id")
	if userID == nil {
		return "", ErrUnauthorized
	}

	userIDStr, ok := userID.(string)
	if !ok {
		return "", ErrUnauthorized
	}

	return userIDStr, nil
}

func handleServiceError(c *fiber.Ctx, err error) error {
	if economyErr, ok := IsEconomyError(err); ok {
		return sendError(c, economyErr.Status, economyErr.Code, economyErr.Message)
	}

	if IsInsufficientFunds(err) {
		if insuffErr, ok := err.(*InsufficientFundsErr); ok {
			return c.Status(402).JSON(ErrorResponse{
				Error:   "INSUFFICIENT_FUNDS",
				Message: insuffErr.Error(),
				Code:    "INSUFFICIENT_FUNDS",
			})
		}
		return sendError(c, 402, "INSUFFICIENT_FUNDS", "Insufficient funds")
	}

	if IsMonthlyLimitExceeded(err) {
		if limitErr, ok := err.(*MonthlyLimitErr); ok {
			return c.Status(429).JSON(ErrorResponse{
				Error:   "TRANSFER_LIMIT",
				Message: limitErr.Error(),
				Code:    "TRANSFER_LIMIT",
			})
		}
		return sendError(c, 429, "TRANSFER_LIMIT", "Monthly transfer limit exceeded")
	}

	if IsCooldownActive(err) {
		if cooldownErr, ok := err.(*CooldownErr); ok {
			return c.Status(429).JSON(ErrorResponse{
				Error:   "COOLDOWN_ACTIVE",
				Message: cooldownErr.Error(),
				Code:    "COOLDOWN_ACTIVE",
			})
		}
		return sendError(c, 429, "COOLDOWN_ACTIVE", "Transfer cooldown active")
	}

	if IsDailyAccrualClaimed(err) {
		if accrualErr, ok := err.(*DailyAccrualErr); ok {
			return c.Status(400).JSON(ErrorResponse{
				Error:   "DAILY_ACCRUAL_CLAIMED",
				Message: accrualErr.Error(),
				Code:    "DAILY_ACCRUAL_CLAIMED",
			})
		}
		return sendError(c, 400, "DAILY_ACCRUAL_CLAIMED", "Daily accrual already claimed")
	}

	if IsNotFoundError(err) {
		return sendError(c, 404, "NOT_FOUND", err.Error())
	}

	if IsDuplicateError(err) {
		return sendError(c, 409, "DUPLICATE", err.Error())
	}

	return sendError(c, 500, "INTERNAL_ERROR", "Internal server error")
}

func sendError(c *fiber.Ctx, status int, code, message string) error {
	return c.Status(status).JSON(ErrorResponse{
		Error:   code,
		Message: message,
		Code:    code,
	})
}
