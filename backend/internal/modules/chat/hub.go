package chat

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
	"time"

	"github.com/brightbund-backend/internal/platform/cache"
	"github.com/brightbund-backend/internal/platform/logger"
	"github.com/gofiber/websocket/v2"
	"github.com/google/uuid"
	"go.uber.org/zap"
)

const (
	defaultPubSubChannel = "chat:events"
	writeWait            = 10 * time.Second
	pongWait             = 60 * time.Second
	pingPeriod           = 45 * time.Second
	maxInboundFrameSize  = 1024 * 1024
)

type Hub struct {
	cache      *cache.Cache
	instanceID string
	channel    string

	mu      sync.RWMutex
	clients map[string]map[*WSClient]struct{}
	once    sync.Once
}

type WSClient struct {
	userID string
	conn   *websocket.Conn
	hub    *Hub
	send   chan []byte
}

type redisEnvelope struct {
	InstanceID string           `json:"instance_id"`
	UserIDs    []string         `json:"user_ids"`
	Envelope   RealtimeEnvelope `json:"envelope"`
}

func NewHub(cacheClient *cache.Cache) *Hub {
	return &Hub{
		cache:      cacheClient,
		instanceID: uuid.NewString(),
		channel:    defaultPubSubChannel,
		clients:    make(map[string]map[*WSClient]struct{}),
	}
}

func (h *Hub) Start(ctx context.Context) {
	if h.cache == nil {
		return
	}
	h.once.Do(func() {
		go h.consumePubSub(ctx)
	})
}

func (h *Hub) consumePubSub(ctx context.Context) {
	pubsub := h.cache.Subscribe(ctx, h.channel)
	defer pubsub.Close()

	for {
		select {
		case <-ctx.Done():
			return
		case message, ok := <-pubsub.Channel():
			if !ok {
				return
			}
			var payload redisEnvelope
			if err := json.Unmarshal([]byte(message.Payload), &payload); err != nil {
				logger.Warn("chat hub: failed to decode pubsub payload", zap.Error(err))
				continue
			}
			if payload.InstanceID == h.instanceID {
				continue
			}
			h.deliverLocal(payload.UserIDs, payload.Envelope)
		}
	}
}

func (h *Hub) Attach(userID string, conn *websocket.Conn) *WSClient {
	client := &WSClient{
		userID: userID,
		conn:   conn,
		hub:    h,
		send:   make(chan []byte, 64),
	}

	h.mu.Lock()
	if h.clients[userID] == nil {
		h.clients[userID] = make(map[*WSClient]struct{})
	}
	h.clients[userID][client] = struct{}{}
	h.mu.Unlock()

	go client.writePump()
	return client
}

func (h *Hub) Detach(client *WSClient) {
	if client == nil {
		return
	}

	h.mu.Lock()
	if bucket, ok := h.clients[client.userID]; ok {
		if _, exists := bucket[client]; exists {
			delete(bucket, client)
			close(client.send)
		}
		if len(bucket) == 0 {
			delete(h.clients, client.userID)
		}
	}
	h.mu.Unlock()
}

func (h *Hub) EmitToUsers(ctx context.Context, userIDs []string, envelope RealtimeEnvelope) error {
	if len(userIDs) == 0 {
		return nil
	}

	uniqueUsers := dedupeUserIDs(userIDs)
	h.deliverLocal(uniqueUsers, envelope)

	if h.cache == nil {
		return nil
	}

	payload := redisEnvelope{
		InstanceID: h.instanceID,
		UserIDs:    uniqueUsers,
		Envelope:   envelope,
	}
	raw, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	return h.cache.Publish(ctx, h.channel, string(raw))
}

func (h *Hub) deliverLocal(userIDs []string, envelope RealtimeEnvelope) {
	raw, err := json.Marshal(envelope)
	if err != nil {
		logger.Warn("chat hub: failed to encode realtime envelope", zap.Error(err))
		return
	}

	h.mu.RLock()
	defer h.mu.RUnlock()

	for _, userID := range userIDs {
		for client := range h.clients[userID] {
			select {
			case client.send <- raw:
			default:
				go client.forceClose(errors.New("slow consumer"))
			}
		}
	}
}

func (c *WSClient) ReadLoop(onFrame func([]byte) error) {
	defer c.forceClose(nil)

	c.conn.SetReadLimit(maxInboundFrameSize)
	_ = c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		return c.conn.SetReadDeadline(time.Now().Add(pongWait))
	})

	for {
		_, payload, err := c.conn.ReadMessage()
		if err != nil {
			return
		}
		if err := onFrame(payload); err != nil {
			_ = c.conn.WriteControl(
				websocket.CloseMessage,
				websocket.FormatCloseMessage(websocket.ClosePolicyViolation, "invalid frame"),
				time.Now().Add(writeWait),
			)
			return
		}
	}
}

func (c *WSClient) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.forceClose(nil)
	}()

	for {
		select {
		case payload, ok := <-c.send:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				_ = c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.conn.WriteMessage(websocket.TextMessage, payload); err != nil {
				return
			}
		case <-ticker.C:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func (c *WSClient) forceClose(closeErr error) {
	c.hub.Detach(c)
	_ = c.conn.Close()
	if closeErr != nil {
		logger.Debug("chat websocket closed", zap.Error(closeErr), zap.String("user_id", c.userID))
	}
}

func dedupeUserIDs(userIDs []string) []string {
	set := make(map[string]struct{}, len(userIDs))
	out := make([]string, 0, len(userIDs))
	for _, userID := range userIDs {
		if _, exists := set[userID]; exists {
			continue
		}
		set[userID] = struct{}{}
		out = append(out, userID)
	}
	return out
}
