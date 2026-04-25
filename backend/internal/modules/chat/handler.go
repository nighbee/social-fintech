package chat

import (
	"context"
	"encoding/json"
	"strings"
	"time"

	"github.com/brightbund-backend/internal/modules/auth"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/websocket/v2"
)

type Handler struct {
	service  *Service
	hub      *Hub
	jwt      *auth.JWTManager
	authRepo auth.Repository
}

func NewHandler(service *Service, hub *Hub, jwt *auth.JWTManager, authRepo auth.Repository) *Handler {
	return &Handler{
		service:  service,
		hub:      hub,
		jwt:      jwt,
		authRepo: authRepo,
	}
}

// OpenDirectConversation godoc
// @Summary Open or get a direct conversation
// @Description Creates a new direct conversation with the specified recipient or returns the existing one.
// @Tags Chat
// @Accept json
// @Produce json
// @Security Bearer
// @Param request body CreateDirectConversationRequest true "Recipient ID"
// @Success 200 {object} Conversation
// @Failure 400 {object} map[string]string "Invalid body"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 404 {object} map[string]string "Recipient not found"
// @Router /chats/conversations/direct [post]
func (h *Handler) OpenDirectConversation(c *fiber.Ctx) error {
	userID, ok := userIDFromContext(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}

	var req CreateDirectConversationRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}

	conversation, err := h.service.OpenDirectConversation(c.Context(), userID, strings.TrimSpace(req.RecipientID))
	if err != nil {
		status := mapChatErrToHTTPStatus(err)
		return c.Status(status).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(conversation)
}

// ListConversations godoc
// @Summary List user conversations
// @Description Returns a paginated list of conversations for the authenticated user.
// @Tags Chat
// @Produce json
// @Security Bearer
// @Param cursor query string false "Pagination cursor"
// @Param limit query int false "Items per page (default 20)"
// @Success 200 {object} ListConversationsResponse
// @Failure 401 {object} map[string]string "Unauthorized"
// @Router /chats/conversations [get]
func (h *Handler) ListConversations(c *fiber.Ctx) error {
	userID, ok := userIDFromContext(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}

	resp, err := h.service.ListConversations(c.Context(), userID, c.Query("cursor"), c.QueryInt("limit", 20))
	if err != nil {
		status := mapChatErrToHTTPStatus(err)
		return c.Status(status).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(resp)
}

// ListMessages godoc
// @Summary List messages in a conversation
// @Description Returns a paginated list of messages for the specified conversation.
// @Tags Chat
// @Produce json
// @Security Bearer
// @Param conversation_id path string true "Conversation ID"
// @Param cursor query string false "Pagination cursor"
// @Param limit query int false "Items per page (default 50)"
// @Success 200 {object} ListMessagesResponse
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 403 {object} map[string]string "Forbidden — not a participant"
// @Failure 404 {object} map[string]string "Conversation not found"
// @Router /chats/conversations/{conversation_id}/messages [get]
func (h *Handler) ListMessages(c *fiber.Ctx) error {
	userID, ok := userIDFromContext(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}

	conversationID := strings.TrimSpace(c.Params("conversation_id"))
	resp, err := h.service.ListMessages(c.Context(), userID, conversationID, c.Query("cursor"), c.QueryInt("limit", 50))
	if err != nil {
		status := mapChatErrToHTTPStatus(err)
		return c.Status(status).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(resp)
}

// SendMessage godoc
// @Summary Send a message
// @Description Sends a new message to the specified conversation.
// @Tags Chat
// @Accept json
// @Produce json
// @Security Bearer
// @Param conversation_id path string true "Conversation ID"
// @Param request body SendMessageRequest true "Message body and optional media"
// @Success 201 {object} Message
// @Failure 400 {object} map[string]string "Invalid body"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 403 {object} map[string]string "Forbidden — not a participant"
// @Failure 404 {object} map[string]string "Conversation not found"
// @Router /chats/conversations/{conversation_id}/messages [post]
func (h *Handler) SendMessage(c *fiber.Ctx) error {
	userID, ok := userIDFromContext(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}

	conversationID := strings.TrimSpace(c.Params("conversation_id"))
	var req SendMessageRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}
	if strings.TrimSpace(req.IdempotencyKey) == "" {
		req.IdempotencyKey = strings.TrimSpace(c.Get("Idempotency-Key"))
	}

	message, err := h.service.SendMessage(c.Context(), userID, conversationID, &req)
	if err != nil {
		status := mapChatErrToHTTPStatus(err)
		return c.Status(status).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(fiber.StatusCreated).JSON(message)
}

// MarkConversationRead godoc
// @Summary Mark conversation as read
// @Description Updates the last read message for the user in the specified conversation.
// @Tags Chat
// @Accept json
// @Produce json
// @Security Bearer
// @Param conversation_id path string true "Conversation ID"
// @Param request body MarkReadRequest false "Optional last read message ID"
// @Success 200 {object} map[string]interface{} "Status OK and read_at timestamp"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 403 {object} map[string]string "Forbidden — not a participant"
// @Failure 404 {object} map[string]string "Conversation not found"
// @Router /chats/conversations/{conversation_id}/read [post]
func (h *Handler) MarkConversationRead(c *fiber.Ctx) error {
	userID, ok := userIDFromContext(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}

	conversationID := strings.TrimSpace(c.Params("conversation_id"))
	var req MarkReadRequest
	if len(c.Body()) > 0 {
		if err := c.BodyParser(&req); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
		}
	}

	readAt, err := h.service.MarkConversationRead(c.Context(), userID, conversationID, &req)
	if err != nil {
		status := mapChatErrToHTTPStatus(err)
		return c.Status(status).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"status": "ok", "read_at": readAt})
}

