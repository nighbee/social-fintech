package auth

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

// бизнес логика которая связывает jwt, repo, sms и verifiers
type Service struct {
	repo      Repository
	jwt       *JWTManager
	verifiers map[ProviderType]OAuthVerifier
	sms       SMSSender
}

//конструктор который принимает все свойства структуры сервиса
func NewService(repo Repository, jwt *JWTManager, verifiers map[ProviderType]OAuthVerifier, smsSender SMSSender) *Service {
	if smsSender == nil {
		smsSender = NewNoopSMSSender()
	}
	return &Service{
		repo:      repo,
		jwt:       jwt,
		verifiers: verifiers,
		sms:       smsSender,
	}
}

//OAuth логин или регистриация, сразу создается новая сесси яи выдача токенов
func (s *Service) Login(ctx context.Context, req LoginRequest, ip string) (*LoginResponse, error) {
	verifier := s.verifiers[req.ProviderType]
	if verifier == nil {
		return nil, fmt.Errorf("unsupported provider")
	}

	providerUser, err := verifier.Verify(ctx, req.ProviderToken)
	if err != nil {
		return nil, ErrInvalidProviderToken
	}

	user, err := s.repo.GetUserByIdentity(ctx, string(providerUser.Provider), providerUser.Subject)
	if err != nil && !IsNotFound(err) {
		return nil, err
	}
	if IsNotFound(err) {
		user = nil
	}

	if user == nil {
		if providerUser.Email == "" {
			return nil, ErrEmailRequired
		}

		existing, err := s.repo.GetUserByEmail(ctx, providerUser.Email)
		if err != nil && !IsNotFound(err) {
			return nil, err
		}
		if IsNotFound(err) {
			existing = nil
		}

		if existing != nil {
			user = existing
			identity := &Identity{
				UserID:    user.ID,
				Provider:  string(providerUser.Provider),
				Subject:   providerUser.Subject,
				Email:     providerUser.Email,
				CreatedAt: time.Now(),
			}
			if err := s.repo.CreateIdentity(ctx, identity); err != nil {
				return nil, err
			}
		} else {
			username, err := s.generateUniqueUsername(ctx, providerUser.Email)
			if err != nil {
				return nil, err
			}

			now := time.Now()
			user = &User{
				ID:             uuid.NewString(),
				Email:          providerUser.Email,
				Username:       username,
				AvatarURL:      "",
				IsShadowBanned: false,
				CreatedAt:      now,
				UpdatedAt:      now,
				LastActiveAt:   now,
			}
			if err := s.repo.CreateUser(ctx, user); err != nil {
				return nil, err
			}
			identity := &Identity{
				UserID:    user.ID,
				Provider:  string(providerUser.Provider),
				Subject:   providerUser.Subject,
				Email:     providerUser.Email,
				CreatedAt: time.Now(),
			}
			if err := s.repo.CreateIdentity(ctx, identity); err != nil {
				return nil, err
			}
		}
	}

	last, err := s.repo.GetLastSessionByUser(ctx, user.ID)
	if err == nil && last != nil {
		if last.DeviceID != "" && last.DeviceID != req.DeviceID {
			log.Printf("suspicious_login: user=%s new_device=%s old_device=%s", user.ID, req.DeviceID, last.DeviceID)
		}
		if last.IP != "" && last.IP != ip {
			log.Printf("suspicious_login: user=%s new_ip=%s old_ip=%s", user.ID, ip, last.IP)
		}
	}

	session := &Session{
		ID:           uuid.NewString(),
		UserID:       user.ID,
		DeviceID:     req.DeviceID,
		IP:           ip,
		UserAgent:    req.UserAgent,
		AppVersion:   req.AppVersion,
		LastActiveAt: time.Now(),
		CreatedAt:    time.Now(),
	}
	if err := s.repo.CreateSession(ctx, session); err != nil {
		return nil, err
	}

	access, refresh, _, err := s.jwt.IssueTokens(uuid.MustParse(user.ID), uuid.MustParse(session.ID))
	if err != nil {
		return nil, err
	}

	if err := s.repo.UpdateSessionsRefreshToken(ctx, session.ID, HashToken(refresh), time.Now()); err != nil {
		return nil, err
	}

	_ = s.repo.TouchUser(ctx, user.ID, time.Now())

	return &LoginResponse{
		AccessToken:  access,
		RefreshToken: refresh,
		User:         *user,
	}, nil
}


