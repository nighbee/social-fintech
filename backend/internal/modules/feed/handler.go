package feed

import (
	"errors"

	"github.com/brightbund-backend/internal/modules/economy"
	"github.com/brightbund-backend/internal/platform/logger"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"go.uber.org/zap"
)

type Handler struct {
	service *Service
	worker  *InteractionWorker
	economy economy.Service
}

func NewHandler(service *Service, worker *InteractionWorker, economyService economy.Service) *Handler {
	return &Handler{service: service, worker: worker, economy: economyService}
}

// ... unchanged intermediate ...

// ToggleLike godoc
// @Summary Like a post
// @Description Queues a like interaction through the Redis write-behind worker
// @Tags Feed Interactions
// @Produce json
// @Security Bearer
// @Param post_id path string true "Post UUID"
// @Success 202 {object} map[string]string "Accepted for processing"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Router /api/v1/posts/{post_id}/likes [post]
func (h *Handler) ToggleLike(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	postID, err := uuid.Parse(c.Params("post_id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_post_id"})
	}

	if err := h.worker.QueueLike(c.Context(), postID, userID); err != nil {
		logger.Error("failed queuing like", zap.Error(err))
		return c.Status(500).JSON(fiber.Map{"error": "processing_failed"})
	}

	return c.Status(202).JSON(fiber.Map{"status": "queued"})
}

func validationErr(c *fiber.Ctx, msg string) error {
	return c.Status(400).JSON(fiber.Map{"error": "validation_error", "message": msg})
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

// GetFeedState godoc
// @Summary Fetch current feed fatigue state
// @Description Calculates background decay and returns the current fatigue seconds
// @Tags Feed
// @Produce json
// @Security Bearer
// @Success 200 {object} FeedStateResponse
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /api/v1/feed/state [get]
func (h *Handler) GetFeedState(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	state, err := h.service.GetFeedState(c.Context(), userID)
	if err != nil {
		logger.Error("failed to get feed state",
			zap.String("user_id", userID.String()),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "internal_error"})
	}

	return c.JSON(state)
}

// SyncFeedState godoc
// @Summary Sync active feed time
// @Description Pings the server with DeltaSeconds. Evaluated by anti-cheat engine.
// @Tags Feed
// @Accept json
// @Produce json
// @Security Bearer
// @Param request body SyncFeedStateRequest true "Sync payload"
// @Success 200 {object} FeedStateResponse
// @Failure 400 {object} map[string]string "Validation error"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /api/v1/feed/state/sync [post]
func (h *Handler) SyncFeedState(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	var req SyncFeedStateRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_body"})
	}

	state, err := h.service.SyncFeedState(c.Context(), userID, &req)
	if err != nil {
		if err == ErrInvalidDelta {
			return validationErr(c, err.Error())
		}
		logger.Error("failed to sync feed state",
			zap.String("user_id", userID.String()),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "internal_error"})
	}

	return c.JSON(state)
}

// CreatePost godoc
// @Summary Create a new feed post
// @Description Create a post containing text, media attachments, and privacy controls
// @Tags Feed
// @Accept json
// @Produce json
// @Security Bearer
// @Param request body CreatePostRequest true "Post creation payload"
// @Success 201 {object} map[string]string "Success"
// @Failure 400 {object} map[string]string "Validation error"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Router /api/v1/posts [post]
func (h *Handler) CreatePost(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	var req CreatePostRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_body"})
	}

	// Basic validation
	if req.Visibility != VisibilityAnyone && req.Visibility != VisibilityAlliesOnly {
		return validationErr(c, "invalid visibility")
	}
	if req.CommentPermission != CommentPermAnyone && req.CommentPermission != CommentPermAlliesOnly && req.CommentPermission != CommentPermNoOne {
		return validationErr(c, "invalid comment_permission")
	}

	if err := h.service.CreatePost(c.Context(), userID, &req); err != nil {
		if err == ErrPostRequiresMedia {
			return validationErr(c, err.Error())
		}
		logger.Error("failed to create post",
			zap.String("user_id", userID.String()),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "post_create_failed"})
	}

	return c.Status(201).JSON(fiber.Map{"status": "success"})
}

