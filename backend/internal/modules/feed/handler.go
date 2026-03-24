package feed

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/url"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/brightbund-backend/internal/modules/economy"
	"github.com/brightbund-backend/internal/platform/logger"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"go.uber.org/zap"
)

type ObjectStorage interface {
	Upload(ctx context.Context, objectName string, reader io.Reader, size int64, contentType string) (string, error)
}

type Handler struct {
	service   *Service
	worker    *InteractionWorker
	economy   economy.Service
	storage   ObjectStorage
	publicURL string
}

func NewHandler(service *Service, worker *InteractionWorker, economyService economy.Service, storageClient ObjectStorage, publicURL string) *Handler {
	return &Handler{service: service, worker: worker, economy: economyService, storage: storageClient, publicURL: publicURL}
}

// Constants for media upload hardening (SAFETY)
const (
	// Maximum file sizes by MIME category
	maxImageSizeBytes = 10 * 1024 * 1024  // 10 MB for images (PNG, JPEG, WebP)
	maxVideoSizeBytes = 100 * 1024 * 1024 // 100 MB for videos (MP4, WebM)
)

// Allowed MIME types (whitelist defense against abuse)
var allowedImageMimes = map[string]bool{
	"image/jpeg": true,
	"image/png":  true,
	"image/webp": true,
}

var allowedVideoMimes = map[string]bool{
	"video/mp4":       true,
	"video/webm":      true,
	"video/quicktime": true, // MOV files (iOS)
}

// UploadMedia godoc
// @Summary Upload media
// @Description Uploads an image or video and returns its URL with size/MIME validation
// @Tags Feed
// @Accept multipart/form-data
// @Produce json
// @Security Bearer
// @Param file formData file true "Media file (JPEG/PNG/WebP/MP4/WebM/MOV)"
// @Success 201 {object} PostResponse
// @Failure 400 {object} map[string]string "Invalid file (size/type/format)"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 413 {object} map[string]string "File too large"
// @Failure 507 {object} map[string]string "Insufficient storage"
// @Router /feed/media/upload [post]
func (h *Handler) UploadMedia(c *fiber.Ctx) error {
	_, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	file, err := c.FormFile("file")
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "missing_file"})
	}

	contentType := file.Header.Get("Content-Type")

	// VALIDATION: Determine media type and validate against whitelist
	var mediaType string
	var maxSize int64

	if strings.HasPrefix(contentType, "video/") {
		if !allowedVideoMimes[contentType] {
			return c.Status(400).JSON(fiber.Map{
				"error":    "invalid_video_mime",
				"message":  "Supported video types: MP4, WebM, MOV (iPhone)",
				"received": contentType,
			})
		}
		mediaType = "video"
		maxSize = maxVideoSizeBytes
	} else if strings.HasPrefix(contentType, "image/") {
		if !allowedImageMimes[contentType] {
			return c.Status(400).JSON(fiber.Map{
				"error":    "invalid_image_mime",
				"message":  "Supported image types: JPEG, PNG, WebP",
				"received": contentType,
			})
		}
		mediaType = "image"
		maxSize = maxImageSizeBytes
	} else {
		return c.Status(400).JSON(fiber.Map{
			"error":    "unsupported_media_type",
			"message":  "Only image/* or video/* MIME types allowed",
			"received": contentType,
		})
	}

	// VALIDATION: Check file size boundaries
	if file.Size <= 0 {
		return c.Status(400).JSON(fiber.Map{
			"error":   "empty_file",
			"message": "File must be at least 1 byte",
		})
	}

	if file.Size > maxSize {
		limitMB := maxSize / (1024 * 1024)
		return c.Status(413).JSON(fiber.Map{
			"error":      "file_too_large",
			"message":    fmt.Sprintf("Maximum size for %s: %d MB", mediaType, limitMB),
			"max_bytes":  maxSize,
			"file_bytes": file.Size,
		})
	}

	filename := uuid.New().String() + filepath.Ext(file.Filename)
	objectName := "media/" + filename

	src, err := file.Open()
	if err != nil {
		logger.Error("failed to open file", zap.Error(err))
		return c.Status(500).JSON(fiber.Map{"error": "upload_failed"})
	}
	defer src.Close()

	if h.storage == nil {
		logger.Error("object storage not configured")
		return c.Status(500).JSON(fiber.Map{"error": "upload_failed"})
	}

	// Attempt upload with error differentiation for storage failures
	publicURL, err := h.storage.Upload(c.Context(), objectName, src, file.Size, contentType)
	if err != nil {
		logger.Error("failed to upload to storage",
			zap.Error(err),
			zap.String("filename", filename),
			zap.Int64("size", file.Size),
			zap.String("media_type", mediaType))

		// Differentiate storage errors: insufficient space vs transient/other failures
		errMsg := err.Error()
		if strings.Contains(strings.ToLower(errMsg), "no space") ||
			strings.Contains(strings.ToLower(errMsg), "quota") ||
			strings.Contains(strings.ToLower(errMsg), "disk full") {
			return c.Status(507).JSON(fiber.Map{
				"error":   "insufficient_storage",
				"message": "Server storage full, please try later",
			})
		}

		return c.Status(500).JSON(fiber.Map{
			"error":   "upload_failed",
			"message": "Storage service error, please try again",
		})
	}

	return c.Status(201).JSON(fiber.Map{
		"url":  publicURL,
		"type": mediaType,
	})
}

