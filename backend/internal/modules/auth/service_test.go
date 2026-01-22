package auth

import (
	"context"
	"database/sql"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
)

type fakeRepo struct {
	mu                sync.Mutex
	users             map[string]*User
	usersByEmail      map[string]string
	usersByPhone      map[string]string
	identities        map[string]string
	sessions          map[string]*Session
	phoneVerifications map[string]*PhoneVerification
}

func newFakeRepo() *fakeRepo {
	return &fakeRepo{
		users:             make(map[string]*User),
		usersByEmail:      make(map[string]string),
		usersByPhone:      make(map[string]string),
		identities:        make(map[string]string),
		sessions:          make(map[string]*Session),
		phoneVerifications: make(map[string]*PhoneVerification),
	}
}

func (r *fakeRepo) GetUserByIdentity(ctx context.Context, provider, subject string) (*User, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	key := provider + ":" + subject
	id, ok := r.identities[key]
	if !ok {
		return nil, sql.ErrNoRows
	}
	return r.users[id], nil
}

func (r *fakeRepo) GetUserByEmail(ctx context.Context, email string) (*User, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	id, ok := r.usersByEmail[email]
	if !ok {
		return nil, sql.ErrNoRows
	}
	return r.users[id], nil
}

func (r *fakeRepo) GetUserByPhone(ctx context.Context, countryCode, phoneNumber string) (*User, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	key := countryCode + ":" + phoneNumber
	id, ok := r.usersByPhone[key]
	if !ok {
		return nil, sql.ErrNoRows
	}
	return r.users[id], nil
}

func (r *fakeRepo) UsernameExists(ctx context.Context, username string) (bool, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, u := range r.users {
		if u.Username == username {
			return true, nil
		}
	}
	return false, nil
}

func (r *fakeRepo) CreateUser(ctx context.Context, user *User) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.users[user.ID] = user
	if user.Email != "" {
		r.usersByEmail[user.Email] = user.ID
	}
	if user.PhoneCountry != nil && user.PhoneNumber != nil {
		key := *user.PhoneCountry + ":" + *user.PhoneNumber
		r.usersByPhone[key] = user.ID
	}
	return nil
}

func (r *fakeRepo) CreateIdentity(ctx context.Context, identity *Identity) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	key := identity.Provider + ":" + identity.Subject
	r.identities[key] = identity.UserID
	return nil
}

func (r *fakeRepo) CreateSession(ctx context.Context, session *Session) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.sessions[session.ID] = session
	return nil
}

func (r *fakeRepo) GetSessionByID(ctx context.Context, id string) (*Session, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	s, ok := r.sessions[id]
	if !ok {
		return nil, sql.ErrNoRows
	}
	return s, nil
}

func (r *fakeRepo) GetLastSessionByUser(ctx context.Context, userID string) (*Session, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var last *Session
	for _, s := range r.sessions {
		if s.UserID != userID {
			continue
		}
		if last == nil || s.CreatedAt.After(last.CreatedAt) {
			last = s
		}
	}
	if last == nil {
		return nil, sql.ErrNoRows
	}
	return last, nil
}

func (r *fakeRepo) UpdateSessionsRefreshToken(ctx context.Context, id, refreshHash string, lastActive time.Time) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if s, ok := r.sessions[id]; ok {
		s.RefreshTokenHash = refreshHash
		s.LastActiveAt = lastActive
		return nil
	}
	return sql.ErrNoRows
}

func (r *fakeRepo) TouchSession(ctx context.Context, id string, lastActive time.Time) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if s, ok := r.sessions[id]; ok {
		s.LastActiveAt = lastActive
		return nil
	}
	return sql.ErrNoRows
}

func (r *fakeRepo) TouchUser(ctx context.Context, id string, lastActive time.Time) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if u, ok := r.users[id]; ok {
		u.LastActiveAt = lastActive
		return nil
	}
	return sql.ErrNoRows
}

func (r *fakeRepo) RevokeSession(ctx context.Context, id string, revokedAt time.Time) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if s, ok := r.sessions[id]; ok {
		s.RevokedAt = &revokedAt
		return nil
	}
	return sql.ErrNoRows
}

