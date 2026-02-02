package auth

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/google/uuid"
	"go.uber.org/zap"
	"golang.org/x/crypto/bcrypt"
)

// бизнес логика которая связывает jwt, repo, sms и verifiers
type Service struct {
	repo           Repository
	jwt            *JWTManager
	verifiers      map[ProviderType]OAuthVerifier
	sms            SMSSender
	logger         *zap.Logger
	economyService EconomyService
}

type EconomyService interface {
	GetOrCreateWallets(ctx context.Context, userID string) error
}

// конструктор который принимает все свойства структуры сервиса
func NewService(repo Repository, jwt *JWTManager, verifiers map[ProviderType]OAuthVerifier, smsSender SMSSender, economyService EconomyService) *Service {
	if smsSender == nil {
		smsSender = NewNoopSMSSender()
	}

	logger, _ := zap.NewProduction()

	return &Service{
		repo:           repo,
		jwt:            jwt,
		verifiers:      verifiers,
		sms:            smsSender,
		logger:         logger,
		economyService: economyService,
	}
}

// OAuth логин или регистриация, сразу создается новая сесси яи выдача токенов
func (s *Service) Login(ctx context.Context, req LoginRequest, ip string) (*LoginResponse, error) {
	s.logger.Info("oauth_login_attempt",
		zap.String("provider", string(req.ProviderType)),
		zap.String("device_id", req.DeviceID),
		zap.String("ip", ip),
	)

	verifier := s.verifiers[req.ProviderType]
	if verifier == nil {
		s.logger.Error("unsupported_oauth_provider", zap.String("provider", string(req.ProviderType)))
		return nil, fmt.Errorf("unsupported provider")
	}

	providerUser, err := verifier.Verify(ctx, req.ProviderToken)
	if err != nil {
		s.logger.Warn("oauth_token_verification_failed",
			zap.String("provider", string(req.ProviderType)),
			zap.Error(err),
		)
		return nil, ErrInvalidProviderToken
	}

	s.logger.Debug("oauth_token_verified",
		zap.String("provider", string(req.ProviderType)),
		zap.String("subject", providerUser.Subject),
		zap.String("email", providerUser.Email),
	)

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
			s.logger.Info("linking_oauth_to_existing_user",
				zap.String("user_id", user.ID),
				zap.String("provider", string(providerUser.Provider)),
			)
			identity := &Identity{
				UserID:    user.ID,
				Provider:  string(providerUser.Provider),
				Subject:   providerUser.Subject,
				Email:     providerUser.Email,
				CreatedAt: time.Now(),
			}
			if err := s.repo.CreateIdentity(ctx, identity); err != nil {
				s.logger.Error("failed_to_create_identity", zap.Error(err))
				return nil, err
			}
		} else {
			username, err := s.generateUniqueUsername(ctx, providerUser.Email)
			if err != nil {
				s.logger.Error("failed_to_generate_username", zap.Error(err))
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
				s.logger.Error("failed_to_create_user", zap.Error(err))
				return nil, err
			}

			if err := s.createUserWallets(ctx, user.ID); err != nil {
				s.logger.Error("failed_to_create_wallets",
					zap.String("user_id", user.ID),
					zap.Error(err),
				)
			}

			s.logger.Info("new_user_created",
				zap.String("user_id", user.ID),
				zap.String("username", user.Username),
				zap.String("provider", string(providerUser.Provider)),
			)

			identity := &Identity{
				UserID:    user.ID,
				Provider:  string(providerUser.Provider),
				Subject:   providerUser.Subject,
				Email:     providerUser.Email,
				CreatedAt: time.Now(),
			}
			if err := s.repo.CreateIdentity(ctx, identity); err != nil {
				s.logger.Error("failed_to_create_identity", zap.Error(err))
				return nil, err
			}
		}
	}

	last, err := s.repo.GetLastSessionByUser(ctx, user.ID)
	if err == nil && last != nil {
		if last.DeviceID != "" && last.DeviceID != req.DeviceID {
			s.logger.Warn("suspicious_login_new_device",
				zap.String("user_id", user.ID),
				zap.String("new_device", req.DeviceID),
				zap.String("old_device", last.DeviceID),
			)
		}
		if last.IP != "" && last.IP != ip {
			s.logger.Warn("suspicious_login_new_ip",
				zap.String("user_id", user.ID),
				zap.String("new_ip", ip),
				zap.String("old_ip", last.IP),
			)
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
		s.logger.Error("failed_to_create_session", zap.Error(err))
		return nil, err
	}

	access, refresh, _, err := s.jwt.IssueTokens(uuid.MustParse(user.ID), uuid.MustParse(session.ID))
	if err != nil {
		s.logger.Error("failed_to_issue_tokens", zap.Error(err))
		return nil, err
	}

	if err := s.repo.UpdateSessionsRefreshToken(ctx, session.ID, HashToken(refresh), time.Now()); err != nil {
		s.logger.Error("failed_to_save_refresh_token", zap.Error(err))
		return nil, err
	}

	_ = s.repo.TouchUser(ctx, user.ID, time.Now())

	s.logger.Info("oauth_login_success",
		zap.String("user_id", user.ID),
		zap.String("session_id", session.ID),
		zap.String("provider", string(req.ProviderType)),
	)

	return &LoginResponse{
		AccessToken:  access,
		RefreshToken: refresh,
		User:         *user,
	}, nil
}

