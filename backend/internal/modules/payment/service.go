package payment

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/brightbund-backend/internal/modules/economy"
	"github.com/brightbund-backend/internal/modules/profiles"
	"github.com/brightbund-backend/internal/platform/eventbus"
	"github.com/google/uuid"
	"go.uber.org/zap"
)

type Service interface {
	HandleRevenueCatWebhook(ctx context.Context, authToken string, payload *RevenueCatWebhook) error
	ProcessIAPEvent(ctx context.Context, event *eventbus.PaymentEvent) error
}

type service struct {
	repo           Repository
	economyService economy.Service
	profilesRepo   *profiles.Repository
	producer       *eventbus.Producer
	logger         *zap.Logger
	webhookToken   string
}

func NewService(repo Repository, economyService economy.Service, profilesRepo *profiles.Repository, producer *eventbus.Producer, logger *zap.Logger, webhookToken string) Service {
	return &service{
		repo:           repo,
		economyService: economyService,
		profilesRepo:   profilesRepo,
		producer:       producer,
		logger:         logger,
		webhookToken:   webhookToken,
	}
}

func (s *service) HandleRevenueCatWebhook(ctx context.Context, authToken string, payload *RevenueCatWebhook) error {
	// 1. Verify Auth Token
	if s.webhookToken != "" && authToken != s.webhookToken {
		return errors.New("invalid authorization token")
	}

	event := payload.Event
	s.logger.Info("received revenuecat webhook",
		zap.String("event_id", event.ID),
		zap.String("type", event.Type),
		zap.String("user_id", event.AppUserID),
		zap.String("product_id", event.ProductID),
	)

	// 2. Map to internal event and publish to Kafka
	// We only process purchase/renewal/refund events
	switch event.Type {
	case EventInitialPurchase, EventRenewal, EventNonRenewingPurchase, EventRefund:
		paymentEvent := eventbus.PaymentEvent{
			BaseEvent: eventbus.BaseEvent{
				Type:      eventbus.TypeIAPReceived,
				ActorID:   event.AppUserID,
				Timestamp: time.Now().UTC(),
			},
			EventID:   event.ID,
			ProductID: event.ProductID,
			Amount:    GetSealAmount(event.ProductID),
			Price:     event.Price,
			Currency:  event.Currency,
		}

		err := s.producer.Publish(ctx, eventbus.TypeIAPReceived, paymentEvent)
		if err != nil {
			return fmt.Errorf("failed to publish payment event: %w", err)
		}

	default:
		s.logger.Debug("ignoring revenuecat event type", zap.String("type", event.Type))
	}

	return nil
}

func (s *service) ProcessIAPEvent(ctx context.Context, event *eventbus.PaymentEvent) error {
	// 1. Idempotency Check
	existing, err := s.repo.GetPaymentLogByEventID(ctx, event.EventID)
	if err != nil {
		return fmt.Errorf("failed to check idempotency: %w", err)
	}
	if existing != nil {
		s.logger.Info("skipping already processed payment event", zap.String("event_id", event.EventID))
		return nil
	}

	// 2. Handle Based on Product/Action
	// For refunds, we might want to deduct seals, but for now let's focus on granting
	// (Note: event.BaseEvent.Type is payment.iap_received, we might need a subtype or check original RC type)
	
	// Credit Silver Seals
	if event.Amount > 0 {
		// Convert Seals to Centinels (1 Seal = 100 Centinels)
		amountCentinels := event.Amount * 100
		
		err := s.economyService.ProcessIAPDeposit(ctx, event.ActorID, amountCentinels, economy.CurrencySilverSeal, event.EventID)
		if err != nil {
			return fmt.Errorf("failed to credit seals: %w", err)
		}
		s.logger.Info("credited silver seals from IAP", 
			zap.String("user_id", event.ActorID), 
			zap.Int64("seals", event.Amount),
		)
	}

	// Grant Patron Status if applicable
	if IsPatronProduct(event.ProductID) {
		err := s.profilesRepo.SetPatronStatus(ctx, event.ActorID, true)
		if err != nil {
			s.logger.Error("failed to set patron status", zap.Error(err), zap.String("user_id", event.ActorID))
			// We don't fail the whole process if just the badge fails, but it should be logged
		} else {
			s.logger.Info("granted patron status", zap.String("user_id", event.ActorID))
		}
	}

	// 3. Log the processed event
	paymentLog := &PaymentLog{
		ID:        uuid.New().String(),
		EventID:   event.EventID,
		UserID:    event.ActorID,
		ProductID: event.ProductID,
		Amount:    event.Amount,
		EventType: string(eventbus.TypeIAPReceived),
	}

	err = s.repo.CreatePaymentLog(ctx, paymentLog)
	if err != nil {
		return fmt.Errorf("failed to create payment log: %w", err)
	}

	return nil
}