func (r *fakeRepo) DeleteSession(ctx context.Context, id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.sessions, id)
	return nil
}

func (r *fakeRepo) CreatePhoneVerification(ctx context.Context, v *PhoneVerification) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.phoneVerifications[v.ID] = v
	return nil
}

func (r *fakeRepo) GetPhoneVerificationByID(ctx context.Context, id string) (*PhoneVerification, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	v, ok := r.phoneVerifications[id]
	if !ok {
		return nil, sql.ErrNoRows
	}
	return v, nil
}

func (r *fakeRepo) ConsumePhoneVerification(ctx context.Context, id string, consumedAt time.Time) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if v, ok := r.phoneVerifications[id]; ok {
		v.ConsumedAt = &consumedAt
		return nil
	}
	return sql.ErrNoRows
}

func (r *fakeRepo) UsePhoneVerification(ctx context.Context, id string, usedAt time.Time) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if v, ok := r.phoneVerifications[id]; ok {
		v.UsedAt = &usedAt
		return nil
	}
	return sql.ErrNoRows
}

type captureSMSSender struct {
	mu       sync.Mutex
	lastCode string
}

func (s *captureSMSSender) Send(ctx context.Context, to, message string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	digits := make([]byte, 0, 6)
	for i := 0; i < len(message); i++ {
		ch := message[i]
		if ch >= '0' && ch <= '9' {
			digits = append(digits, ch)
		}
	}
	if len(digits) >= 6 {
		s.lastCode = string(digits[len(digits)-6:])
	}
	return nil
}

func (s *captureSMSSender) Code() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.lastCode
}

func TestRegisterEmailAndLogin(t *testing.T) {
	repo := newFakeRepo()
	jwt := NewJWTManager("test-secret", time.Minute, time.Hour)
	svc := NewService(repo, jwt, map[ProviderType]OAuthVerifier{}, nil)

	reg, err := svc.RegisterEmail(context.Background(), EmailRegisterRequest{
		Email:       "user@example.com",
		Password:    "strongpass",
		FirstName:   "John",
		LastName:    "Doe",
		DateOfBirth: "2000-01-01",
		Referral:    "ref",
		DeviceID:    "dev1",
		UserAgent:   "test",
		AppVersion:  "1.0",
	}, "127.0.0.1")
	if err != nil {
		t.Fatalf("register error: %v", err)
	}
	if reg.AccessToken == "" || reg.RefreshToken == "" {
		t.Fatalf("missing tokens after register")
	}

	login, err := svc.LoginEmail(context.Background(), EmailLoginRequest{
		Email:      "user@example.com",
		Password:   "strongpass",
		DeviceID:   "dev2",
		UserAgent:  "test",
		AppVersion: "1.0",
	}, "127.0.0.2")
	if err != nil {
		t.Fatalf("login error: %v", err)
	}
	if login.User.Email != "user@example.com" {
		t.Fatalf("unexpected user email: %s", login.User.Email)
	}
}

func TestLoginEmailInvalidPassword(t *testing.T) {
	repo := newFakeRepo()
	jwt := NewJWTManager("test-secret", time.Minute, time.Hour)
	svc := NewService(repo, jwt, map[ProviderType]OAuthVerifier{}, nil)

	_, err := svc.RegisterEmail(context.Background(), EmailRegisterRequest{
		Email:       "user@example.com",
		Password:    "strongpass",
		FirstName:   "John",
		LastName:    "Doe",
		DateOfBirth: "2000-01-01",
		DeviceID:    "dev1",
	}, "127.0.0.1")
	if err != nil {
		t.Fatalf("register error: %v", err)
	}

	_, err = svc.LoginEmail(context.Background(), EmailLoginRequest{
		Email:    "user@example.com",
		Password: "wrongpass",
		DeviceID: "dev2",
	}, "127.0.0.1")
	if err == nil || !strings.Contains(err.Error(), "invalid_credentials") {
		t.Fatalf("expected invalid credentials error")
	}
}