// GetFeed godoc
// @Summary Get mixed feed
// @Description Fetch mixed feed (Allies + Local Geo + World)
// @Tags Feed
// @Produce json
// @Security Bearer
// @Param cursor query string false "Pagination cursor"
// @Param limit query int false "Max results" default(20)
// @Success 200 {object} FeedResponse
// @Failure 401 {object} map[string]string "Unauthorized"
// @Router /api/v1/feed [get]
func (h *Handler) GetFeed(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	cursor := c.Query("cursor")
	limit := c.QueryInt("limit", 20)

	resp, err := h.service.GetFeed(c.Context(), userID, cursor, limit)
	if err != nil {
		logger.Error("failed to fetch feed", zap.Error(err))
		return c.Status(500).JSON(fiber.Map{"error": "feed_fetch_failed"})
	}

	return c.JSON(resp)
}

// CreateComment godoc
// @Summary Comment on a post
// @Description Comment or reply on a specific post
// @Tags Feed
// @Accept json
// @Produce json
// @Security Bearer
// @Param post_id path string true "Post UUID"
// @Param request body CreateCommentRequest true "Comment payload"
// @Success 201 {object} map[string]string "Success"
// @Failure 400 {object} map[string]string "Validation error"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 403 {object} map[string]string "Commenting disabled or restricted"
// @Router /api/v1/posts/{post_id}/comments [post]
func (h *Handler) CreateComment(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	postIDStr := c.Params("post_id")
	postID, err := uuid.Parse(postIDStr)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_post_id"})
	}

	var req CreateCommentRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_body"})
	}

	if err := h.service.CreateComment(c.Context(), userID, postID, &req); err != nil {
		if err == ErrCommentRequiresText {
			return validationErr(c, err.Error())
		}
		if err == ErrCommentNotAllowed {
			return c.Status(403).JSON(fiber.Map{"error": "comment_not_allowed"})
		}
		if err == ErrPostNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "post_not_found"})
		}
		logger.Error("failed to create comment", zap.Error(err))
		return c.Status(500).JSON(fiber.Map{"error": "comment_create_failed"})
	}

	return c.Status(201).JSON(fiber.Map{"status": "success"})
}

// GetThreadedComments godoc
// @Summary Get post comments
// @Description Fetch threaded comments for a specific post. Pass parent_id to get replies for a specific comment.
// @Tags Feed
// @Produce json
// @Security Bearer
// @Param post_id path string true "Post UUID"
// @Param parent_id query string false "Optional comment UUID to fetch replies for"
// @Param cursor query string false "Pagination cursor"
// @Param limit query int false "Max results" default(50)
// @Success 200 {object} ThreadedCommentsResponse
// @Failure 401 {object} map[string]string "Unauthorized"
// @Router /api/v1/posts/{post_id}/comments [get]
func (h *Handler) GetThreadedComments(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	postIDStr := c.Params("post_id")
	postID, err := uuid.Parse(postIDStr)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_post_id"})
	}

	var parentIDPtr *uuid.UUID
	parentIDStr := c.Query("parent_id")
	if parentIDStr != "" {
		parentID, err := uuid.Parse(parentIDStr)
		if err != nil {
			return c.Status(400).JSON(fiber.Map{"error": "invalid_parent_id"})
		}
		parentIDPtr = &parentID
	}

	cursor := c.Query("cursor")
	limit := c.QueryInt("limit", 50)

	resp, err := h.service.GetThreadedComments(c.Context(), userID, postID, parentIDPtr, cursor, limit)
	if err != nil {
		logger.Error("failed to fetch comments", zap.Error(err))
		return c.Status(500).JSON(fiber.Map{"error": "comments_fetch_failed"})
	}

	return c.JSON(resp)
}

// GetLikes godoc
// @Summary Fetch post likes
// @Description Fetch paginated list of users who liked the post
// @Tags Feed Interactions
// @Produce json
// @Param post_id path string true "Post UUID"
// @Success 200 {object} InteractionListResponse
// @Router /api/v1/posts/{post_id}/likes [get]
func (h *Handler) GetLikes(c *fiber.Ctx) error {
	postID, err := uuid.Parse(c.Params("post_id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_post_id"})
	}

	resp, err := h.service.GetInteractions(c.Context(), postID, "like", c.Query("cursor"), c.QueryInt("limit", 50))
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "fetch_failed"})
	}
	return c.JSON(resp)
}

