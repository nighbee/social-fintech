package profile

import (
	"errors"
	"strconv"

	"github.com/gofiber/fiber/v2"
)

type Handler struct {
	service Service
}

func NewHandler(service Service) *Handler {
	return &Handler{service: service}
}

// GetProfile godoc
// @Summary Get user profile by username
// @Description Retrieve a user's profile by their username
// @Tags Profile
// @Accept json
// @Produce json
// @Param username path string true "Username"
// @Success 200 {object} ProfileResponse
// @Failure 404 {object} ErrorResponse
// @Failure 403 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /profiles/{username} [get]
func (h *Handler) GetProfile(c *fiber.Ctx) error {
	username := c.Params("username")
	if username == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "username_required"})
	}

	viewerUserID := getUserIDFromContext(c)

	profile, err := h.service.GetProfile(c.Context(), username, viewerUserID)
	if err != nil {
		return handleError(c, err)
	}

	return c.JSON(profile)
}

// GetMyProfile godoc
// @Summary Get authenticated user's own profile
// @Description Retrieve the authenticated user's profile
// @Tags Profile
// @Accept json
// @Produce json
// @Security Bearer
// @Success 200 {object} ProfileResponse
// @Failure 401 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /profiles/me [get]
func (h *Handler) GetMyProfile(c *fiber.Ctx) error {
	viewerUserID := getUserIDFromContext(c)
	if viewerUserID == nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}

	profile, err := h.service.GetProfileByUserID(c.Context(), *viewerUserID, viewerUserID)
	if err != nil {
		// Auto-create profile if it doesn't exist
		if errors.Is(err, ErrProfileNotFound) {
			if createErr := h.service.AdminCreateProfile(c.Context(), *viewerUserID); createErr != nil {
				return handleError(c, createErr)
			}
			// Fetch the newly created profile
			profile, err = h.service.GetProfileByUserID(c.Context(), *viewerUserID, viewerUserID)
			if err != nil {
				return handleError(c, err)
			}
		} else {
			return handleError(c, err)
		}
	}

	return c.JSON(profile)
}

// UpdateProfile godoc
// @Summary Update user profile
// @Description Update authenticated user's profile information
// @Tags Profile
// @Accept json
// @Produce json
// @Security Bearer
// @Param request body UpdateProfileRequest true "Profile update data"
// @Success 200 {object} ProfileResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /profiles/me [put]
func (h *Handler) UpdateProfile(c *fiber.Ctx) error {
	viewerUserID := getUserIDFromContext(c)
	if viewerUserID == nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}

	var req UpdateProfileRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}

	profile, err := h.service.UpdateProfile(c.Context(), *viewerUserID, &req)
	if err != nil {
		return handleError(c, err)
	}

	return c.JSON(profile)
}

// UploadAvatar godoc
// @Summary Upload profile avatar
// @Description Upload or replace user's profile avatar image
// @Tags Profile
// @Accept multipart/form-data
// @Produce json
// @Security Bearer
// @Param avatar formData file true "Avatar image (JPG, PNG, max 10MB)"
// @Success 200 {object} UploadAvatarResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 413 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /profiles/me/avatar [post]
func (h *Handler) UploadAvatar(c *fiber.Ctx) error {
	viewerUserID := getUserIDFromContext(c)
	if viewerUserID == nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}

	file, err := c.FormFile("avatar")
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "avatar_required"})
	}

	src, err := file.Open()
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "failed_to_open_file"})
	}
	defer src.Close()

	avatarURL, err := h.service.UpdateAvatar(c.Context(), *viewerUserID, src, file)
	if err != nil {
		return handleError(c, err)
	}

	return c.JSON(UploadAvatarResponse{AvatarURL: avatarURL})
}

// SearchProfiles godoc
// @Summary Search profiles
// @Description Search for user profiles by username, display name, or bio
// @Tags Profile
// @Accept json
// @Produce json
// @Param q query string true "Search query (min 2 characters)"
// @Param limit query int false "Results per page" default(20)
// @Param offset query int false "Offset for pagination" default(0)
// @Success 200 {object} ProfileSearchResponse
// @Failure 400 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /profiles/search [get]
func (h *Handler) SearchProfiles(c *fiber.Ctx) error {
	query := c.Query("q")
	if query == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "query_required"})
	}

	limit, _ := strconv.Atoi(c.Query("limit", "20"))
	offset, _ := strconv.Atoi(c.Query("offset", "0"))

	if limit > 100 {
		limit = 100
	}

	viewerUserID := getUserIDFromContext(c)

	profiles, total, err := h.service.SearchProfiles(c.Context(), query, limit, offset, viewerUserID)
	if err != nil {
		return handleError(c, err)
	}

	page := (offset / limit) + 1
	results := make([]ProfileSearchResult, len(profiles))
	for i, p := range profiles {
		result := ProfileSearchResult{
			UserID:          p.UserID,
			DisplayName:     p.DisplayName,
			ReputationScore: p.ReputationScore,
			CurrentRankTier: p.CurrentRankTier,
		}
		if p.AvatarURL != "" {
			result.AvatarURL = p.AvatarURL
		}
		if p.Location != nil {
			result.Location = *p.Location
		}
		results[i] = result
	}

	return c.JSON(ProfileSearchResponse{
		Results: results,
		Total:   total,
		Page:    page,
		Limit:   limit,
	})
}

