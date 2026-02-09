package profiles

import (
	"github.com/brightbund-backend/internal/platform/geolocation"
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

// GetMyProfile godoc
// @Summary Get my profile
// @Description Retrieve the authenticated user's profile. Auto-creates if not exists.
// @Tags Profiles
// @Accept json
// @Produce json
// @Security Bearer
// @Success 200 {object} Profile "User profile"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Internal server error"
// @Router /profiles/me [get]
func (h *Handler) GetMyProfile(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}
	p, err := h.service.GetMyProfile(c.Context(), userID.(string))
	if err != nil {
		logger.Error("failed to get profile",
			zap.String("user_id", userID.(string)),
			zap.String("request_id", c.Get("X-Request-Id")),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "profile_error", "message": err.Error()})
	}
	return c.JSON(p)
}

// UpdateMyProfile godoc
// @Summary Update my profile
// @Description Update the authenticated user's profile information. Auto-populates location if IP provided.
// @Tags Profiles
// @Accept json
// @Produce json
// @Security Bearer
// @Param request body UpdateProfileRequest true "Profile update data"
// @Success 200 {object} Profile "Updated profile"
// @Failure 400 {object} map[string]string "Invalid request body"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Profile update failed"
// @Router /profiles/me [patch]
func (h *Handler) UpdateMyProfile(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	var req UpdateProfileRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_body"})
	}

	// Extract client IP for automatic geolocation
	req.ClientIP = geolocation.ExtractIPFromRequest(c.Request())

	p, err := h.service.UpdateMyProfile(c.Context(), userID.(string), &req)
	if err != nil {
		logger.Error("failed to update profile",
			zap.String("user_id", userID.(string)),
			zap.String("request_id", c.Get("X-Request-Id")),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "profile_update_failed", "message": err.Error()})
	}
	return c.JSON(p)
}

// GetPublicProfile godoc
// @Summary Get public profile
// @Description Retrieve another user's public profile. Returns 403 if profile is private.
// @Tags Profiles
// @Accept json
// @Produce json
// @Security Bearer
// @Param user_id path string true "User ID"
// @Success 200 {object} PublicProfileResponse "Public profile"
// @Failure 400 {object} map[string]string "Invalid user ID"
// @Failure 403 {object} map[string]string "Profile is private"
// @Failure 404 {object} map[string]string "Profile not found"
// @Failure 500 {object} map[string]string "Internal server error"
// @Router /profiles/{user_id} [get]
func (h *Handler) GetPublicProfile(c *fiber.Ctx) error {
	targetID := c.Params("user_id")
	if targetID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_user_id"})
	}

	p, err := h.service.GetPublicProfile(c.Context(), targetID)
	if err != nil {
		if err == ErrProfilePrivate {
			return c.Status(403).JSON(fiber.Map{"error": "profile_private"})
		}
		if err == ErrProfileNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "profile_not_found"})
		}
		logger.Error("failed to get public profile",
			zap.String("target_user_id", targetID),
			zap.String("request_id", c.Get("X-Request-Id")),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "profile_error"})
	}

	return c.JSON(p)
}

// UploadAvatar godoc
// @Summary Upload avatar image
// @Description Upload an avatar image for the authenticated user. Max 5MB, supports jpg/png/webp.
// @Tags Profiles
// @Accept multipart/form-data
// @Produce json
// @Security Bearer
// @Param file formData file true "Avatar image file"
// @Success 200 {object} Profile "Updated profile with new avatar URL"
// @Failure 400 {object} map[string]string "File required, too large, or invalid type"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Upload failed or storage not configured"
// @Router /profiles/me/avatar [post]
func (h *Handler) UploadAvatar(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	file, err := c.FormFile("file")
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "file_required"})
	}

	src, err := file.Open()
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "file_open_failed"})
	}
	defer src.Close()

	p, err := h.service.UploadAvatar(
		c.Context(),
		userID.(string),
		file.Filename,
		file.Header.Get("Content-Type"),
		file.Size,
		src,
	)
	if err != nil {
		if err == ErrStorageNotConfigured {
			return c.Status(500).JSON(fiber.Map{"error": "storage_not_configured"})
		}
		if err == ErrAvatarTooLarge || err == ErrInvalidAvatarMimeType {
			return c.Status(400).JSON(fiber.Map{"error": "invalid_avatar"})
		}
		logger.Error("avatar upload failed",
			zap.String("user_id", userID.(string)),
			zap.String("filename", file.Filename),
			zap.Int64("size", file.Size),
			zap.String("request_id", c.Get("X-Request-Id")),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "avatar_upload_failed"})
	}

	return c.JSON(p)
}