func resolvePublicBaseURL(configured, requestBase string) string {
	candidate := strings.TrimSuffix(configured, "/")
	fallback := strings.TrimSuffix(requestBase, "/")
	if fallback == "" {
		fallback = "http://localhost:8080"
	}
	if candidate == "" {
		return fallback
	}

	u, err := url.Parse(candidate)
	if err != nil {
		return fallback
	}
	host := strings.ToLower(u.Hostname())
	if host == "localhost" || host == "127.0.0.1" {
		return fallback
	}
	return candidate
}

// ... unchanged intermediate ...

// ToggleLike godoc
// @Summary Like a post
// @Description Toggles like interaction synchronously and returns updated state
// @Tags Feed Interactions
// @Produce json
// @Security Bearer
// @Param post_id path string true "Post UUID"
// @Success 200 {object} PostResponse
// @Failure 401 {object} map[string]string "Unauthorized"
// @Router /posts/{post_id}/likes [post]
func (h *Handler) ToggleLike(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	postID, err := uuid.Parse(c.Params("post_id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_post_id"})
	}

	postResp, err := h.service.ToggleLike(c.Context(), postID, userID)
	if err != nil {
		logger.Error("failed to toggle like", zap.Error(err))
		return c.Status(500).JSON(fiber.Map{"error": "processing_failed"})
	}

	return c.JSON(postResp)
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
// @Description Returns accumulated active seconds, cooldown status, and break_seconds_remaining (0-300). Applies the hard break/reset state machine: if a 5-min break has expired the state is fully reset; if the user was away ≥ 5 min during an active phase the timer resets to 0.
// @Tags Feed
// @Produce json
// @Security Bearer
// @Success 200 {object} FeedStateResponse
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /feed/state [get]
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
// @Router /feed/state/sync [post]
func (h *Handler) SyncFeedState(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	var req SyncFeedStateRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_body"})
	}
	if req.DeviceID == "" {
		return validationErr(c, ErrInvalidDeviceID.Error())
	}

	state, err := h.service.SyncFeedState(c.Context(), userID, &req)
	if err != nil {
		if err == ErrInvalidDelta || err == ErrInvalidDeviceID {
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
// @Success 201 {object} PostResponse
// @Failure 400 {object} map[string]string "Validation error"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Router /posts [post]
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

	postResp, err := h.service.CreatePost(c.Context(), userID, &req)
	if err != nil {
		if err == ErrPostRequiresMedia {
			return validationErr(c, err.Error())
		}
		if err == ErrPublishingRestricted {
			return c.Status(429).JSON(fiber.Map{"error": err.Error()})
		}
		logger.Error("failed to create post",
			zap.String("user_id", userID.String()),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "post_create_failed"})
	}

	return c.Status(201).JSON(postResp)
}

