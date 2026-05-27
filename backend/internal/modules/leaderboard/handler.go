package leaderboard

import (
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"time"

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
// @Description  Returns the weekly leaderboard for the given scope.
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

// GetMyRank godoc
// @Summary      Get my rank
// @Description  Returns the current user's rank and score for the given scope, even if outside top N.
// @Tags         Leaderboard
// @Produce      json
// @Security     Bearer
// @Param        scope  query  string  true  "Scope: district | city | country | global"
// @Success      200    {object}  MyRankResponse
// @Router       /leaderboard/me [get]
func (h *Handler) GetMyRank(c *fiber.Ctx) error {
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

	resp, err := h.svc.GetMyRank(c.Context(), userID, scope)
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

// AdminListScopes godoc
// @Summary      List all leaderboard scopes
// @Description  Returns every live leaderboard Redis key with member counts across all scopes.
// @Tags         Leaderboard Admin
// @Produce      json
// @Security     Bearer
// @Success      200  {object}  AdminListScopesResponse
// @Router       /admin/leaderboard/scopes [get]
func (h *Handler) AdminListScopes(c *fiber.Ctx) error {
	patterns := []struct {
		Scope  Scope
		Pattern string
	}{
		{ScopeGlobal, "leaderboard:global:week:*:*"},
		{ScopeCountry, "leaderboard:country:*:week:*:*"},
		{ScopeCity, "leaderboard:city:*:week:*:*"},
		{ScopeDistrict, "leaderboard:arena:*:week:*:*"},
	}

	var scopes []ScopeInfo
	for _, p := range patterns {
		keys, err := h.svc.cache.ScanKeys(c.Context(), p.Pattern, 500)
		if err != nil {
			continue
		}
		for _, key := range keys {
			card, _ := h.svc.cache.ZCard(c.Context(), key)
			info := ScopeInfo{
				Scope: p.Scope,
				Key:   key,
				Card:  card,
			}
			if p.Scope != ScopeGlobal {
				parts := splitLeaderboardKey(key)
				if region, ok := parts["region"]; ok {
					info.Region = region
				}
			}
			scopes = append(scopes, info)
		}
	}

	return c.JSON(AdminListScopesResponse{Scopes: scopes})
}

// AdminAddUser godoc
// @Summary      Add user to leaderboard
// @Description  Inserts or updates a user's score in the current week's leaderboard for a given scope and optional region.
// @Tags         Leaderboard Admin
// @Accept       json
// @Produce      json
// @Security     Bearer
// @Param        body  body  AdminAddUserRequest  true  "Add user request"
// @Success      200   {object}  map[string]string
// @Failure      400   {object}  map[string]string
// @Router       /admin/leaderboard/add-user [post]
func (h *Handler) AdminAddUser(c *fiber.Ctx) error {
	var req AdminAddUserRequest
	if err := json.Unmarshal(c.Body(), &req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid body"})
	}
	if req.UserID == "" || req.Scope == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "user_id and scope are required"})
	}

	scope := Scope(req.Scope)
	if !scope.Valid() {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid scope"})
	}

	year, week := time.Now().UTC().ISOWeek()
	key := BuildScopeKey(scope, req.Region, year, week)

	if err := h.svc.cache.ZAdd(c.Context(), key, req.Score, req.UserID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "failed to add user"})
	}
	_ = h.svc.cache.Expire(c.Context(), key, leaderboardKeyTTL)

	return c.JSON(fiber.Map{"status": "ok"})
}