// регистрация с имелйлом и паролем + запрос данных. Хэш пароля + токены + сессия
func (s *Service) RegisterEmail(ctx context.Context, req EmailRegisterRequest, ip string) (*LoginResponse, error) {
	s.logger.Info("email_registration_attempt",
		zap.String("email", req.Email),
		zap.String("device_id", req.DeviceID),
		zap.String("ip", ip),
	)

	if req.Email == "" || req.Password == "" || req.FirstName == "" || req.LastName == "" || req.DateOfBirth == "" {
		s.logger.Warn("email_registration_missing_fields")
		return nil, ErrInvalidCredentials
	}
	if len(req.Password) < 8 {
		s.logger.Warn("email_registration_weak_password", zap.Int("length", len(req.Password)))
		return nil, ErrWeakPassword
	}

	if _, err := s.repo.GetUserByEmail(ctx, req.Email); err == nil {
		s.logger.Warn("email_registration_email_exists", zap.String("email", req.Email))
		return nil, ErrEmailExists
	} else if !IsNotFound(err) {
		s.logger.Error("email_registration_db_error", zap.Error(err))
		return nil, err
	}

	dob, err := time.Parse("2006-01-02", req.DateOfBirth)
	if err != nil {
		s.logger.Warn("email_registration_invalid_dob", zap.String("dob", req.DateOfBirth), zap.Error(err))
		return nil, ErrInvalidDateOfBirth
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		s.logger.Error("failed_to_hash_password", zap.Error(err))
		return nil, err
	}

	username, err := s.generateUniqueUsername(ctx, req.Email)
	if err != nil {
		s.logger.Error("failed_to_generate_username", zap.String("email", req.Email), zap.Error(err))
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
		PhoneCountry:   nil,
		PhoneNumber:    nil,
		AvatarURL:      "",
		IsShadowBanned: false,
		CreatedAt:      now,
		UpdatedAt:      now,
		LastActiveAt:   now,
	}
	if err := s.repo.CreateUser(ctx, user); err != nil {
		s.logger.Error("failed_to_create_user_in_registration", zap.String("email", req.Email), zap.Error(err))
		return nil, err
	}

	if err := s.createUserWallets(ctx, user.ID); err != nil {
		s.logger.Error("failed_to_create_wallets",
			zap.String("user_id", user.ID),
			zap.Error(err),
		)
	}

	identity := &Identity{
		UserID:    user.ID,
		Provider:  string(ProviderEmail),
		Subject:   req.Email,
		Email:     req.Email,
		CreatedAt: time.Now(),
	}
	if err := s.repo.CreateIdentity(ctx, identity); err != nil {
		s.logger.Error("failed_to_create_identity", zap.String("user_id", user.ID), zap.Error(err))
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
	s.logger.Info("email_login_attempt", zap.String("email", req.Email), zap.String("ip", ip))

	if req.Email == "" || req.Password == "" {
		s.logger.Warn("email_login_missing_fields")
		return nil, ErrInvalidCredentials
	}

	user, err := s.repo.GetUserByEmail(ctx, req.Email)
	if err != nil {
		s.logger.Warn("email_login_user_not_found", zap.String("email", req.Email), zap.Error(err))
		return nil, ErrInvalidCredentials
	}
	if user.PasswordHash == "" {
		s.logger.Warn("email_login_no_password_hash", zap.String("email", req.Email))
		return nil, ErrInvalidCredentials
	}

	hashPrefix := user.PasswordHash
	if len(hashPrefix) > 10 {
		hashPrefix = hashPrefix[:10]
	}
	log.Printf("LoginEmail: comparing password for user: %s, hash length: %d, hash prefix: %s",
		user.Email, len(user.PasswordHash), hashPrefix)

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		s.logger.Warn("email_login_invalid_password", zap.String("email", req.Email))
		return nil, ErrInvalidCredentials
	}

	log.Printf("LoginEmail: successful login for user: %s (id: %s)", user.Email, user.ID)

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

// проверка существования имейла
func (s *Service) CheckEmailExists(ctx context.Context, email string) (bool, error) {
	s.logger.Info("check_email_attempt", zap.String("email", email))

	if email == "" {
		return false, ErrInvalidCredentials
	}

	_, err := s.repo.GetUserByEmail(ctx, email)
	if err != nil {
		// User not found means email doesn't exist
		return false, nil
	}

	// User found, email exists
	return true, nil
}

// генерит код и отправляет смс
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

// проверка кода ждя логина выдает токены
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

// завершает регистрацию по телефону
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
	phoneCountry := v.PhoneCountry
	phoneNumber := v.PhoneNumber
	user := &User{
		ID:             uuid.NewString(),
		Email:          "",
		Username:       username,
		FirstName:      req.FirstName,
		LastName:       req.LastName,
		DateOfBirth:    &dob,
		ReferralCode:   req.Referral,
		PhoneCountry:   &phoneCountry,
		PhoneNumber:    &phoneNumber,
		AvatarURL:      "",
		IsShadowBanned: false,
		CreatedAt:      now,
		UpdatedAt:      now,
		LastActiveAt:   now,
	}
	if err := s.repo.CreateUser(ctx, user); err != nil {
		return nil, err
	}

	if err := s.createUserWallets(ctx, user.ID); err != nil {
		s.logger.Error("failed_to_create_wallets",
			zap.String("user_id", user.ID),
			zap.Error(err),
		)
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

// обновление рефреш флоу с ротейшн и проверить поменялся ли
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

// ревоукнуть сессии
func (s *Service) Logout(ctx context.Context, sessionID string) error {
	return s.repo.RevokeSession(ctx, sessionID, time.Now())
}

// FirebasePhoneAuth handles phone authentication using Firebase ID token
// This is used for login when user already exists
func (s *Service) FirebasePhoneAuth(ctx context.Context, req FirebasePhoneAuthRequest, ip string) (*LoginResponse, error) {
	if req.FirebaseIDToken == "" || req.DeviceID == "" {
		return nil, ErrInvalidCredentials
	}

	// Type assert to get Firebase sender
	firebaseSender, ok := s.sms.(*FirebaseSMSSender)
	if !ok {
		return nil, fmt.Errorf("firebase authentication not enabled")
	}

	// Verify Firebase ID token
	token, err := firebaseSender.VerifyIDToken(ctx, req.FirebaseIDToken)
	if err != nil {
		s.logger.Warn("firebase_token_verification_failed", zap.Error(err))
		return nil, ErrInvalidProviderToken
	}

	// Extract phone number from token
	phoneNumber, ok := token.Claims["phone_number"].(string)
	if !ok || phoneNumber == "" {
		return nil, fmt.Errorf("phone number not found in token")
	}

	s.logger.Info("firebase_phone_auth_attempt",
		zap.String("phone", phoneNumber),
		zap.String("uid", token.UID),
	)

	// Parse phone number (format: +1234567890)
	if len(phoneNumber) < 3 || phoneNumber[0] != '+' {
		return nil, fmt.Errorf("invalid phone number format")
	}

	// Extract country code and number
	// Assuming format like +1234567890 where +1 is country code
	var countryCode, number string
	if len(phoneNumber) > 2 {
		// Try common country codes
		if phoneNumber[1:3] == "1 " || phoneNumber[1:2] == "1" {
			countryCode = "+1"
			number = phoneNumber[2:]
		} else if len(phoneNumber) > 3 {
			countryCode = phoneNumber[0:3] // +XX format
			number = phoneNumber[3:]
		}
	}

	// Clean the number
	number = strings.ReplaceAll(number, " ", "")
	number = strings.ReplaceAll(number, "-", "")

	// Look up user by phone
	user, err := s.repo.GetUserByPhone(ctx, countryCode, number)
	if err != nil {
		if IsNotFound(err) {
			// User doesn't exist - need to register
			return nil, ErrUserNotFound
		}
		return nil, err
	}

	// Create session
	now := time.Now()
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

	// Issue JWT tokens
	access, refresh, _, err := s.jwt.IssueTokens(uuid.MustParse(user.ID), uuid.MustParse(session.ID))
	if err != nil {
		return nil, err
	}

	if err := s.repo.UpdateSessionsRefreshToken(ctx, session.ID, HashToken(refresh), now); err != nil {
		return nil, err
	}

	_ = s.repo.TouchUser(ctx, user.ID, now)

	s.logger.Info("firebase_phone_auth_success", zap.String("user_id", user.ID))

	return &LoginResponse{
		AccessToken:  access,
		RefreshToken: refresh,
		User:         *user,
	}, nil
}

// FirebasePhoneRegister handles phone registration using Firebase ID token
func (s *Service) FirebasePhoneRegister(ctx context.Context, req FirebasePhoneRegisterRequest, ip string) (*LoginResponse, error) {
	if req.FirebaseIDToken == "" || req.FirstName == "" || req.LastName == "" || req.DateOfBirth == "" {
		return nil, ErrInvalidCredentials
	}

	// Type assert to get Firebase sender
	firebaseSender, ok := s.sms.(*FirebaseSMSSender)
	if !ok {
		return nil, fmt.Errorf("firebase authentication not enabled")
	}

	// Verify Firebase ID token
	token, err := firebaseSender.VerifyIDToken(ctx, req.FirebaseIDToken)
	if err != nil {
		s.logger.Warn("firebase_token_verification_failed", zap.Error(err))
		return nil, ErrInvalidProviderToken
	}

	// Extract phone number from token
	phoneNumber, ok := token.Claims["phone_number"].(string)
	if !ok || phoneNumber == "" {
		return nil, fmt.Errorf("phone number not found in token")
	}

	s.logger.Info("firebase_phone_register_attempt",
		zap.String("phone", phoneNumber),
		zap.String("uid", token.UID),
	)

	// Parse phone number
	if len(phoneNumber) < 3 || phoneNumber[0] != '+' {
		return nil, fmt.Errorf("invalid phone number format")
	}

	var countryCode, number string
	if len(phoneNumber) > 2 {
		if phoneNumber[1:2] == "1" {
			countryCode = "+1"
			number = phoneNumber[2:]
		} else if len(phoneNumber) > 3 {
			countryCode = phoneNumber[0:3]
			number = phoneNumber[3:]
		}
	}

	number = strings.ReplaceAll(number, " ", "")
	number = strings.ReplaceAll(number, "-", "")

	// Check if phone already exists
	if _, err := s.repo.GetUserByPhone(ctx, countryCode, number); err == nil {
		return nil, ErrPhoneExists
	} else if !IsNotFound(err) {
		return nil, err
	}

	// Parse date of birth
	dob, err := time.Parse("2006-01-02", req.DateOfBirth)
	if err != nil {
		return nil, ErrInvalidDateOfBirth
	}

	// Generate username
	base := "user" + number
	username, err := s.generateUniqueUsername(ctx, base+"@phone.local")
	if err != nil {
		return nil, err
	}

	// Create user
	now := time.Now()
	user := &User{
		ID:             uuid.NewString(),
		Email:          "",
		Username:       username,
		FirstName:      req.FirstName,
		LastName:       req.LastName,
		DateOfBirth:    &dob,
		ReferralCode:   req.Referral,
		PhoneCountry:   &countryCode,
		PhoneNumber:    &number,
		AvatarURL:      "",
		IsShadowBanned: false,
		CreatedAt:      now,
		UpdatedAt:      now,
		LastActiveAt:   now,
	}
	if err := s.repo.CreateUser(ctx, user); err != nil {
		return nil, err
	}

	// Create identity
	identity := &Identity{
		UserID:    user.ID,
		Provider:  string(ProviderPhone),
		Subject:   phoneKey(countryCode, number),
		Email:     "",
		CreatedAt: now,
	}
	if err := s.repo.CreateIdentity(ctx, identity); err != nil {
		return nil, err
	}

	// Create session
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

	// Issue tokens
	access, refresh, _, err := s.jwt.IssueTokens(uuid.MustParse(user.ID), uuid.MustParse(session.ID))
	if err != nil {
		return nil, err
	}

	if err := s.repo.UpdateSessionsRefreshToken(ctx, session.ID, HashToken(refresh), now); err != nil {
		return nil, err
	}

	s.logger.Info("firebase_phone_register_success", zap.String("user_id", user.ID))

	return &LoginResponse{
		AccessToken:  access,
		RefreshToken: refresh,
		User:         *user,
	}, nil
}

// для генерациии юзернейма универсального
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


func (s *Service) createUserWallets(ctx context.Context, userID string) error {
	if s.economyService == nil {
		// If economy is not wired yet, just skip.
		return nil
	}
	return s.economyService.GetOrCreateWallets(ctx, userID)
}
