package payment

import (
	"context"
	"testing"
	"github.com/brightbund-backend/internal/modules/economy"
	"github.com/brightbund-backend/internal/platform/eventbus"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"go.uber.org/zap"
)

// Mocks
type mockRepo struct {
	mock.Mock
}

func (m *mockRepo) CreatePaymentLog(ctx context.Context, log *PaymentLog) error {
	args := m.Called(ctx, log)
	return args.Error(0)
}

func (m *mockRepo) GetPaymentLogByEventID(ctx context.Context, eventID string) (*PaymentLog, error) {
	args := m.Called(ctx, eventID)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*PaymentLog), args.Error(1)
}

func (m *mockRepo) SetPatronStatus(ctx context.Context, userID string, isPatron bool) error {
	args := m.Called(ctx, userID, isPatron)
	return args.Error(0)
}

type mockEconomyService struct {
	economy.Service
	mock.Mock
}

func (m *mockEconomyService) ProcessIAPDeposit(ctx context.Context, userID string, amount int64, currency economy.CurrencyCode, receiptID string) error {
	args := m.Called(ctx, userID, amount, currency, receiptID)
	return args.Error(0)
}

type mockProfilesRepo struct {
	mock.Mock
}

func (m *mockProfilesRepo) SetPatronStatus(ctx context.Context, userID string, isPatron bool) error {
	args := m.Called(ctx, userID, isPatron)
	return args.Error(0)
}

func TestProcessIAPEvent(t *testing.T) {
	logger := zap.NewNop()
	repo := new(mockRepo)
	eco := new(mockEconomyService)
	prof := new(mockProfilesRepo)
	
	svc := &service{
		repo:           repo,
		economyService: eco,
		profilesRepo:   prof,
		logger:         logger,
	}

	ctx := context.Background()
	userID := "user-123"
	eventID := "evt-456"

	t.Run("successful seal credit", func(t *testing.T) {
		event := &eventbus.PaymentEvent{
			BaseEvent: eventbus.BaseEvent{ActorID: userID},
			EventID:   eventID,
			ProductID: ProductSponsor, // 30 seals
			Amount:    30,
		}

		repo.On("GetPaymentLogByEventID", ctx, eventID).Return(nil, nil).Once()
		eco.On("ProcessIAPDeposit", ctx, userID, int64(3000), economy.CurrencySilverSeal, eventID).Return(nil).Once()
		repo.On("CreatePaymentLog", ctx, mock.Anything).Return(nil).Once()

		err := svc.ProcessIAPEvent(ctx, event)
		assert.NoError(t, err)
		repo.AssertExpectations(t)
		eco.AssertExpectations(t)
	})

	t.Run("successful patron grant", func(t *testing.T) {
		event := &eventbus.PaymentEvent{
			BaseEvent: eventbus.BaseEvent{ActorID: userID},
			EventID:   "evt-789",
			ProductID: ProductPatron, // 120 seals + Patron
			Amount:    120,
		}

		repo.On("GetPaymentLogByEventID", ctx, "evt-789").Return(nil, nil).Once()
		eco.On("ProcessIAPDeposit", ctx, userID, int64(12000), economy.CurrencySilverSeal, "evt-789").Return(nil).Once()
		prof.On("SetPatronStatus", ctx, userID, true).Return(nil).Once()
		repo.On("CreatePaymentLog", ctx, mock.Anything).Return(nil).Once()

		err := svc.ProcessIAPEvent(ctx, event)
		assert.NoError(t, err)
		repo.AssertExpectations(t)
		eco.AssertExpectations(t)
		prof.AssertExpectations(t)
	})

	t.Run("idempotency check", func(t *testing.T) {
		event := &eventbus.PaymentEvent{EventID: "dup-123"}
		repo.On("GetPaymentLogByEventID", ctx, "dup-123").Return(&PaymentLog{}, nil).Once()

		err := svc.ProcessIAPEvent(ctx, event)
		assert.NoError(t, err) // Should skip without error
		repo.AssertExpectations(t)
	})
}