// AdminRemoveUser godoc
// @Summary      Remove user from leaderboard
// @Description  Removes a user from the current week's leaderboard. If region is empty and scope is not global, removes from all regions of that scope.
// @Tags         Leaderboard Admin
// @Accept       json
// @Produce      json
// @Security     Bearer
// @Param        body  body  AdminRemoveUserRequest  true  "Remove user request"
// @Success      200   {object}  map[string]string
// @Failure      400   {object}  map[string]string
// @Router       /admin/leaderboard/remove-user [post]
func (h *Handler) AdminRemoveUser(c *fiber.Ctx) error {
	var req AdminRemoveUserRequest
	if err := json.Unmarshal(c.Body(), &req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid body"})
	}
	if req.UserID == "" || req.Scope == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "user_id and scope are required"})
	}

	scope := Scope(req.Scope)
	if !scope.Valid() {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid scope"})
	}

	year, week := time.Now().UTC().ISOWeek()

	if scope == ScopeGlobal || req.Region == "" {
		if scope == ScopeGlobal {
			key := BuildGlobalKey(year, week)
			_, _ = h.svc.cache.ZRem(c.Context(), key, req.UserID)
			return c.JSON(fiber.Map{"status": "ok"})
		}
		keys, _ := h.svc.cache.ScanKeys(c.Context(), fmt.Sprintf("leaderboard:%s:*:week:%d:%d", scopeToPrefix(scope), year, week), 500)
		for _, key := range keys {
			_, _ = h.svc.cache.ZRem(c.Context(), key, req.UserID)
		}
	} else {
		key := BuildScopeKey(scope, req.Region, year, week)
		_, _ = h.svc.cache.ZRem(c.Context(), key, req.UserID)
	}

	return c.JSON(fiber.Map{"status": "ok"})
}

// AdminAdjustScore godoc
// @Summary      Adjust user's leaderboard score
// @Description  Increments or decrements a user's score in the current week's leaderboard. Positive amount adds, negative subtracts.
// @Tags         Leaderboard Admin
// @Accept       json
// @Produce      json
// @Security     Bearer
// @Param        body  body  AdminAdjustScoreRequest  true  "Adjust score request"
// @Success      200   {object}  map[string]string
// @Failure      400   {object}  map[string]string
// @Router       /admin/leaderboard/adjust-score [post]
func (h *Handler) AdminAdjustScore(c *fiber.Ctx) error {
	var req AdminAdjustScoreRequest
	if err := json.Unmarshal(c.Body(), &req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid body"})
	}
	if req.UserID == "" || req.Scope == "" || req.Amount == 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "user_id, scope, and amount are required"})
	}

	scope := Scope(req.Scope)
	if !scope.Valid() {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid scope"})
	}

	year, week := time.Now().UTC().ISOWeek()
	var keys []string

	if scope == ScopeGlobal {
		keys = append(keys, BuildGlobalKey(year, week))
	} else if req.Region != "" {
		keys = append(keys, BuildScopeKey(scope, req.Region, year, week))
	} else {
		scanned, _ := h.svc.cache.ScanKeys(c.Context(), fmt.Sprintf("leaderboard:%s:*:week:%d:%d", scopeToPrefix(scope), year, week), 500)
		keys = scanned
	}

	for _, key := range keys {
		newScore, err := h.svc.cache.ZIncrBy(c.Context(), key, req.Amount, req.UserID)
		if err != nil {
			continue
		}
		if newScore <= 0 {
			h.svc.cache.ZRem(c.Context(), key, req.UserID)
		}
	}

	return c.JSON(fiber.Map{"status": "ok"})
}

func scopeToPrefix(scope Scope) string {
	switch scope {
	case ScopeDistrict:
		return "arena"
	case ScopeCity:
		return "city"
	case ScopeCountry:
		return "country"
	default:
		return "global"
	}
}

func splitLeaderboardKey(key string) map[string]string {
	parts := make(map[string]string)
	segments := splitByColon(key)
	if len(segments) >= 4 {
		parts["scope"] = segments[1]
	}
	if len(segments) >= 5 && segments[1] != "global" {
		parts["region"] = segments[2]
	}
	return parts
}

func splitByColon(s string) []string {
	var result []string
	current := ""
	for _, ch := range s {
		if ch == ':' {
			result = append(result, current)
			current = ""
		} else {
			current += string(ch)
		}
	}
	result = append(result, current)
	return result
}