// UpdatePost godoc
// @Summary Update own post settings
// @Description Updates post privacy settings after publication (comment_permission and/or hide_likes_count).
// @Tags Feed
// @Accept json
// @Produce json
// @Security Bearer
// @Param post_id path string true "Post UUID"
// @Param request body UpdatePostRequest true "Post update payload"
// @Success 200 {object} PostResponse
// @Failure 400 {object} map[string]string "Validation error"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 403 {object} map[string]string "Forbidden"
// @Failure 404 {object} map[string]string "Post not found"
// @Router /posts/{post_id} [patch]
func (h *Handler) UpdatePost(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	postID, err := uuid.Parse(c.Params("post_id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_post_id"})
	}

	var req UpdatePostRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_body"})
	}

	postResp, err := h.service.UpdatePost(c.Context(), userID, postID, &req)
	if err != nil {
		if errors.Is(err, ErrInvalidPostUpdate) || errors.Is(err, ErrInvalidCommentPermission) {
			return validationErr(c, err.Error())
		}
		if errors.Is(err, ErrNotPostAuthor) {
			return c.Status(403).JSON(fiber.Map{"error": "forbidden"})
		}
		if errors.Is(err, ErrPostNotFound) {
			return c.Status(404).JSON(fiber.Map{"error": "post_not_found"})
		}
		logger.Error("failed to update post", zap.Error(err))
		return c.Status(500).JSON(fiber.Map{"error": "post_update_failed"})
	}

	return c.JSON(postResp)
}

// DeletePost godoc
// @Summary Delete own post
// @Description Soft-deletes an existing post. Only post author can delete.
// @Tags Feed
// @Produce json
// @Security Bearer
// @Param post_id path string true "Post UUID"
// @Success 200 {object} map[string]string
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 403 {object} map[string]string "Forbidden"
// @Failure 404 {object} map[string]string "Post not found"
// @Router /posts/{post_id} [delete]
func (h *Handler) DeletePost(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	postID, err := uuid.Parse(c.Params("post_id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_post_id"})
	}

	if err := h.service.DeletePost(c.Context(), userID, postID); err != nil {
		if errors.Is(err, ErrNotPostAuthor) {
			return c.Status(403).JSON(fiber.Map{"error": "forbidden"})
		}
		if errors.Is(err, ErrPostNotFound) {
			return c.Status(404).JSON(fiber.Map{"error": "post_not_found"})
		}
		if errors.Is(err, ErrPostAlreadyDeleted) {
			return c.Status(409).JSON(fiber.Map{"error": "post_already_deleted"})
		}
		logger.Error("failed to delete post", zap.Error(err))
		return c.Status(500).JSON(fiber.Map{"error": "post_delete_failed"})
	}

	return c.JSON(fiber.Map{"status": "deleted"})
}