// GetMyStats godoc
// @Summary Get my profile statistics
// @Description Retrieve wallet balances and transaction totals for the authenticated user.
// @Tags Profiles
// @Accept json
// @Produce json
// @Security Bearer
// @Success 200 {object} ProfileStats "Profile statistics"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Failed to retrieve stats"
// @Router /profiles/me/stats [get]
func (h *Handler) GetMyStats(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}
	stats, err := h.service.GetMyStats(c.Context(), userID.(string))
	if err != nil {
		logger.Error("failed to get profile stats",
			zap.String("user_id", userID.(string)),
			zap.String("request_id", c.Get("X-Request-Id")),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "profile_stats_failed"})
	}
	return c.JSON(stats)
}

// GetPublicStats godoc
// @Summary Get public profile statistics
// @Description Retrieve statistics for another user's public profile. Returns 403 if profile is private.
// @Tags Profiles
// @Accept json
// @Produce json
// @Security Bearer
// @Param user_id path string true "User ID"
// @Success 200 {object} ProfileStats "Profile statistics"
// @Failure 400 {object} map[string]string "Invalid user ID"
// @Failure 403 {object} map[string]string "Profile is private"
// @Failure 404 {object} map[string]string "Profile not found"
// @Failure 500 {object} map[string]string "Failed to retrieve stats"
// @Router /profiles/{user_id}/stats [get]
func (h *Handler) GetPublicStats(c *fiber.Ctx) error {
	targetID := c.Params("user_id")
	if targetID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_user_id"})
	}
	stats, err := h.service.GetPublicStats(c.Context(), targetID)
	if err != nil {
		if err == ErrProfilePrivate {
			return c.Status(403).JSON(fiber.Map{"error": "profile_private"})
		}
		if err == ErrProfileNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "profile_not_found"})
		}
		logger.Error("failed to get public stats",
			zap.String("target_user_id", targetID),
			zap.String("request_id", c.Get("X-Request-Id")),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "profile_stats_failed"})
	}
	return c.JSON(stats)
}

// DeleteMyProfile godoc
// @Summary Delete my profile
// @Description Delete the authenticated user's profile. Profile can be auto-recreated on next access.
// @Tags Profiles
// @Accept json
// @Produce json
// @Security Bearer
// @Success 204 "Profile deleted successfully"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Profile deletion failed"
// @Router /profiles/me [delete]
func (h *Handler) DeleteMyProfile(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}
	if err := h.service.DeleteMyProfile(c.Context(), userID.(string)); err != nil {
		logger.Error("failed to delete profile",
			zap.String("user_id", userID.(string)),
			zap.String("request_id", c.Get("X-Request-Id")),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "profile_delete_failed"})
	}
	return c.SendStatus(204)
}

// AddAlly godoc
// @Summary Become an ally (subscribe)
// @Description Subscribe to another user's profile.
// @Tags Profiles
// @Security Bearer
// @Param user_id path string true "Target User ID"
// @Success 204 "Ally added"
// @Failure 400 "Invalid ID or Self-ally"
// @Failure 401 "Unauthorized"
// @Failure 404 "Target not found"
// @Failure 500 "Internal error"
// @Router /profiles/{user_id}/allies [post]
func (h *Handler) AddAlly(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}
	targetID := c.Params("user_id")
	if targetID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_user_id"})
	}

	if err := h.service.AddAlly(c.Context(), userID.(string), targetID); err != nil {
		if err == ErrProfileNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "profile_not_found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": "add_ally_failed"})
	}
	return c.SendStatus(204)
}