// GetNearbyProfiles godoc
// @Summary Get nearby profiles
// @Description Get profiles near a specific location using GPS coordinates
// @Tags Profile
// @Accept json
// @Produce json
// @Param lat query number true "Latitude"
// @Param lon query number true "Longitude"
// @Param radius query int false "Radius in km" default(10)
// @Param limit query int false "Results per page" default(20)
// @Param offset query int false "Offset for pagination" default(0)
// @Success 200 {object} ProfileSearchResponse
// @Failure 400 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /profiles/nearby [get]
func (h *Handler) GetNearbyProfiles(c *fiber.Ctx) error {
	latStr := c.Query("lat")
	lonStr := c.Query("lon")

	if latStr == "" || lonStr == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "lat_lon_required"})
	}

	lat, err := strconv.ParseFloat(latStr, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_latitude"})
	}

	lon, err := strconv.ParseFloat(lonStr, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_longitude"})
	}

	radius, _ := strconv.Atoi(c.Query("radius", "10"))
	limit, _ := strconv.Atoi(c.Query("limit", "20"))
	offset, _ := strconv.Atoi(c.Query("offset", "0"))

	if limit > 100 {
		limit = 100
	}

	viewerUserID := getUserIDFromContext(c)

	profiles, total, err := h.service.GetNearbyProfiles(c.Context(), lat, lon, radius, limit, offset, viewerUserID)
	if err != nil {
		return handleError(c, err)
	}

	page := (offset / limit) + 1
	results := make([]ProfileSearchResult, len(profiles))
	for i, p := range profiles {
		result := ProfileSearchResult{
			UserID:          p.UserID,
			DisplayName:     p.DisplayName,
			ReputationScore: p.ReputationScore,
			CurrentRankTier: p.CurrentRankTier,
		}
		if p.AvatarURL != "" {
			result.AvatarURL = p.AvatarURL
		}
		if p.Location != nil {
			result.Location = *p.Location
		}
		results[i] = result
	}

	return c.JSON(ProfileSearchResponse{
		Results: results,
		Total:   total,
		Page:    page,
		Limit:   limit,
	})
}

// CreateRelationship godoc
// @Summary Create user relationship
// @Description Create a relationship (ally, favorite, block, restrict) with another user
// @Tags Profile
// @Accept json
// @Produce json
// @Security Bearer
// @Param request body CreateRelationshipRequest true "Relationship details"
// @Success 200 {object} map[string]string
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 409 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /profiles/relationships [post]
func (h *Handler) CreateRelationship(c *fiber.Ctx) error {
	viewerUserID := getUserIDFromContext(c)
	if viewerUserID == nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}

	var req CreateRelationshipRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}

	err := h.service.CreateRelationship(c.Context(), *viewerUserID, &req)
	if err != nil {
		return handleError(c, err)
	}

	return c.JSON(fiber.Map{"message": "relationship_created"})
}

// RemoveRelationship godoc
// @Summary Remove user relationship
// @Description Remove a relationship with another user
// @Tags Profile
// @Accept json
// @Produce json
// @Security Bearer
// @Param request body RemoveRelationshipRequest true "Relationship details"
// @Success 200 {object} map[string]string
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /profiles/relationships [delete]
func (h *Handler) RemoveRelationship(c *fiber.Ctx) error {
	viewerUserID := getUserIDFromContext(c)
	if viewerUserID == nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}

	var req RemoveRelationshipRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}

	err := h.service.RemoveRelationship(c.Context(), *viewerUserID, &req)
	if err != nil {
		return handleError(c, err)
	}

	return c.JSON(fiber.Map{"message": "relationship_removed"})
}