// GetFeed godoc
// @Summary Get mixed feed
// @Description Fetch mixed feed (Allies + Local Geo + World)
// @Tags Feed
// @Produce json
// @Security Bearer
// @Param cursor query string false "Pagination cursor"
// @Param limit query int false "Max results" default(20)
// @Param lat query number false "Viewer latitude for local feed mixing"
// @Param lon query number false "Viewer longitude for local feed mixing"
// @Success 200 {object} FeedResponse
// @Failure 401 {object} map[string]string "Unauthorized"
// @Router /feed [get]
func (h *Handler) GetFeed(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	cursor := c.Query("cursor")
	limit := c.QueryInt("limit", 20)

	latStr := c.Query("lat")
	lonStr := c.Query("lon")
	hasLocation := false
	lat := 0.0
	lon := 0.0
	if latStr != "" || lonStr != "" {
		parsedLat, errLat := strconv.ParseFloat(latStr, 64)
		parsedLon, errLon := strconv.ParseFloat(lonStr, 64)
		if errLat != nil || errLon != nil {
			return validationErr(c, "invalid lat/lon")
		}
		lat = parsedLat
		lon = parsedLon
		hasLocation = true
	}

	resp, err := h.service.GetFeed(c.Context(), userID, cursor, limit, lat, lon, hasLocation)
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
// @Success 201 {object} CommentResponse
// @Failure 400 {object} map[string]string "Validation error"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 403 {object} map[string]string "Commenting disabled or restricted"
// @Router /posts/{post_id}/comments [post]
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

	commentResp, err := h.service.CreateComment(c.Context(), userID, postID, &req)
	if err != nil {
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

	return c.Status(201).JSON(commentResp)
}

// DeleteComment godoc
// @Summary Delete comment
// @Description Soft-deletes a comment. Allowed for comment author or admin moderator.
// @Tags Feed Moderation
// @Produce json
// @Security Bearer
// @Param post_id path string true "Post UUID"
// @Param comment_id path string true "Comment UUID"
// @Success 200 {object} map[string]string
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 403 {object} map[string]string "Forbidden"
// @Router /posts/{post_id}/comments/{comment_id} [delete]
func (h *Handler) DeleteComment(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	commentID, err := uuid.Parse(c.Params("comment_id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_comment_id"})
	}

	if err := h.service.DeleteComment(c.Context(), userID, commentID); err != nil {
		if errors.Is(err, ErrNotCommentAuthor) {
			return c.Status(403).JSON(fiber.Map{"error": "forbidden"})
		}
		logger.Error("failed to delete comment", zap.Error(err))
		return c.Status(500).JSON(fiber.Map{"error": "comment_delete_failed"})
	}

	return c.JSON(fiber.Map{"status": "deleted"})
}

// ReportComment godoc
// @Summary Report comment
// @Description Creates moderation report for a comment.
// @Tags Feed Moderation
// @Accept json
// @Produce json
// @Security Bearer
// @Param post_id path string true "Post UUID"
// @Param comment_id path string true "Comment UUID"
// @Param request body ReportCommentRequest true "Report reason and optional description"
// @Success 201 {object} map[string]string
// @Failure 400 {object} map[string]string "Validation error"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Router /posts/{post_id}/comments/{comment_id}/report [post]
func (h *Handler) ReportComment(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	commentID, err := uuid.Parse(c.Params("comment_id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_comment_id"})
	}

	var req ReportCommentRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_body"})
	}
	if strings.TrimSpace(req.Reason) == "" {
		return c.Status(400).JSON(fiber.Map{"error": ErrInvalidReportReason.Error()})
	}

	if err := h.service.ReportComment(c.Context(), userID, commentID, req.Reason, req.Description); err != nil {
		if errors.Is(err, ErrInvalidReportReason) {
			return c.Status(400).JSON(fiber.Map{"error": ErrInvalidReportReason.Error()})
		}
		if errors.Is(err, ErrDuplicateReport) {
			return c.Status(409).JSON(fiber.Map{"error": ErrDuplicateReport.Error()})
		}
		if errors.Is(err, ErrReportRateLimited) {
			return c.Status(429).JSON(fiber.Map{"error": ErrReportRateLimited.Error()})
		}
		logger.Error("failed to report comment", zap.Error(err))
		return c.Status(500).JSON(fiber.Map{"error": "report_failed"})
	}

	return c.Status(201).JSON(fiber.Map{"status": "reported"})
}