// RemoveAlly godoc
// @Summary Remove ally (unsubscribe)
// @Description Unsubscribe from another user's profile.
// @Tags Profiles
// @Security Bearer
// @Param user_id path string true "Target User ID"
// @Success 204 "Ally removed"
// @Failure 400 "Invalid ID"
// @Failure 401 "Unauthorized"
// @Failure 500 "Internal error"
// @Router /profiles/{user_id}/allies [delete]
func (h *Handler) RemoveAlly(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}
	targetID := c.Params("user_id")
	if targetID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_user_id"})
	}

	if err := h.service.RemoveAlly(c.Context(), userID.(string), targetID); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "remove_ally_failed"})
	}
	return c.SendStatus(204)
}

// GetAllies godoc
// @Summary Get allies (subscribers)
// @Description Get list of users following the target user.
// @Tags Profiles
// @Param user_id path string true "Target User ID"
// @Success 200 {array} AllyProfile
// @Failure 400 "Invalid ID"
// @Failure 500 "Internal error"
// @Router /profiles/{user_id}/allies [get]
func (h *Handler) GetAllies(c *fiber.Ctx) error {
	targetID := c.Params("user_id")
	if targetID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_user_id"})
	}

	allies, err := h.service.GetAllies(c.Context(), targetID)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "get_allies_failed"})
	}
	return c.JSON(allies)
}

// BlockUser godoc
// @Summary Block a user
// @Description Block another user.
// @Tags Profiles
// @Security Bearer
// @Param user_id path string true "Target User ID"
// @Success 204 "User blocked"
// @Failure 400 "Invalid ID or Self-block"
// @Failure 401 "Unauthorized"
// @Failure 404 "Target not found"
// @Failure 500 "Internal error"
// @Router /profiles/{user_id}/block [post]
func (h *Handler) BlockUser(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}
	targetID := c.Params("user_id")

	if err := h.service.BlockUser(c.Context(), userID.(string), targetID); err != nil {
		if err == ErrProfileNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "profile_not_found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": "block_failed"})
	}
	return c.SendStatus(204)
}

// UnblockUser godoc
// @Summary Unblock a user
// @Description Unblock a previously blocked user.
// @Tags Profiles
// @Security Bearer
// @Param user_id path string true "Target User ID"
// @Success 204 "User unblocked"
// @Failure 400 "Invalid ID"
// @Failure 401 "Unauthorized"
// @Failure 500 "Internal error"
// @Router /profiles/{user_id}/block [delete]
func (h *Handler) UnblockUser(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}
	targetID := c.Params("user_id")

	if err := h.service.UnblockUser(c.Context(), userID.(string), targetID); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "unblock_failed"})
	}
	return c.SendStatus(204)
}

// RestrictUser godoc
// @Summary Restrict a user
// @Description Restrict another user.
// @Tags Profiles
// @Security Bearer
// @Param user_id path string true "Target User ID"
// @Success 204 "User restricted"
// @Failure 400 "Invalid ID or Self-restrict"
// @Failure 401 "Unauthorized"
// @Failure 404 "Target not found"
// @Failure 500 "Internal error"
// @Router /profiles/{user_id}/restrict [post]
func (h *Handler) RestrictUser(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}
	targetID := c.Params("user_id")

	if err := h.service.RestrictUser(c.Context(), userID.(string), targetID); err != nil {
		if err == ErrProfileNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "profile_not_found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": "restrict_failed"})
	}
	return c.SendStatus(204)
}