// SendSeal godoc
// @Summary Give Silver Seal to post (Economy)
// @Description Deducts silver from the viewer and credits the post author. Validates balance, cooldown, and self-seal rules via the Economy module.
// @Tags Feed Interactions
// @Accept json
// @Produce json
// @Security Bearer
// @Param post_id path string true "Post UUID"
// @Param request body SendSealRequest true "Seal Request"
// @Success 201 {object} map[string]interface{} "Seal sent — returns ledger_entry_id and new sender balance"
// @Failure 400 {object} map[string]string
// @Failure 402 {object} map[string]string "insufficient_balance"
// @Failure 429 {object} map[string]string "cooldown active"
// @Router /api/v1/posts/{post_id}/seals [post]
func (h *Handler) SendSeal(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	postID, err := uuid.Parse(c.Params("post_id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_post_id"})
	}

	var req SendSealRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_request_body"})
	}

	if req.Amount <= 0 {
		return c.Status(400).JSON(fiber.Map{"error": ErrInvalidSealAmount.Error()})
	}

	// Resolve the post author so Economy knows who receives the Silver.
	// GetPostPermissionsInfo returns (commentPermission, authorID, error).
	_, authorID, err := h.service.repo.GetPostPermissionsInfo(c.Context(), postID)
	if err != nil {
		return c.Status(404).JSON(fiber.Map{"error": ErrPostNotFound.Error()})
	}

	// Prevent self-sealing.
	if authorID == userID {
		return c.Status(400).JSON(fiber.Map{"error": ErrSealOwnPost.Error()})
	}

	// Build the idempotency key from viewer+post+comment so duplicate taps are safe.
	idempotencyKey := uuid.NewSHA1(uuid.NameSpaceURL, []byte(userID.String()+":"+postID.String())).String()

	// Call Economy — handles wallet debit, ledger entry, cooldown, monthly limit.
	txResp, err := h.economy.GiveSealToPost(c.Context(), userID.String(), postID.String(), &economy.GiveSealToPostRequest{
		ReceiverUserID: authorID.String(),
		Amount:         req.Amount,
		Currency:       "SILVER_SEAL",
		IdempotencyKey: idempotencyKey,
	})
	if err != nil {
		log := logger.Get()
		log.Warn("seal economy error", zap.String("user", userID.String()), zap.Error(err))

		// Map economy errors to HTTP status codes.
		switch {
		case economy.IsInsufficientFunds(err):
			return c.Status(402).JSON(fiber.Map{"error": ErrInsufficientBalance.Error()})
		case economy.IsCooldownActive(err):
			return c.Status(429).JSON(fiber.Map{"error": "cooldown_active", "detail": err.Error()})
		case economy.IsMonthlyLimitExceeded(err):
			return c.Status(429).JSON(fiber.Map{"error": "monthly_limit_exceeded"})
		case errors.Is(err, economy.ErrOptimisticLockFailure):
			return c.Status(409).JSON(fiber.Map{"error": "transaction_conflict", "detail": "please retry"})
		default:
			return c.Status(500).JSON(fiber.Map{"error": "seal_failed"})
		}
	}

	// Queue denormalization: increment seals_count and seals_amount on the post.
	_ = h.worker.QueueSeal(postID, req.Amount)

	return c.Status(201).JSON(fiber.Map{
		"status":          "seal_sent",
		"ledger_entry_id": txResp.LedgerEntryID,
		"new_balance":     txResp.SenderBalance,
	})
}

// contains is a simple substring helper to avoid importing strings twice.
func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > 0 &&
		func() bool {
			for i := 0; i <= len(s)-len(substr); i++ {
				if s[i:i+len(substr)] == substr {
					return true
				}
			}
			return false
		}())
}

// GetSeals godoc
// @Summary Fetch post seals
// @Description Fetch all users who contributed Silver Seals and their messages
// @Tags Feed Interactions
// @Produce json
// @Param post_id path string true "Post UUID"
// @Success 200 {object} SealListResponse
// @Router /api/v1/posts/{post_id}/seals [get]
func (h *Handler) GetSeals(c *fiber.Ctx) error {
	postID, err := uuid.Parse(c.Params("post_id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_post_id"})
	}

	resp, err := h.service.GetSeals(c.Context(), postID, c.Query("cursor"), c.QueryInt("limit", 50))
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "fetch_failed"})
	}
	return c.JSON(resp)
}