// ReportPost godoc
// @Summary Report post
// @Description Creates moderation report for a post.
// @Tags Feed Moderation
// @Accept json
// @Produce json
// @Security Bearer
// @Param post_id path string true "Post UUID"
// @Param request body ReportPostRequest true "Report reason and optional description"
// @Success 201 {object} map[string]string
// @Failure 400 {object} map[string]string "Validation error"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Router /posts/{post_id}/report [post]
func (h *Handler) ReportPost(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	postID, err := uuid.Parse(c.Params("post_id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_post_id"})
	}

	var req ReportPostRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_body"})
	}
	if strings.TrimSpace(req.Reason) == "" {
		return c.Status(400).JSON(fiber.Map{"error": ErrInvalidReportReason.Error()})
	}

	if err := h.service.ReportPost(c.Context(), userID, postID, req.Reason, req.Description); err != nil {
		if errors.Is(err, ErrInvalidReportReason) {
			return c.Status(400).JSON(fiber.Map{"error": ErrInvalidReportReason.Error()})
		}
		if errors.Is(err, ErrDuplicateReport) {
			return c.Status(409).JSON(fiber.Map{"error": ErrDuplicateReport.Error()})
		}
		if errors.Is(err, ErrReportRateLimited) {
			return c.Status(429).JSON(fiber.Map{"error": ErrReportRateLimited.Error()})
		}
		logger.Error("failed to report post", zap.Error(err))
		return c.Status(500).JSON(fiber.Map{"error": "report_failed"})
	}

	return c.Status(201).JSON(fiber.Map{"status": "reported"})
}

// GetAdminReports godoc
// @Summary List moderation reports
// @Description Admin endpoint with filters by status/target_type/reason.
// @Tags Feed Moderation
// @Produce json
// @Security Bearer
// @Param status query string false "pending/reviewed"
// @Param target_type query string false "post/comment"
// @Param reason query string false "report reason"
// @Param limit query int false "limit" default(50)
// @Param offset query int false "offset" default(0)
// @Success 200 {object} ReportsListResponse
// @Failure 401 {object} map[string]string "Unauthorized"
// @Router /admin/reports [get]
func (h *Handler) GetAdminReports(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	isAdmin, err := h.service.IsUserAdmin(c.Context(), userID)
	if err != nil {
		logger.Error("failed to check admin role", zap.Error(err))
		return c.Status(500).JSON(fiber.Map{"error": "fetch_failed"})
	}
	if !isAdmin {
		return c.Status(403).JSON(fiber.Map{"error": "forbidden"})
	}

	resp, err := h.service.ListReports(
		c.Context(),
		strings.TrimSpace(c.Query("status")),
		strings.TrimSpace(c.Query("target_type")),
		strings.TrimSpace(c.Query("reason")),
		c.QueryInt("limit", 50),
		c.QueryInt("offset", 0),
	)
	if err != nil {
		logger.Error("failed to fetch reports", zap.Error(err))
		return c.Status(500).JSON(fiber.Map{"error": "fetch_failed"})
	}
	return c.JSON(resp)
}

// ReviewReports godoc
// @Summary Review moderation reports
// @Description Admin endpoint to apply moderation decision for a target.
// @Tags Feed Moderation
// @Accept json
// @Produce json
// @Security Bearer
// @Param request body ReviewReportsRequest true "Target and decision"
// @Success 200 {object} map[string]string
// @Failure 400 {object} map[string]string "Validation error"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Router /admin/reports/review [post]
func (h *Handler) ReviewReports(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	isAdmin, err := h.service.IsUserAdmin(c.Context(), userID)
	if err != nil {
		logger.Error("failed to check admin role", zap.Error(err))
		return c.Status(500).JSON(fiber.Map{"error": "review_failed"})
	}
	if !isAdmin {
		return c.Status(403).JSON(fiber.Map{"error": "forbidden"})
	}

	var req ReviewReportsRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_body"})
	}

	targetID, err := uuid.Parse(strings.TrimSpace(req.TargetID))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_target_id"})
	}

	err = h.service.ReviewReports(c.Context(), req.TargetType, targetID, req.Decision)
	if err != nil {
		if errors.Is(err, ErrInvalidReportTargetType) || errors.Is(err, ErrInvalidReportDecision) {
			return c.Status(400).JSON(fiber.Map{"error": err.Error()})
		}
		logger.Error("failed to review reports", zap.Error(err))
		return c.Status(500).JSON(fiber.Map{"error": "review_failed"})
	}

	return c.JSON(fiber.Map{"status": "reviewed"})
}