// UnrestrictUser godoc
// @Summary Unrestrict a user
// @Description Unrestrict a previously restricted user.
// @Tags Profiles
// @Security Bearer
// @Param user_id path string true "Target User ID"
// @Success 204 "User unrestricted"
// @Failure 400 "Invalid ID"
// @Failure 401 "Unauthorized"
// @Failure 500 "Internal error"
// @Router /profiles/{user_id}/restrict [delete]
func (h *Handler) UnrestrictUser(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}
	targetID := c.Params("user_id")

	if err := h.service.UnrestrictUser(c.Context(), userID.(string), targetID); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "unrestrict_failed"})
	}
	return c.SendStatus(204)
}

// ReportUser godoc
// @Summary Report a user
// @Description Report a user for spam, harassment, etc.
// @Tags Profiles
// @Security Bearer
// @Param user_id path string true "Target User ID"
// @Param request body ReportRequest true "Report details"
// @Success 202 "Report received"
// @Failure 400 "Invalid ID, Self-report or Valid Reason"
// @Failure 401 "Unauthorized"
// @Failure 404 "Target not found"
// @Failure 500 "Internal error"
// @Router /profiles/{user_id}/report [post]
func (h *Handler) ReportUser(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}
	targetID := c.Params("user_id")

	var req ReportRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_body"})
	}

	if err := h.service.ReportUser(c.Context(), userID.(string), targetID, &req); err != nil {
		if err == ErrProfileNotFound {
			return c.Status(404).JSON(fiber.Map{"error": "profile_not_found"})
		}
		if err.Error() == "invalid_reason" {
			return c.Status(400).JSON(fiber.Map{"error": "invalid_reason"})
		}
		logger.Error("failed to report user",
			zap.String("reporter_id", userID.(string)),
			zap.String("reported_id", targetID),
			zap.String("reason", req.Reason),
			zap.String("request_id", c.Get("X-Request-Id")),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "report_failed"})
	}
	return c.SendStatus(202)
}

// SearchUsers godoc
// @Summary Search users by first/last name
// @Description Public search for referrer user selection
// @Tags Users
// @Accept json
// @Produce json
// @Param first_name query string true "First name"
// @Param last_name query string true "Last name"
// @Param limit query int false "Limit (max 50)"
// @Success 200 {array} UserSearchResult
// @Router /users/search [get]
func (h *Handler) SearchUsers(c *fiber.Ctx) error {
	firstName := c.Query("first_name")
	lastName := c.Query("last_name")
	limit := c.QueryInt("limit", 20)

	results, err := h.service.SearchUsers(c.Context(), firstName, lastName, limit)
	if err != nil {
		logger.Error("failed to search users",
			zap.String("first_name", firstName),
			zap.String("last_name", lastName),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "search_failed"})
	}

	return c.JSON(results)
}

// SearchProfilesForFeed godoc
// @Summary Search user profiles for home/feed page
// @Description Search profiles by name with privacy and block filters. Returns profiles with avatar, reputation, and rank.
// @Tags Profiles
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param query query string true "Search query (matches first name, last name, or display name)" example:"john"
// @Param limit query int false "Results limit (max 50)" default(20)
// @Param offset query int false "Pagination offset" default(0)
// @Success 200 {array} ProfileSearchResult "List of matching profiles"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Internal server error"
// @Router /profiles/search [get]
func (h *Handler) SearchProfilesForFeed(c *fiber.Ctx) error {
	userID, ok := c.Locals("user_id").(string)
	if !ok || userID == "" {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	query := c.Query("query")
	limit := c.QueryInt("limit", 20)
	offset := c.QueryInt("offset", 0)

	results, err := h.service.SearchProfilesForFeed(c.Context(), userID, query, limit, offset)
	if err != nil {
		logger.Error("failed to search profiles for feed",
			zap.String("user_id", userID),
			zap.String("query", query),
			zap.Error(err),
		)
		return c.Status(500).JSON(fiber.Map{"error": "search_failed"})
	}

	return c.JSON(results)
}