// регистрация с имелйлом и паролем + запрос данных. Хэш пароля + токены + сессия
func (s *Service) RegisterEmail(ctx context.Context, req EmailRegisterRequest, ip string) (*LoginResponse, error) {
	if req.Email == "" || req.Password == "" || req.FirstName == "" || req.LastName == "" || req.DateOfBirth == "" {
		return nil, ErrInvalidCredentials
	}
	if len(req.Password) < 8 {
		return nil, ErrWeakPassword
	}

	if _, err := s.repo.GetUserByEmail(ctx, req.Email); err == nil {
		return nil, ErrEmailExists
	} else if !IsNotFound(err) {
		return nil, err
	}

	dob, err := time.Parse("2006-01-02", req.DateOfBirth)
	if err != nil {
		return nil, ErrInvalidDateOfBirth
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	username, err := s.generateUniqueUsername(ctx, req.Email)
	if err != nil {
		return nil, err
	}

	now := time.Now()
	user := &User{
		ID:             uuid.NewString(),
		Email:          req.Email,
		Username:       username,
		PasswordHash:   string(hash),
		FirstName:      req.FirstName,
		LastName:       req.LastName,
		DateOfBirth:    &dob,
		ReferralCode:   req.Referral,
		AvatarURL:      "",
		IsShadowBanned: false,
		CreatedAt:      now,
		UpdatedAt:      now,
		LastActiveAt:   now,
	}
	if err := s.repo.CreateUser(ctx, user); err != nil {
		return nil, err
	}

	identity := &Identity{
		UserID:    user.ID,
		Provider:  string(ProviderEmail),
		Subject:   req.Email,
		Email:     req.Email,
		CreatedAt: time.Now(),
	}
	if err := s.repo.CreateIdentity(ctx, identity); err != nil {
		return nil, err
	}

	session := &Session{
		ID:           uuid.NewString(),
		UserID:       user.ID,
		DeviceID:     req.DeviceID,
		IP:           ip,
		UserAgent:    req.UserAgent,
		AppVersion:   req.AppVersion,
		LastActiveAt: time.Now(),
		CreatedAt:    time.Now(),
	}
	if err := s.repo.CreateSession(ctx, session); err != nil {
		return nil, err
	}

	access, refresh, _, err := s.jwt.IssueTokens(uuid.MustParse(user.ID), uuid.MustParse(session.ID))
	if err != nil {
		return nil, err
	}

	if err := s.repo.UpdateSessionsRefreshToken(ctx, session.ID, HashToken(refresh), time.Now()); err != nil {
		return nil, err
	}

	_ = s.repo.TouchUser(ctx, user.ID, time.Now())

	return &LoginResponse{
		AccessToken:  access,
		RefreshToken: refresh,
		User:         *user,
	}, nil
}


// логин по имейлу+паролю
func (s *Service) LoginEmail(ctx context.Context, req EmailLoginRequest, ip string) (*LoginResponse, error) {
	if req.Email == "" || req.Password == "" {
		return nil, ErrInvalidCredentials
	}

	user, err := s.repo.GetUserByEmail(ctx, req.Email)
	if err != nil {
		return nil, ErrInvalidCredentials
	}
	if user.PasswordHash == "" {
		return nil, ErrInvalidCredentials
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, ErrInvalidCredentials
	}

	session := &Session{
		ID:           uuid.NewString(),
		UserID:       user.ID,
		DeviceID:     req.DeviceID,
		IP:           ip,
		UserAgent:    req.UserAgent,
		AppVersion:   req.AppVersion,
		LastActiveAt: time.Now(),
		CreatedAt:    time.Now(),
	}
	if err := s.repo.CreateSession(ctx, session); err != nil {
		return nil, err
	}

	access, refresh, _, err := s.jwt.IssueTokens(uuid.MustParse(user.ID), uuid.MustParse(session.ID))
	if err != nil {
		return nil, err
	}

	if err := s.repo.UpdateSessionsRefreshToken(ctx, session.ID, HashToken(refresh), time.Now()); err != nil {
		return nil, err
	}

	_ = s.repo.TouchUser(ctx, user.ID, time.Now())

	return &LoginResponse{
		AccessToken:  access,
		RefreshToken: refresh,
		User:         *user,
	}, nil
}

//генерит код и отправляет смс
func (s *Service) RequestPhoneCode(ctx context.Context, req PhoneCodeRequest) (*PhoneCodeResponse, error) {
	cc, pn := normalizePhone(req.CountryCode, req.PhoneNumber)
	if cc == "" || pn == "" {
		return nil, ErrInvalidPhone
	}

	if req.Purpose != "login" && req.Purpose != "register" {
		return nil, ErrInvalidPurpose
	}

	if req.Purpose == "register" {
		if _, err := s.repo.GetUserByPhone(ctx, cc, pn); err == nil {
			return nil, ErrPhoneExists
		} else if !IsNotFound(err) {
			return nil, err
		}
	}

	if req.Purpose == "login" {
		if _, err := s.repo.GetUserByPhone(ctx, cc, pn); err != nil {
			return nil, ErrUserNotFound
		}
	}

	code, err := generateOTP()
	if err != nil {
		return nil, err
	}

	v := &PhoneVerification{
		ID:           uuid.NewString(),
		PhoneCountry: cc,
		PhoneNumber:  pn,
		Purpose:      req.Purpose,
		CodeHash:     hashCode(code),
		ExpiresAt:    time.Now().Add(phoneCodeTTL),
		CreatedAt:    time.Now(),
	}
	if err := s.repo.CreatePhoneVerification(ctx, v); err != nil {
		return nil, err
	}

	to := fmt.Sprintf("%s%s", cc, pn)
	message := fmt.Sprintf("Your BrightBund code is %s", code)
	if err := s.sms.Send(ctx, to, message); err != nil {
		return nil, err
	}

	return &PhoneCodeResponse{
		VerificationID: v.ID,
		ExpiresAt:      v.ExpiresAt,
	}, nil
}


//проверка кода ждя логина выдает токены
func (s *Service) VerifyPhoneCode(ctx context.Context, req PhoneVerifyRequest, ip string) (*PhoneVerifyResponse, error) {
	if req.VerificationID == "" || req.Code == "" {
		return nil, ErrInvalidCode
	}

	v, err := s.repo.GetPhoneVerificationByID(ctx, req.VerificationID)
	if err != nil {
		return nil, ErrInvalidCode
	}

	if v.ExpiresAt.Before(time.Now()) {
		return nil, ErrVerificationExpired
	}
	if v.ConsumedAt != nil {
		return nil, ErrVerificationConsumed
	}
	if v.CodeHash != hashCode(req.Code) {
		return nil, ErrInvalidCode
	}

	now := time.Now()
	if err := s.repo.ConsumePhoneVerification(ctx, v.ID, now); err != nil {
		return nil, err
	}

	if v.Purpose == "register" {
		return &PhoneVerifyResponse{
			Verified:       true,
			VerificationID: v.ID,
		}, nil
	}

	// login
	user, err := s.repo.GetUserByPhone(ctx, v.PhoneCountry, v.PhoneNumber)
	if err != nil {
		return nil, ErrUserNotFound
	}

	session := &Session{
		ID:           uuid.NewString(),
		UserID:       user.ID,
		DeviceID:     req.DeviceID,
		IP:           ip,
		UserAgent:    req.UserAgent,
		AppVersion:   req.AppVersion,
		LastActiveAt: now,
		CreatedAt:    now,
	}
	if err := s.repo.CreateSession(ctx, session); err != nil {
		return nil, err
	}

	access, refresh, _, err := s.jwt.IssueTokens(uuid.MustParse(user.ID), uuid.MustParse(session.ID))
	if err != nil {
		return nil, err
	}

	if err := s.repo.UpdateSessionsRefreshToken(ctx, session.ID, HashToken(refresh), time.Now()); err != nil {
		return nil, err
	}

	_ = s.repo.TouchUser(ctx, user.ID, time.Now())

	return &PhoneVerifyResponse{
		Verified:     true,
		AccessToken:  access,
		RefreshToken: refresh,
		User:         user,
	}, nil
}


//завершает регистрацию по телефону
func (s *Service) RegisterPhone(ctx context.Context, req PhoneRegisterRequest, ip string) (*LoginResponse, error) {
	if req.VerificationID == "" || req.FirstName == "" || req.LastName == "" || req.DateOfBirth == "" {
		return nil, ErrInvalidCredentials
	}

	v, err := s.repo.GetPhoneVerificationByID(ctx, req.VerificationID)
	if err != nil {
		return nil, ErrInvalidCode
	}

	if v.Purpose != "register" {
		return nil, ErrInvalidPurpose
	}
	if v.ExpiresAt.Before(time.Now()) {
		return nil, ErrVerificationExpired
	}
	if v.ConsumedAt == nil {
		return nil, ErrVerificationNotReady
	}
	if v.UsedAt != nil {
		return nil, ErrVerificationConsumed
	}

	if _, err := s.repo.GetUserByPhone(ctx, v.PhoneCountry, v.PhoneNumber); err == nil {
		return nil, ErrPhoneExists
	} else if !IsNotFound(err) {
		return nil, err
	}

	dob, err := time.Parse("2006-01-02", req.DateOfBirth)
	if err != nil {
		return nil, ErrInvalidDateOfBirth
	}

	base := "user" + v.PhoneNumber
	username, err := s.generateUniqueUsername(ctx, base+"@phone.local")
	if err != nil {
		return nil, err
	}

	now := time.Now()
	user := &User{
		ID:             uuid.NewString(),
		Email:          "",
		Username:       username,
		FirstName:      req.FirstName,
		LastName:       req.LastName,
		DateOfBirth:    &dob,
		ReferralCode:   req.Referral,
		PhoneCountry:   v.PhoneCountry,
		PhoneNumber:    v.PhoneNumber,
		AvatarURL:      "",
		IsShadowBanned: false,
		CreatedAt:      now,
		UpdatedAt:      now,
		LastActiveAt:   now,
	}
	if err := s.repo.CreateUser(ctx, user); err != nil {
		return nil, err
	}

	identity := &Identity{
		UserID:    user.ID,
		Provider:  string(ProviderPhone),
		Subject:   phoneKey(v.PhoneCountry, v.PhoneNumber),
		Email:     "",
		CreatedAt: time.Now(),
	}
	if err := s.repo.CreateIdentity(ctx, identity); err != nil {
		return nil, err
	}

	session := &Session{
		ID:           uuid.NewString(),
		UserID:       user.ID,
		DeviceID:     req.DeviceID,
		IP:           ip,
		UserAgent:    req.UserAgent,
		AppVersion:   req.AppVersion,
		LastActiveAt: now,
		CreatedAt:    now,
	}
	if err := s.repo.CreateSession(ctx, session); err != nil {
		return nil, err
	}

	access, refresh, _, err := s.jwt.IssueTokens(uuid.MustParse(user.ID), uuid.MustParse(session.ID))
	if err != nil {
		return nil, err
	}

	if err := s.repo.UpdateSessionsRefreshToken(ctx, session.ID, HashToken(refresh), time.Now()); err != nil {
		return nil, err
	}

	if err := s.repo.UsePhoneVerification(ctx, v.ID, time.Now()); err != nil {
		return nil, err
	}

	_ = s.repo.TouchUser(ctx, user.ID, time.Now())

	return &LoginResponse{
		AccessToken:  access,
		RefreshToken: refresh,
		User:         *user,
	}, nil
}


//обновление рефреш флоу с ротейшн и проверить поменялся ли
func (s *Service) Refresh(ctx context.Context, refreshToken string) (*LoginResponse, error) {
	claims, err := s.jwt.VerifyRefresh(refreshToken)
	if err != nil {
		return nil, ErrInvalidRefresh
	}

	session, err := s.repo.GetSessionByID(ctx, claims.SessionID)
	if err != nil {
		return nil, ErrSessionNotFound
	}

	if session.RevokedAt != nil {
		return nil, ErrInvalidRefresh
	}

	if session.RefreshTokenHash == "" || session.RefreshTokenHash != HashToken(refreshToken) {
		return nil, ErrInvalidRefresh
	}

	userID := uuid.MustParse(session.UserID)
	sessionID := uuid.MustParse(session.ID)

	access, refresh, _, err := s.jwt.IssueTokens(userID, sessionID)
	if err != nil {
		return nil, err
	}

	now := time.Now()
	if err := s.repo.UpdateSessionsRefreshToken(ctx, session.ID, HashToken(refresh), now); err != nil {
		return nil, err
	}

	_ = s.repo.TouchUser(ctx, session.UserID, now)

	return &LoginResponse{
		AccessToken:  access,
		RefreshToken: refresh,
		User:         User{ID: session.UserID},
	}, nil
}

//ревоукнуть сессии
func (s *Service) Logout(ctx context.Context, sessionID string) error {
	return s.repo.RevokeSession(ctx, sessionID, time.Now())
}

//для генерациии юзернейма универсального
func (s *Service) generateUniqueUsername(ctx context.Context, email string) (string, error) {
	base := strings.Split(email, "@")[0]
	base = cleanUsername(base)
	username := base

	for i := 0; i < 20; i++ {
		exists, err := s.repo.UsernameExists(ctx, username)
		if err != nil {
			return "", err
		}
		if !exists {
			return username, nil
		}
		username = fmt.Sprintf("%s%d", base, i+1)
	}

	return "", fmt.Errorf("unable to generate username")
}
