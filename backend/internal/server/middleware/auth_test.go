package middleware

import (
	"context"
	"encoding/json"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/brightbund-backend/internal/modules/auth"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

// MockRepository for auth
type MockAuthRepository struct {
	mock.Mock
}

func (m *MockAuthRepository) CreateUser(ctx context.Context, user *auth.User) error {
	args := m.Called(ctx, user)
	return args.Error(0)
}
func (m *MockAuthRepository) GetUserByEmail(ctx context.Context, email string) (*auth.User, error) {
	args := m.Called(ctx, email)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*auth.User), args.Error(1)
}
func (m *MockAuthRepository) GetUserByID(ctx context.Context, id string) (*auth.User, error) {
	args := m.Called(ctx, id)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*auth.User), args.Error(1)
}
func (m *MockAuthRepository) GetSessionByID(ctx context.Context, id string) (*auth.Session, error) {
	args := m.Called(ctx, id)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*auth.Session), args.Error(1)
}

// Stub other methods as needed for compilation if interface requires them...
// For this test, we only need GetSessionByID basically.
// Depending on Go interface implementation, we might need all methods.
// Let's assume Repository interface is small enough or we can use a partial mock if Go allowed it,
// but in Go we need to implement the whole interface.
// To keep file short, I will add dummy implementations for likely methods in auth.Repository.
// Real implementation would be in mocks package but creating here for self-containment.

func (m *MockAuthRepository) CreateSession(ctx context.Context, session *auth.Session) error {
	return nil
}
func (m *MockAuthRepository) GetLastSessionByUser(ctx context.Context, userID string) (*auth.Session, error) {
	return nil, nil
}
func (m *MockAuthRepository) UpdateSessionsRefreshToken(ctx context.Context, id, refreshHash string, lastActive time.Time) error {
	return nil
}
func (m *MockAuthRepository) TouchSession(ctx context.Context, id string, lastActive time.Time) error {
	return nil
}
func (m *MockAuthRepository) TouchUser(ctx context.Context, id string, lastActive time.Time) error {
	return nil
}
func (m *MockAuthRepository) RevokeSession(ctx context.Context, id string, revokedAt time.Time) error {
	return nil
}
func (m *MockAuthRepository) DeleteSession(ctx context.Context, id string) error { return nil }

func (m *MockAuthRepository) CreatePhoneVerification(ctx context.Context, v *auth.PhoneVerification) error {
	return nil
}
func (m *MockAuthRepository) GetPhoneVerificationByID(ctx context.Context, id string) (*auth.PhoneVerification, error) {
	return nil, nil
}
func (m *MockAuthRepository) ConsumePhoneVerification(ctx context.Context, id string, consumedAt time.Time) error {
	return nil
}
func (m *MockAuthRepository) UsePhoneVerification(ctx context.Context, id string, usedAt time.Time) error {
	return nil
}
func (m *MockAuthRepository) CreateEmailVerification(ctx context.Context, v *auth.EmailVerification) error {
	return nil
}
func (m *MockAuthRepository) GetEmailVerificationByID(ctx context.Context, id string) (*auth.EmailVerification, error) {
	return nil, nil
}
func (m *MockAuthRepository) ConsumeEmailVerification(ctx context.Context, id string, consumedAt time.Time) error {
	return nil
}
func (m *MockAuthRepository) UseEmailVerification(ctx context.Context, id string, usedAt time.Time) error {
	return nil
}
func (m *MockAuthRepository) SetAdminStatus(ctx context.Context, userID string, isAdmin bool) error {
	return nil
}