// ToggleCommentLike godoc
// @Summary Like a comment
// @Description Toggles like interaction on a comment synchronously
// @Tags Feed Interactions
// @Produce json
// @Security Bearer
// @Param comment_id path string true "Comment UUID"
// @Success 200 {object} CommentResponse
// @Failure 401 {object} map[string]string "Unauthorized"
// @Router /comments/{comment_id}/likes [post]
func (h *Handler) ToggleCommentLike(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	commentID, err := uuid.Parse(c.Params("comment_id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_comment_id"})
	}

	commentResp, err := h.service.ToggleCommentLike(c.Context(), commentID, userID)
	if err != nil {
		logger.Error("failed to toggle comment like", zap.Error(err))
		return c.Status(500).JSON(fiber.Map{"error": "processing_failed"})
	}

	return c.JSON(commentResp)
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
// @Router /posts/{post_id}/comments [get]
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
// @Router /posts/{post_id}/likes [get]
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
// @Success 201 {object} map[string]interface{} "Seal sent вЂ” returns ledger_entry_id and new sender balance"
// @Failure 400 {object} map[string]string
// @Failure 402 {object} map[string]string "insufficient_balance"
// @Failure 429 {object} map[string]string "cooldown active"
// @Router /posts/{post_id}/seals [post]
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
	req.Comment = strings.TrimSpace(req.Comment)

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

	// Build idempotency key so duplicate taps can replay safely even when client does
	// not send an explicit key. Keep this scoped to a short server window to avoid
	// blocking legitimate future seals after cooldown windows.
	idempotencyKey := strings.TrimSpace(req.IdempotencyKey)
	if idempotencyKey == "" {
		idempotencyKey = strings.TrimSpace(c.Get("Idempotency-Key"))
	}
	if idempotencyKey == "" {
		window := time.Now().UTC().Format("200601021504")
		autoKeyMaterial := fmt.Sprintf("post-seal|%s|%s|%s|%d|%s|%s", userID.String(), authorID.String(), postID.String(), req.Amount, req.Comment, window)
		idempotencyKey = "auto_post_seal_" + uuid.NewSHA1(uuid.NameSpaceOID, []byte(autoKeyMaterial)).String()
	}

	// Call Economy вЂ” handles wallet debit, ledger entry, cooldown, monthly limit.
	txResp, err := h.economy.GiveSealToPost(c.Context(), userID.String(), postID.String(), &economy.GiveSealToPostRequest{
		ReceiverUserID: authorID.String(),
		Amount:         req.Amount,
		Comment:        req.Comment,
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

	// Queue denormalization only for a newly created ledger entry.
	if txResp.CreatedNew {
		_ = h.worker.QueueSeal(postID, req.Amount)
	}

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
// @Security Bearer
// @Param post_id path string true "Post UUID"
// @Success 200 {object} SealListResponse
// @Failure 401 {object} map[string]string "Unauthorized"
// @Router /posts/{post_id}/seals [get]
func (h *Handler) GetSeals(c *fiber.Ctx) error {
	if _, ok := requireUserID(c); !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

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

// GetMyPostsGrid godoc
// @Summary Get own profile posts grid
// @Description Returns a paginated 3x3-style grid of the authenticated user's posts (thumbnails only). Use next_cursor to paginate. Default limit is 18.
// @Tags Profiles
// @Produce json
// @Security Bearer
// @Param cursor query string false "Pagination cursor (RFC3339Nano timestamp)"
// @Param limit  query int    false "Items per page (max 30)" default(18)
// @Success 200 {object} UserPostsGridResponse
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /profiles/me/posts [get]
func (h *Handler) GetMyPostsGrid(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}
	resp, err := h.service.GetUserPostsGrid(c.Context(), userID, userID, c.Query("cursor"), c.QueryInt("limit", 18))
	if err != nil {
		logger.Error("GetMyPostsGrid failed", zap.String("user_id", userID.String()), zap.Error(err))
		return c.Status(500).JSON(fiber.Map{"error": "fetch_failed"})
	}
	return c.JSON(resp)
}

// GetUserPostsGrid godoc
// @Summary Get another user's profile posts grid
// @Description Returns a paginated grid of a user's public (or ally-visible) posts. Viewer must be authenticated.
// @Tags Profiles
// @Produce json
// @Security Bearer
// @Param user_id path  string true  "Author UUID"
// @Param cursor  query string false "Pagination cursor (RFC3339Nano timestamp)"
// @Param limit   query int    false "Items per page (max 30)" default(18)
// @Success 200 {object} UserPostsGridResponse
// @Failure 400 {object} map[string]string "Invalid user_id"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /profiles/{user_id}/posts [get]
func (h *Handler) GetUserPostsGrid(c *fiber.Ctx) error {
	viewerID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}
	authorID, err := uuid.Parse(c.Params("user_id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_user_id"})
	}
	resp, err := h.service.GetUserPostsGrid(c.Context(), authorID, viewerID, c.Query("cursor"), c.QueryInt("limit", 18))
	if err != nil {
		logger.Error("GetUserPostsGrid failed", zap.String("author_id", authorID.String()), zap.Error(err))
		return c.Status(500).JSON(fiber.Map{"error": "fetch_failed"})
	}
	return c.JSON(resp)
}