// WebSocketUpgrade godoc
// @Summary Real-time chat WebSocket
// @Description Upgrades the connection to a WebSocket for real-time message delivery and status updates.
// @Description Requires a Bearer token in the `Authorization` header OR as a `token` query parameter.
// @Tags Chat
// @Param token query string false "Auth token if header is not present"
// @Success 101 "Switching Protocols"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 403 {object} map[string]string "Account blocked"
// @Router /chats/ws [get]
func (h *Handler) WebSocketUpgrade(c *fiber.Ctx) error {
	if !websocket.IsWebSocketUpgrade(c) {
		return c.Status(fiber.StatusUpgradeRequired).JSON(fiber.Map{"error": "upgrade_required"})
	}

	token := extractToken(c)
	if token == "" {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "missing_token"})
	}

	claims, err := h.jwt.VerifyAccess(token)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid_token"})
	}

	session, err := h.authRepo.GetSessionByID(c.Context(), claims.SessionID)
	if err != nil || session == nil || session.RevokedAt != nil || session.UserID != claims.Subject {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid_session"})
	}

	user, err := h.authRepo.GetUserByID(c.Context(), claims.Subject)
	if err != nil || user == nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid_session"})
	}
	if user.IsShadowBanned || strings.EqualFold(user.ActivationStatus, "blocked") {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "account_blocked"})
	}

	c.Locals("user_id", claims.Subject)
	return c.Next()
}

func (h *Handler) ServeWebSocket(conn *websocket.Conn) {
	userID, _ := conn.Locals("user_id").(string)
	if strings.TrimSpace(userID) == "" {
		_ = conn.WriteControl(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.ClosePolicyViolation, "unauthorized"), time.Now().Add(writeWait))
		_ = conn.Close()
		return
	}

	client := h.hub.Attach(userID, conn)
	client.ReadLoop(func(payload []byte) error {
		var cmd wsClientCommand
		if err := json.Unmarshal(payload, &cmd); err != nil {
			return err
		}

		switch strings.ToLower(strings.TrimSpace(cmd.Type)) {
		case "", "ping":
			return nil
		case "mark_read", "read":
			if cmd.ConversationID == nil || strings.TrimSpace(*cmd.ConversationID) == "" {
				return ErrInvalidMessage
			}
			_, err := h.service.MarkConversationRead(context.Background(), userID, strings.TrimSpace(*cmd.ConversationID), &MarkReadRequest{
				LastReadMessageID: cmd.LastReadMessageID,
			})
			return err
		default:
			return ErrInvalidMessage
		}
	})
}

func extractToken(c *fiber.Ctx) string {
	header := strings.TrimSpace(c.Get("Authorization"))
	if strings.HasPrefix(header, "Bearer ") {
		return strings.TrimSpace(strings.TrimPrefix(header, "Bearer "))
	}
	return strings.TrimSpace(c.Query("token"))
}

func userIDFromContext(c *fiber.Ctx) (string, bool) {
	userID, ok := c.Locals("user_id").(string)
	if !ok || strings.TrimSpace(userID) == "" {
		return "", false
	}
	return userID, true
}
