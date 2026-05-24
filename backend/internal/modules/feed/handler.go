package feed

import (
	"context"
	"errors"
	"fmt"
	"io"

	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/brightbund-backend/internal/modules/economy"
	"github.com/brightbund-backend/internal/modules/profiles"
	"github.com/brightbund-backend/internal/platform/logger"
	"github.com/brightbund-backend/internal/platform/eventbus"
	"github.com/brightbund-backend/internal/platform/vision"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"go.uber.org/zap"
)

type ObjectStorage interface {
	Upload(ctx context.Context, bucketName, objectName string, reader io.Reader, size int64, contentType string) (string, error)
	Download(ctx context.Context, bucketName, objectName string) (io.ReadCloser, error)
	Delete(ctx context.Context, bucketName, objectName string) error
}

// SealNotifier is the optional hook the seal handler calls after a
// successful Silver Seal transfer to push a "you moved X to position N"
// notification to the actor. The interface is deliberately tiny so the
// feed package does not need to import the notifications, map, or
// cache modules — main.go wires a concrete adapter.
type SealNotifier interface {
	NotifyPostSealed(ctx context.Context, actorID, postAuthorID uuid.UUID) error
}

type Handler struct {
	service    *Service
	worker     *InteractionWorker
	economy    economy.Service
	storage    ObjectStorage
	vision     vision.Client
	publicURL  string
	tempBucket string
	notifier   SealNotifier
}

func NewHandler(service *Service, worker *InteractionWorker, economyService economy.Service, storageClient ObjectStorage, visionClient vision.Client, publicURL, tempBucket string) *Handler {
	return &Handler{
		service:    service,
		worker:     worker,
		economy:    economyService,
		storage:    storageClient,
		vision:     visionClient,
		publicURL:  publicURL,
		tempBucket: tempBucket,
	}
}

// SetSealNotifier installs the post-seal notifier. Called from main.go
// after wiring map service + notifications service.
func (h *Handler) SetSealNotifier(n SealNotifier) {
	h.notifier = n
}