// GetMyPostsList godoc
// @Summary Get own profile posts list
// @Description Returns full PostResponse entries for the authenticated user's posts. Pass anchor_post_id to start the list at a specific post (inclusive), or use cursor for standard pagination.
// @Tags Profiles
// @Produce json
// @Security Bearer
// @Param anchor_post_id query string false "Start list at this post ID (inclusive)"
// @Param cursor         query string false "Pagination cursor (RFC3339Nano timestamp)"
// @Param limit          query int    false "Items per page (max 30)" default(10)
// @Success 200 {object} FeedResponse
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /profiles/me/posts/list [get]
func (h *Handler) GetMyPostsList(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}
	anchor := parseOptionalUUID(c.Query("anchor_post_id"))
	resp, err := h.service.GetUserPostsList(c.Context(), userID, userID, anchor, c.Query("cursor"), c.QueryInt("limit", 10))
	if err != nil {
		logger.Error("GetMyPostsList failed", zap.String("user_id", userID.String()), zap.Error(err))
		return c.Status(500).JSON(fiber.Map{"error": "fetch_failed"})
	}
	return c.JSON(resp)
}

// GetUserPostsList godoc
// @Summary Get another user's profile posts list
// @Description Returns full PostResponse entries for a user's visible posts. Pass anchor_post_id to start at a specific post (inclusive).
// @Tags Profiles
// @Produce json
// @Security Bearer
// @Param user_id        path  string true  "Author UUID"
// @Param anchor_post_id query string false "Start list at this post ID (inclusive)"
// @Param cursor         query string false "Pagination cursor (RFC3339Nano timestamp)"
// @Param limit          query int    false "Items per page (max 30)" default(10)
// @Success 200 {object} FeedResponse
// @Failure 400 {object} map[string]string "Invalid user_id"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /profiles/{user_id}/posts/list [get]
func (h *Handler) GetUserPostsList(c *fiber.Ctx) error {
	viewerID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}
	authorID, err := uuid.Parse(c.Params("user_id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_user_id"})
	}
	anchor := parseOptionalUUID(c.Query("anchor_post_id"))
	resp, err := h.service.GetUserPostsList(c.Context(), authorID, viewerID, anchor, c.Query("cursor"), c.QueryInt("limit", 10))
	if err != nil {
		logger.Error("GetUserPostsList failed", zap.String("author_id", authorID.String()), zap.Error(err))
		return c.Status(500).JSON(fiber.Map{"error": "fetch_failed"})
	}
	return c.JSON(resp)
}

// parseOptionalUUID parses a UUID string, returning nil on empty or invalid input.
func parseOptionalUUID(s string) *uuid.UUID {
	if s == "" {
		return nil
	}
	id, err := uuid.Parse(s)
	if err != nil {
		return nil
	}
	return &id
}