func TestRefreshAfterLogout(t *testing.T) {
	repo := newFakeRepo()
	jwt := NewJWTManager("test-secret", time.Minute, time.Hour)
	svc := NewService(repo, jwt, map[ProviderType]OAuthVerifier{}, nil)

	login, err := svc.RegisterEmail(context.Background(), EmailRegisterRequest{
		Email:       "user@example.com",
		Password:    "strongpass",
		FirstName:   "John",
		LastName:    "Doe",
		DateOfBirth: "2000-01-01",
		DeviceID:    "dev1",
	}, "127.0.0.1")
	if err != nil {
		t.Fatalf("register error: %v", err)
	}

	last, err := repo.GetLastSessionByUser(context.Background(), login.User.ID)
	if err != nil {
		t.Fatalf("last session error: %v", err)
	}

	if err := svc.Logout(context.Background(), last.ID); err != nil {
		t.Fatalf("logout error: %v", err)
	}

	_, err = svc.Refresh(context.Background(), login.RefreshToken)
	if err == nil || !strings.Contains(err.Error(), "invalid_refresh") {
		t.Fatalf("expected invalid refresh error")
	}
}

func TestPhoneRegisterFlow(t *testing.T) {
	repo := newFakeRepo()
	jwt := NewJWTManager("test-secret", time.Minute, time.Hour)
	sms := &captureSMSSender{}
	svc := NewService(repo, jwt, map[ProviderType]OAuthVerifier{}, sms)

	reqCode, err := svc.RequestPhoneCode(context.Background(), PhoneCodeRequest{
		CountryCode: "+1",
		PhoneNumber: "5550001",
		Purpose:     "register",
	})
	if err != nil {
		t.Fatalf("request code error: %v", err)
	}
	if reqCode.VerificationID == "" {
		t.Fatalf("missing verification id")
	}

	code := sms.Code()
	if code == "" {
		t.Fatalf("missing sms code")
	}

	verify, err := svc.VerifyPhoneCode(context.Background(), PhoneVerifyRequest{
		VerificationID: reqCode.VerificationID,
		Code:           code,
		DeviceID:       "dev1",
	}, "127.0.0.1")
	if err != nil {
		t.Fatalf("verify error: %v", err)
	}
	if !verify.Verified || verify.VerificationID == "" {
		t.Fatalf("expected verified response")
	}

	reg, err := svc.RegisterPhone(context.Background(), PhoneRegisterRequest{
		VerificationID: verify.VerificationID,
		FirstName:      "Ana",
		LastName:       "Smith",
		DateOfBirth:    "1999-12-31",
		DeviceID:       "dev1",
	}, "127.0.0.1")
	if err != nil {
		t.Fatalf("register phone error: %v", err)
	}
	if reg.AccessToken == "" || reg.RefreshToken == "" {
		t.Fatalf("missing tokens after phone register")
	}
}

func TestPhoneLoginFlow(t *testing.T) {
	repo := newFakeRepo()
	jwt := NewJWTManager("test-secret", time.Minute, time.Hour)
	sms := &captureSMSSender{}
	svc := NewService(repo, jwt, map[ProviderType]OAuthVerifier{}, sms)

	phoneCountry := "+1"
	phoneNumber := "5550002"
	user := &User{
		ID:           uuid.NewString(),
		Username:     "phoneuser",
		PhoneCountry: &phoneCountry,
		PhoneNumber:  &phoneNumber,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
		LastActiveAt: time.Now(),
	}
	if err := repo.CreateUser(context.Background(), user); err != nil {
		t.Fatalf("create user error: %v", err)
	}

	reqCode, err := svc.RequestPhoneCode(context.Background(), PhoneCodeRequest{
		CountryCode: "+1",
		PhoneNumber: "5550002",
		Purpose:     "login",
	})
	if err != nil {
		t.Fatalf("request code error: %v", err)
	}

	code := sms.Code()
	if code == "" {
		t.Fatalf("missing sms code")
	}

	verify, err := svc.VerifyPhoneCode(context.Background(), PhoneVerifyRequest{
		VerificationID: reqCode.VerificationID,
		Code:           code,
		DeviceID:       "dev1",
	}, "127.0.0.1")
	if err != nil {
		t.Fatalf("verify error: %v", err)
	}
	if !verify.Verified || verify.AccessToken == "" || verify.RefreshToken == "" {
		t.Fatalf("expected tokens on phone login")
	}
}