func (m *MockAuthRepository) GetUserByPhone(ctx context.Context, countryCode, number string) (*auth.User, error) {
	return nil, nil
}
func (m *MockAuthRepository) GetUserPasswordHashByID(ctx context.Context, userID string) (string, error) {
	return "", nil
}
func (m *MockAuthRepository) UsernameExists(ctx context.Context, username string) (bool, error) {
	return false, nil
}
func (m *MockAuthRepository) CreateIdentity(ctx context.Context, identity *auth.Identity) error {
	return nil
}
func (m *MockAuthRepository) UpdateUserPasswordHashByID(ctx context.Context, userID, passwordHash string, updatedAt time.Time) error {
	return nil
}
func (m *MockAuthRepository) ListActiveSessionsByUser(ctx context.Context, userID string) ([]auth.Session, error) {
	return nil, nil
}
func (m *MockAuthRepository) CountActiveSessionsByUser(ctx context.Context, userID string) (int, error) {
	return 0, nil
}
func (m *MockAuthRepository) RevokeSessionForUser(ctx context.Context, userID, sessionID string, revokedAt time.Time) error {
	return nil
}
func (m *MockAuthRepository) RevokeAllSessionsExceptForUser(ctx context.Context, userID, currentSessionID string, revokedAt time.Time) error {
	return nil
}
func (m *MockAuthRepository) RevokeAllSessionsForUser(ctx context.Context, userID string, revokedAt time.Time) error {
	return nil
}
func (m *MockAuthRepository) GetUserPhoneByID(ctx context.Context, userID string) (string, string, error) {
	return "", "", nil
}
func (m *MockAuthRepository) GetUserByIdentity(ctx context.Context, provider, subject string) (*auth.User, error) {
	return nil, nil
}
func (m *MockAuthRepository) RecordRegistrationSignal(ctx context.Context, deviceID, ip string, now time.Time) (int, int, error) {
	return 0, 0, nil
}
func (m *MockAuthRepository) RecordActivationLogin(ctx context.Context, userID string, now time.Time) (string, bool, error) {
	return "active", false, nil
}

func (m *MockAuthRepository) BanUser(ctx context.Context, userID string, restrictionsUntil *time.Time, reason string) error {
	return nil
}


func TestRequireAuth(t *testing.T) {
	// Setup
	app := fiber.New()
	secret := "secret123"
	jwtManager := auth.NewJWTManager(secret, 15*time.Minute, 7*24*time.Hour)
	repo := new(MockAuthRepository)

	app.Use(RequireAuth(jwtManager, repo))
	app.Get("/protected", func(c *fiber.Ctx) error {
		return c.SendStatus(fiber.StatusOK)
	})

	t.Run("Missing Authorization Header", func(t *testing.T) {
		req := httptest.NewRequest("GET", "/protected", nil)
		resp, _ := app.Test(req)
		assert.Equal(t, fiber.StatusUnauthorized, resp.StatusCode)

		var body map[string]string
		json.NewDecoder(resp.Body).Decode(&body)
		assert.Equal(t, "missing_token", body["error"])
	})

	t.Run("Invalid Token Format (UUID only)", func(t *testing.T) {
		req := httptest.NewRequest("GET", "/protected", nil)
		req.Header.Set("Authorization", "550e8400-e29b-41d4-a716-446655440000")
		resp, _ := app.Test(req)

		assert.Equal(t, fiber.StatusUnauthorized, resp.StatusCode)
		var body map[string]string
		json.NewDecoder(resp.Body).Decode(&body)
		assert.Equal(t, "invalid_token_format", body["error"])
	})

	t.Run("Valid Token", func(t *testing.T) {
		userID := uuid.New()
		sessionID := uuid.New()
		token, _, _, _ := jwtManager.IssueTokens(userID, sessionID)

		repo.On("GetSessionByID", mock.Anything, sessionID.String()).Return(&auth.Session{
			ID:        sessionID.String(),
			UserID:    userID.String(),
			RevokedAt: nil,
		}, nil)
		repo.On("GetUserByID", mock.Anything, userID.String()).Return(&auth.User{
			ID:               userID.String(),
			ActivationStatus: "active",
			IsShadowBanned:   false,
		}, nil)

		req := httptest.NewRequest("GET", "/protected", nil)
		req.Header.Set("Authorization", "Bearer "+token)
		resp, _ := app.Test(req)

		assert.Equal(t, fiber.StatusOK, resp.StatusCode)
	})
}
