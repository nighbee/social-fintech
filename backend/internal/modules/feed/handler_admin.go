package feed

import (
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

func (h *Handler) AdminGetPost(c *fiber.Ctx) error {
	adminID, ok := requireUserID(c)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	postID, err := uuid.Parse(c.Params("post_id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid_post_id"})
	}

	resp, err := h.service.AdminGetPost(c.Context(), postID, adminID)
	if err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "post_not_found"})
	}

	return c.JSON(resp)
}

func (h *Handler) AdminSearchPosts(c *fiber.Ctx) error {
	query := c.Query("query")
	if query == "" {
		return c.Status(400).JSON(fiber.Map{"error": "query_required"})
	}

	limit := c.QueryInt("limit", 50)
	offset := c.QueryInt("offset", 0)

	posts, total, err := h.service.AdminSearchPosts(c.Context(), query, limit, offset)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "search_failed"})
	}

	return c.JSON(fiber.Map{
		"posts": posts,
		"total": total,
	})
}