// GetAllies godoc
// @Summary Get user's allies
// @Description Get list of users that the authenticated user follows (allies)
// @Tags Profile
// @Accept json
// @Produce json
// @Security Bearer
// @Param limit query int false "Results per page" default(20)
// @Param offset query int false "Offset for pagination" default(0)
// @Success 200 {object} AlliesListResponse
// @Failure 401 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /profiles/me/allies [get]
func (h *Handler) GetAllies(c *fiber.Ctx) error {
	viewerUserID := getUserIDFromContext(c)
	if viewerUserID == nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}

	limit, _ := strconv.Atoi(c.Query("limit", "20"))
	offset, _ := strconv.Atoi(c.Query("offset", "0"))

	if limit > 100 {
		limit = 100
	}

	allies, err := h.service.GetAllies(c.Context(), *viewerUserID, limit, offset)
	if err != nil {
		return handleError(c, err)
	}

	page := (offset / limit) + 1
	allies.Page = page
	allies.Limit = limit

	return c.JSON(allies)
}

// GetFavorites godoc
// @Summary Get user's favorites
// @Description Get list of users that the authenticated user favorited
// @Tags Profile
// @Accept json
// @Produce json
// @Security Bearer
// @Param limit query int false "Results per page" default(20)
// @Param offset query int false "Offset for pagination" default(0)
// @Success 200 {object} FavoritesListResponse
// @Failure 401 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /profiles/me/favorites [get]
func (h *Handler) GetFavorites(c *fiber.Ctx) error {
	viewerUserID := getUserIDFromContext(c)
	if viewerUserID == nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}

	limit, _ := strconv.Atoi(c.Query("limit", "20"))
	offset, _ := strconv.Atoi(c.Query("offset", "0"))

	if limit > 100 {
		limit = 100
	}

	favorites, err := h.service.GetFavorites(c.Context(), *viewerUserID, limit, offset)
	if err != nil {
		return handleError(c, err)
	}

	page := (offset / limit) + 1
	favorites.Page = page
	favorites.Limit = limit

	return c.JSON(favorites)
}

// ReportUser godoc
// @Summary Report a user
// @Description Submit a report against another user for moderation review
// @Tags Profile
// @Accept json
// @Produce json
// @Security Bearer
// @Param request body ReportUserRequest true "Report details"
// @Success 200 {object} ReportResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 409 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /profiles/reports [post]
func (h *Handler) ReportUser(c *fiber.Ctx) error {
	viewerUserID := getUserIDFromContext(c)
	if viewerUserID == nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}

	var req ReportUserRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}

	reportID, err := h.service.ReportUser(c.Context(), *viewerUserID, &req)
	if err != nil {
		return handleError(c, err)
	}

	return c.JSON(ReportResponse{
		ID:      reportID,
		Status:  "pending",
		Message: "Report submitted successfully. Our team will review it.",
	})
}

// GetMyReports godoc
// @Summary Get user's submitted reports
// @Description Get list of reports submitted by the authenticated user
// @Tags Profile
// @Accept json
// @Produce json
// @Security Bearer
// @Param limit query int false "Results per page" default(20)
// @Param offset query int false "Offset for pagination" default(0)
// @Success 200 {object} map[string]interface{}
// @Failure 401 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /profiles/me/reports [get]
func (h *Handler) GetMyReports(c *fiber.Ctx) error {
	viewerUserID := getUserIDFromContext(c)
	if viewerUserID == nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}

	limit, _ := strconv.Atoi(c.Query("limit", "20"))
	offset, _ := strconv.Atoi(c.Query("offset", "0"))

	if limit > 100 {
		limit = 100
	}

	reports, total, err := h.service.GetMyReports(c.Context(), *viewerUserID, limit, offset)
	if err != nil {
		return handleError(c, err)
	}

	page := (offset / limit) + 1

	return c.JSON(fiber.Map{
		"reports": reports,
		"total":   total,
		"page":    page,
		"limit":   limit,
	})
}

func getUserIDFromContext(c *fiber.Ctx) *string {
	userID := c.Locals("user_id")
	if userID == nil {
		return nil
	}
	userIDStr, ok := userID.(string)
	if !ok {
		return nil
	}
	return &userIDStr
}

func handleError(c *fiber.Ctx, err error) error {
	if IsNotFoundError(err) {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "not_found", "message": err.Error()})
	}
	if IsValidationError(err) {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "validation_error", "message": err.Error()})
	}
	if IsPermissionError(err) {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "forbidden", "message": err.Error()})
	}
	if IsConflictError(err) {
		return c.Status(fiber.StatusConflict).JSON(fiber.Map{"error": "conflict", "message": err.Error()})
	}
	if IsRateLimitError(err) {
		return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{"error": "rate_limit", "message": err.Error()})
	}

	return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "server_error", "message": "Internal server error"})
}

type ErrorResponse struct {
	Error   string `json:"error" example:"validation_error"`
	Message string `json:"message,omitempty" example:"Invalid input"`
}