// Constants for media upload hardening (SAFETY)
const (
	// Maximum file sizes by MIME category
	maxImageSizeBytes = 10 * 1024 * 1024  // 10 MB for images (PNG, JPEG, WebP)
	maxVideoSizeBytes = 500 * 1024 * 1024 // 500 MB for videos (MP4, WebM)
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
// @Param file formData file true "Media file (JPEG/PNG/WebP/MP4/WebM/MOV) - Max 500MB for video, 10MB for image"
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
		// Basic 2-minute cap: client must report duration_seconds in the form.
		// Phase-3 will replace this with a server-side ffprobe check.
		if durStr := c.FormValue("duration_seconds"); durStr != "" {
			if dur, convErr := strconv.Atoi(durStr); convErr == nil {
				if dur <= 0 {
					return c.Status(400).JSON(fiber.Map{
						"error":   "invalid_duration",
						"message": "duration_seconds must be a positive integer",
					})
				}
				if dur > MaxVideoDurationSeconds {
					return c.Status(400).JSON(fiber.Map{
						"error":       "video_too_long",
						"message":     fmt.Sprintf("Maximum video duration is %d seconds", MaxVideoDurationSeconds),
						"max_seconds": MaxVideoDurationSeconds,
						"received":    dur,
					})
				}
			}
		}
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
		return c.Status(400).JSON(fiber.Map{
			"error":   "invalid_file_payload",
			"message": "Failed to read uploaded file",
		})
	}
	defer src.Close()

	// MODERATION: Media safety inspection
	if mediaType == "image" && h.vision != nil {
		ok, reason, err := h.vision.DetectInappropriateContent(c.Context(), src)
		if err != nil {
			logger.Error("vision api detection failed", zap.Error(err))
			// Fail open on transient API errors, but log warning
		} else if !ok {
			userID, _ := requireUserID(c)
			// Log to DB
			_ = h.service.LogMediaAbuse(c.Context(), userID, "inappropriate_content", reason, map[string]interface{}{
				"filename":     file.Filename,
				"content_type": contentType,
				"size":         file.Size,
			})

			if h.service.eventBus != nil {
				_ = h.service.eventBus.Publish(c.Context(), eventbus.TypePostRejected, eventbus.SystemEvent{
					UserID:  userID.String(),
					Details: "Your post was rejected: " + reason,
				})
			}

			return c.Status(403).JSON(fiber.Map{
				"error":   "content_rejected",
				"message": "This content can't be posted due to community guidelines.",
			})
		}

		// Reset reader for storage upload
		if seeker, ok := src.(io.Seeker); ok {
			_, _ = seeker.Seek(0, io.SeekStart)
		}
	}

	if h.storage == nil {
		logger.Error("object storage not configured")
		return c.Status(503).JSON(fiber.Map{
			"error":   "storage_unavailable",
			"message": "Storage service is temporarily unavailable",
		})
	}

	// Attempt upload with error differentiation for storage failures
	bucket := "" // default bucket
	if mediaType == "video" {
		bucket = h.tempBucket
	}

	publicURL, err := h.storage.Upload(c.Context(), bucket, objectName, src, file.Size, contentType)
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
		if strings.Contains(strings.ToLower(errMsg), "timeout") ||
			strings.Contains(strings.ToLower(errMsg), "connection refused") ||
			strings.Contains(strings.ToLower(errMsg), "unavailable") {
			return c.Status(503).JSON(fiber.Map{
				"error":   "storage_unavailable",
				"message": "Storage service unavailable, please retry",
			})
		}
		if strings.Contains(strings.ToLower(errMsg), "access denied") ||
			strings.Contains(strings.ToLower(errMsg), "forbidden") {
			return c.Status(500).JSON(fiber.Map{
				"error":   "storage_permission_denied",
				"message": "Storage rejected upload operation",
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

	isInFeed, err := resolveFeedContext(&req)
	if err != nil {
		return validationErr(c, err.Error())
	}

	state, err := h.service.SyncFeedState(c.Context(), userID, &req, isInFeed)
	if err != nil {
		if err == ErrInvalidDelta || err == ErrInvalidDeviceID || err == ErrInvalidFeedContext || err == ErrInvalidAppSection {
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

func resolveFeedContext(req *SyncFeedStateRequest) (bool, error) {
	if req.IsFeedActive != nil {
		return *req.IsFeedActive, nil
	}
	section := strings.TrimSpace(strings.ToLower(req.AppSection))
	if section == "" {
		return false, ErrInvalidFeedContext
	}
	switch section {
	case AppSectionFeed:
		return true, nil
	case AppSectionMap, AppSectionProfile, AppSectionChats, AppSectionBackground:
		return false, nil
	default:
		return false, ErrInvalidAppSection
	}
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
	if strings.TrimSpace(req.IdempotencyKey) == "" {
		req.IdempotencyKey = strings.TrimSpace(c.Get("Idempotency-Key"))
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
		if err == ErrInvalidIdempotencyKey {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": err.Error()})
		}
		if err == ErrPostIdempotencyConflict {
			return c.Status(fiber.StatusConflict).JSON(fiber.Map{"error": err.Error()})
		}
		if err == ErrPostIdempotencyInProgress {
			return c.Status(fiber.StatusConflict).JSON(fiber.Map{"error": err.Error()})
		}
		if err == ErrVideoTooLong || err == ErrVideoDurationRequired {
			return c.Status(fiber.StatusUnprocessableEntity).JSON(fiber.Map{"error": err.Error()})
		}
		if err == ErrTooManyMediaAttachments || err == ErrTooManyPhotoAttachments || err == ErrTooManyVideoAttachments {
			return c.Status(fiber.StatusUnprocessableEntity).JSON(fiber.Map{"error": err.Error()})
		}
		if err == ErrUnsupportedMediaType || err == ErrMediaURLRequired {
			return c.Status(fiber.StatusUnprocessableEntity).JSON(fiber.Map{"error": err.Error()})
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

// SearchProfiles godoc
// @Summary Search profiles for feed
// @Description Search for public user profiles by display name or name. Results are filtered by privacy and blocks.
// @Tags Feed
// @Produce json
// @Security Bearer
// @Param query query string true "Search query (nickname or name)"
// @Param limit query int false "Max results" default(20)
// @Param offset query int false "Offset for pagination" default(0)
// @Success 200 {array} profiles.ProfileSearchResult
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Internal error"
// @Router /feed/search/profiles [get]
func (h *Handler) SearchProfiles(c *fiber.Ctx) error {
	userID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	query := c.Query("query")
	if query == "" {
		return c.JSON([]profiles.ProfileSearchResult{})
	}

	limit := c.QueryInt("limit", 20)
	offset := c.QueryInt("offset", 0)

	results, err := h.service.SearchProfiles(c.Context(), userID.String(), query, limit, offset)
	if err != nil {
		logger.Error("failed to search profiles", zap.Error(err))
		return c.Status(500).JSON(fiber.Map{"error": "search_failed"})
	}

	return c.JSON(results)
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
		if errors.Is(err, ErrReportRateLimited) || errors.Is(err, ErrReportCooldownActive) {
			return c.Status(429).JSON(fiber.Map{"error": err.Error()})
		}
		if errors.Is(err, ErrPostNotFound) {
			return c.Status(404).JSON(fiber.Map{"error": "target_not_found"})
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
		if errors.Is(err, ErrReportRateLimited) || errors.Is(err, ErrReportCooldownActive) {
			return c.Status(429).JSON(fiber.Map{"error": err.Error()})
		}
		if errors.Is(err, ErrPostNotFound) {
			return c.Status(404).JSON(fiber.Map{"error": "target_not_found"})
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

	if req.Amount != 1 {
		return c.Status(400).JSON(fiber.Map{"error": ErrInvalidSealAmount.Error()})
	}

	// Reason text validation (10-200 chars). Accept legacy `comment` as fallback.
	reason := strings.TrimSpace(req.EffectiveReason())
	runes := []rune(reason)
	if len(runes) < 10 {
		return c.Status(400).JSON(fiber.Map{"error": ErrSealReasonTooShort.Error()})
	}
	if len(runes) > 200 {
		return c.Status(400).JSON(fiber.Map{"error": ErrSealReasonTooLong.Error()})
	}
	req.Reason = reason
	req.Comment = reason

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
		// Scope to a day, not a minute — cooldowns already enforce once-per-day
		// semantics. A minute bucket causes distinct keys across minute boundaries
		// (e.g. 12:59:59 vs 13:00:00) which bypass the Economy idempotency gate
		// and produce duplicate ledger entries / double seal credits on a post.
		window := time.Now().UTC().Format("20060102")
		autoKeyMaterial := fmt.Sprintf("post-seal|%s|%s|%s|%d|%s|%s", userID.String(), authorID.String(), postID.String(), req.Amount, reason, window)
		idempotencyKey = "auto_post_seal_" + uuid.NewSHA1(uuid.NameSpaceOID, []byte(autoKeyMaterial)).String()
	}

	// Call Economy вЂ” handles wallet debit, ledger entry, cooldown, monthly limit.
	txResp, err := h.economy.GiveSealToPost(c.Context(), userID.String(), postID.String(), &economy.GiveSealToPostRequest{
		ReceiverUserID: authorID.String(),
		Amount:         req.Amount,
		Comment:        reason,
		Currency:       "SILVER_SEAL",
		IdempotencyKey: idempotencyKey,
	})
	if err != nil {
		log := logger.Get()
		log.Warn("seal economy error", zap.String("user", userID.String()), zap.Error(err))

		// Map economy errors to HTTP status codes.
		switch {
		case economy.IsValidationError(err):
			return c.Status(400).JSON(fiber.Map{"error": "invalid_seal_amount", "detail": err.Error()})
		case economy.IsInsufficientFunds(err):
			return c.Status(402).JSON(fiber.Map{"error": ErrInsufficientBalance.Error()})
		case economy.IsCooldownActive(err):
			return c.Status(429).JSON(fiber.Map{"error": "cooldown_active", "detail": err.Error()})
		case economy.IsMonthlyLimitExceeded(err):
			return c.Status(429).JSON(fiber.Map{"error": "monthly_limit_exceeded"})
		case economy.IsDuplicateError(err) || errors.Is(err, economy.ErrIdempotencyConflict):
			return c.Status(409).JSON(fiber.Map{"error": "idempotency_conflict", "detail": err.Error()})
		case errors.Is(err, economy.ErrOptimisticLockFailure):
			return c.Status(409).JSON(fiber.Map{"error": "transaction_conflict", "detail": "please retry"})
		default:
			return c.Status(500).JSON(fiber.Map{"error": "seal_failed"})
		}
	}

	// Queue post seal-count update only if a new ledger entry was created.
	// TryQueueSeal uses Redis SET NX keyed on idempotencyKey to ensure exactly-once
	// increments even when two concurrent HTTP requests both receive CreatedNew=true.
	if txResp.CreatedNew {
		_ = h.worker.TryQueueSeal(c.Context(), postID, idempotencyKey, req.Amount)

		// Fire the "you moved <author> up the ranking" notification to the
		// sender. Best-effort — we never fail the seal transaction because
		// of a notification error, and we only fire on first acceptance so
		// idempotent retries don't double-notify.
		if h.notifier != nil {
			go func(actor, recipient uuid.UUID) {
				ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
				defer cancel()
				if err := h.notifier.NotifyPostSealed(ctx, actor, recipient); err != nil {
					logger.Get().Warn("notify_post_sealed_failed",
						zap.String("actor", actor.String()),
						zap.String("recipient", recipient.String()),
						zap.Error(err),
					)
				}
			}(userID, authorID)
		}
	}

	return c.Status(201).JSON(fiber.Map{
		"status":          "seal_sent",
		"ledger_entry_id": txResp.LedgerEntryID,
		"new_balance":     txResp.SenderBalance,
	})
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

// AdminDeletePost godoc
// @Summary Admin emergency post deletion
// @Description Emergency deletion of any post by an administrator.
// @Tags Feed Moderation
// @Produce json
// @Security Bearer
// @Param post_id path string true "Post UUID"
// @Success 200 {object} map[string]string
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 403 {object} map[string]string "Forbidden"
// @Router /admin/posts/{post_id} [delete]
func (h *Handler) AdminDeletePost(c *fiber.Ctx) error {
	adminID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	postID, err := uuid.Parse(c.Params("post_id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_post_id"})
	}

	if err := h.service.DeletePost(c.Context(), adminID, postID); err != nil {
		logger.Error("admin failed to delete post", zap.Error(err), zap.String("admin_id", adminID.String()), zap.String("post_id", postID.String()))
		return c.Status(500).JSON(fiber.Map{"error": "admin_post_delete_failed"})
	}

	return c.JSON(fiber.Map{"status": "deleted_by_admin"})
}

// AdminDeleteComment godoc
// @Summary Admin emergency comment deletion
// @Description Emergency deletion of any comment by an administrator.
// @Tags Feed Moderation
// @Produce json
// @Security Bearer
// @Param comment_id path string true "Comment UUID"
// @Success 200 {object} map[string]string
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 403 {object} map[string]string "Forbidden"
// @Router /admin/comments/{comment_id} [delete]
func (h *Handler) AdminDeleteComment(c *fiber.Ctx) error {
	adminID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	commentID, err := uuid.Parse(c.Params("comment_id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_comment_id"})
	}

	if err := h.service.DeleteComment(c.Context(), adminID, commentID); err != nil {
		logger.Error("admin failed to delete comment", zap.Error(err), zap.String("admin_id", adminID.String()), zap.String("comment_id", commentID.String()))
		return c.Status(500).JSON(fiber.Map{"error": "admin_comment_delete_failed"})
	}

	return c.JSON(fiber.Map{"status": "deleted_by_admin"})
}
