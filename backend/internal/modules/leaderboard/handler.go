package leaderboard

import (
	"errors"
	"strconv"

	"github.com/gofiber/fiber/v2"
)

type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// Get godoc
// @Summary      Get leaderboard
// @Description  Returns the weekly leaderboard for the given scope. District, city, and country scopes use the current user's registered location. Global scope requires no location.
// @Tags         Leaderboard
// @Produce      json
// @Security     Bearer
// @Param        scope  query  string  true   "Scope: district | city | country | global"
// @Param        limit  query  int     false  "Number of entries (1-100, default 50)"
// @Success      200    {object}  Response
// @Failure      400    {object}  map[string]string
// @Failure      401    {object}  map[string]string
// @Router       /leaderboard [get]
func (h *Handler) Get(c *fiber.Ctx) error {
	userID, ok := c.Locals("user_id").(string)
	if !ok || userID == "" {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}

	scope := Scope(c.Query("scope", string(ScopeGlobal)))
	if !scope.Valid() {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "invalid scope, use: district | city | country | global",
		})
	}

	limit := 50
	if v := c.Query("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			limit = n
		}
	}

	resp, err := h.svc.GetLeaderboard(c.Context(), userID, scope, limit)
	if err != nil {
		if errors.Is(err, ErrNoLocation) {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "location not set for this scope",
			})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "leaderboard_failed"})
	}

	return c.JSON(resp)
}
