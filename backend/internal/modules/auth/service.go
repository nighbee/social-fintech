package auth

import (
	"context"
	"fmt"
	"log"
	"net"
	"strings"
	"time"

	"github.com/brightbund-backend/internal/platform/observability"
	"github.com/brightbund-backend/internal/platform/eventbus"
	"github.com/google/uuid"
	"go.uber.org/zap"
	"golang.org/x/crypto/bcrypt"
)

type EconomyService interface {
	GetOrCreateWallets(ctx context.Context, userID string) error
	ProcessReferralBonus(ctx context.Context, referrerUserID, refereeUserID string) error
	RegisterPendingReferral(ctx context.Context, referrerUserID, refereeUserID string) error
	ActivateDeferredReferral(ctx context.Context, refereeUserID string) error
	GrantSignupBonus(ctx context.Context, userID string) error
}

const (
	activationDeviceRegistrationsLimit = 3
	activationIPRegistrationsLimit     = 5
	activationDeviceSuspiciousLimit    = 6
	activationIPSuspiciousLimit        = 10
	activationDeviceHardBlockLimit     = 10
	activationIPHardBlockLimit         = 15
	maxUsernameLength                  = 30
)

// бизнес логика которая связывает jwt, repo, sms и verifiers
type Service struct {
	repo           Repository
	jwt            *JWTManager
	verifiers      map[ProviderType]OAuthVerifier
	sms            SMSSender
	email          EmailSender
	logger         *zap.Logger
	eventBus       *eventbus.Producer
	economyService EconomyService
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
		email:          NewNoopEmailSender(),
		logger:         logger,
		economyService: economyService,
	}
}

// SetEmailSender swaps the placeholder NoopEmailSender for a real
// transport (SMTP, SES, etc). Called from main.go after wiring config.
func (s *Service) SetEmailSender(sender EmailSender) {
	if sender == nil {
		return
	}
	s.email = sender
}

func (s *Service) SetEventBus(eb *eventbus.Producer) {
	s.eventBus = eb
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
			// Initial registration via OAuth (provider name/dob might be missing)
			username, err := s.generateUniqueUsername(ctx, "", "", nil)
			if err != nil {
				s.logger.Error("failed_to_generate_username", zap.Error(err))
				return nil, err
			}

			now := time.Now()
			activationStatus, restrictionsUntil, activationErr := s.resolveInitialActivation(ctx, req.DeviceID, ip)
			if activationErr != nil {
				s.logger.Warn("initial_activation_resolution_failed", zap.Error(activationErr))
				activationStatus = "restricted"
				restrictionsUntil = nil
			}
			user = &User{
				ID:               uuid.NewString(),
				Email:            providerUser.Email,
				Username:         username,
				AvatarURL:        "",
				IsShadowBanned:   false,
				ActivationStatus: activationStatus,
				ActivationUnlockedAt: func() *time.Time {
					if activationStatus == "active" {
						t := now
						return &t
					}
					return nil
				}(),
				RestrictionsUntil: restrictionsUntil,
				CreatedAt:         now,
				UpdatedAt:         now,
				LastActiveAt:      now,
			}
			if err := s.repo.CreateUser(ctx, user); err != nil {
				s.logger.Error("failed_to_create_user", zap.Error(err))
				return nil, err
			}

			if s.economyService != nil {
				if err := s.economyService.GrantSignupBonus(ctx, user.ID); err != nil {
					s.logger.Warn("signup_bonus_failed", zap.String("user_id", user.ID), zap.Error(err))
				}
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

	if err := ensureUserCanAuthenticate(user); err != nil {
		return nil, err
	}

	last, err := s.repo.GetLastSessionByUser(ctx, user.ID)
	if err == nil && last != nil {
		if last.DeviceID != "" && last.DeviceID != req.DeviceID {
			s.logger.Warn("suspicious_login_new_device",
				zap.String("user_id", user.ID),
				zap.String("new_device", req.DeviceID),
				zap.String("old_device", last.DeviceID),
			)
			_ = s.eventBus.Publish(ctx, eventbus.TypeSecuritySignin, eventbus.SystemEvent{UserID: user.ID, Details: "New sign-in from a new device"})
		}
		if last.IP != "" && last.IP != ip {
			s.logger.Warn("suspicious_login_new_ip",
				zap.String("user_id", user.ID),
				zap.String("new_ip", ip),
				zap.String("old_ip", last.IP),
			)
			_ = s.eventBus.Publish(ctx, eventbus.TypeSecuritySignin, eventbus.SystemEvent{UserID: user.ID, Details: "New sign-in from a new IP address"})
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

	if _, err := s.onSuccessfulLogin(ctx, user.ID); err != nil {
		s.logger.Warn("activation_login_tracking_failed", zap.String("user_id", user.ID), zap.Error(err))
	}

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

func (s *Service) onSuccessfulLogin(ctx context.Context, userID string) (bool, error) {
	now := time.Now()
	_, activated, err := s.repo.RecordActivationLogin(ctx, userID, now)
	if err != nil {
		return false, err
	}
	_ = s.repo.TouchUser(ctx, userID, now)
	if activated && s.economyService != nil {
		if err := s.economyService.ActivateDeferredReferral(ctx, userID); err != nil {
			s.logger.Warn("activate_deferred_referral_failed", zap.String("user_id", userID), zap.Error(err))
		}
	}
	return activated, nil
}

func (s *Service) resolveInitialActivation(ctx context.Context, deviceID, ip string) (string, *time.Time, error) {
	if isTrustedRegistrationIP(ip) {
		unlockedAt := time.Now()
		return "active", &unlockedAt, nil
	}

	deviceCount, ipCount, err := s.repo.RecordRegistrationSignal(ctx, deviceID, ip, time.Now())
	if err != nil {
		return "", nil, err
	}
	if deviceCount > activationDeviceHardBlockLimit || ipCount > activationIPHardBlockLimit {
		return "", nil, ErrRegistrationRateLimited
	}

	status, until := classifyInitialActivation(deviceCount, ipCount, time.Now())
	return status, until, nil
}

func classifyInitialActivation(deviceCount, ipCount int, now time.Time) (string, *time.Time) {
	if deviceCount > activationDeviceRegistrationsLimit || ipCount > activationIPRegistrationsLimit {
		// Escalate to suspicious when device/IP signal is far above baseline.
		if deviceCount > activationDeviceSuspiciousLimit || ipCount > activationIPSuspiciousLimit {
			until := now.Add(120 * time.Hour)
			return "suspicious", &until
		}
		until := now.Add(72 * time.Hour)
		return "restricted", &until
	}

	unlockedAt := now
	return "active", &unlockedAt
}

func isTrustedRegistrationIP(rawIP string) bool {
	ip := net.ParseIP(strings.TrimSpace(rawIP))
	if ip == nil {
		return false
	}
	return ip.IsLoopback()
}

func validateDateOfBirth(rawDOB string, now time.Time) (time.Time, error) {
	dob, err := time.Parse("2006-01-02", rawDOB)
	if err != nil {
		return time.Time{}, ErrInvalidDateOfBirth
	}

	minDOB := time.Date(1950, time.January, 1, 0, 0, 0, 0, time.UTC)
	if dob.Before(minDOB) {
		return time.Time{}, ErrDateOfBirthTooOld
	}

	if dob.After(now.AddDate(-5, 0, 0)) {
		return time.Time{}, ErrDateOfBirthTooYoung
	}

	return dob, nil
}

func ensureUserCanAuthenticate(user *User) error {
	if user == nil {
		return ErrInvalidCredentials
	}
	// Hard moderation block: account is fully blocked from authentication flows.
	if user.IsShadowBanned || strings.EqualFold(user.ActivationStatus, "blocked") {
		return ErrAccountBlocked
	}
	return nil
}

// регистрация с имелйлом и паролем + запрос данных. Хэш пароля + токены + сессия
func (s *Service) RegisterEmail(ctx context.Context, req EmailRegisterRequest, ip string) (*LoginResponse, error) {
	observability.IncRegistrationAttempt("email")
	fail := func(reason string, err error) (*LoginResponse, error) {
		observability.IncRegistrationFailure("email", reason)
		return nil, err
	}

	s.logger.Info("email_registration_attempt",
		zap.String("email", req.Email),
		zap.String("device_id", req.DeviceID),
		zap.String("ip", ip),
	)

	if req.Email == "" || req.Password == "" || req.FirstName == "" || req.LastName == "" || req.DateOfBirth == "" {
		s.logger.Warn("email_registration_missing_fields")
		return fail("invalid_credentials", ErrInvalidCredentials)
	}
	if err := verifyCaptchaToken(ctx, req.CaptchaToken, ip); err != nil {
		return fail("captcha_invalid", err)
	}
	if len(req.Password) < 8 {
		s.logger.Warn("email_registration_weak_password", zap.Int("length", len(req.Password)))
		return fail("weak_password", ErrWeakPassword)
	}

	if _, err := s.repo.GetUserByEmail(ctx, req.Email); err == nil {
		s.logger.Warn("email_registration_email_exists", zap.String("email", req.Email))
		return fail("email_exists", ErrEmailExists)
	} else if !IsNotFound(err) {
		s.logger.Error("email_registration_db_error", zap.Error(err))
		return fail("db_error", err)
	}

	now := time.Now()
	dob, err := validateDateOfBirth(req.DateOfBirth, now)
	if err != nil {
		s.logger.Warn("email_registration_invalid_dob", zap.String("dob", req.DateOfBirth), zap.Error(err))
		return fail("invalid_dob", err)
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		s.logger.Error("failed_to_hash_password", zap.Error(err))
		return fail("hash_failed", err)
	}

	username, err := s.generateUniqueUsername(ctx, req.FirstName, req.LastName, &dob)
	if err != nil {
		s.logger.Error("failed_to_generate_username", zap.String("email", req.Email), zap.Error(err))
		return fail("username_generation_failed", err)
	}

	activationStatus, restrictionsUntil, err := s.resolveInitialActivation(ctx, req.DeviceID, ip)
	if err != nil {
		if err == ErrRegistrationRateLimited {
			s.logger.Warn("email_registration_rate_limited", zap.String("email", req.Email), zap.String("ip", ip))
			return fail("rate_limited", err)
		}
		s.logger.Warn("initial_activation_resolution_failed", zap.Error(err))
		activationStatus = "restricted"
		restrictionsUntil = nil
	}
	user := &User{
		ID:               uuid.NewString(),
		Email:            req.Email,
		Username:         username,
		PasswordHash:     string(hash),
		FirstName:        req.FirstName,
		LastName:         req.LastName,
		DateOfBirth:      &dob,
		ReferralCode:     "",
		PhoneCountry:     nil,
		PhoneNumber:      nil,
		AvatarURL:        "",
		IsShadowBanned:   false,
		ActivationStatus: activationStatus,
		ActivationUnlockedAt: func() *time.Time {
			if activationStatus == "active" {
				t := now
				return &t
			}
			return nil
		}(),
		RestrictionsUntil: restrictionsUntil,
		CreatedAt:         now,
		UpdatedAt:         now,
		LastActiveAt:      now,
	}
	if err := s.repo.CreateUser(ctx, user); err != nil {
		s.logger.Error("failed_to_create_user_in_registration", zap.String("email", req.Email), zap.Error(err))
		return fail("create_user_failed", err)
	}

	if s.economyService != nil {
		if err := s.economyService.GrantSignupBonus(ctx, user.ID); err != nil {
			s.logger.Warn("signup_bonus_failed", zap.String("user_id", user.ID), zap.Error(err))
		}
	}

	if req.ReferrerUserID != "" && s.economyService != nil {
		referralFn := s.economyService.RegisterPendingReferral
		if activationStatus == "active" {
			referralFn = s.economyService.ProcessReferralBonus
		}
		if err := referralFn(ctx, req.ReferrerUserID, user.ID); err != nil {
			s.logger.Warn("referral_bonus_failed",
				zap.String("referrer_user_id", req.ReferrerUserID),
				zap.String("referee_user_id", user.ID),
				zap.Error(err),
			)
		}
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
		return fail("create_identity_failed", err)
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
		return fail("create_session_failed", err)
	}

	access, refresh, _, err := s.jwt.IssueTokens(uuid.MustParse(user.ID), uuid.MustParse(session.ID))
	if err != nil {
		return fail("issue_tokens_failed", err)
	}

	if err := s.repo.UpdateSessionsRefreshToken(ctx, session.ID, HashToken(refresh), time.Now()); err != nil {
		return fail("save_refresh_failed", err)
	}

	if _, err := s.onSuccessfulLogin(ctx, user.ID); err != nil {
		s.logger.Warn("activation_login_tracking_failed", zap.String("user_id", user.ID), zap.Error(err))
	}
	observability.IncRegistrationSuccess("email")

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
	if err := ensureUserCanAuthenticate(user); err != nil {
		return nil, err
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

	if _, err := s.onSuccessfulLogin(ctx, user.ID); err != nil {
		s.logger.Warn("activation_login_tracking_failed", zap.String("user_id", user.ID), zap.Error(err))
	}

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
	if err := validateE164(cc, pn); err != nil {
		return nil, err
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
	if err := ensureUserCanAuthenticate(user); err != nil {
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

	_ = s.repo.TouchUser(ctx, user.ID, time.Now())

	return &PhoneVerifyResponse{
		Verified:     true,
		AccessToken:  access,
		RefreshToken: refresh,
		User:         user,
	}, nil
}

// RequestEmailCode sends a 6-digit confirmation code to the requested
// email address. Purpose drives existence checks:
//   - register: email must NOT already be tied to an account
//   - login | password_reset: email MUST already exist
//   - email_change: caller-specific, no existence check (used post-auth)
//
// The code is hashed before persistence; only the email address itself
// is stored in plaintext (it's required to send the message).
func (s *Service) RequestEmailCode(ctx context.Context, req EmailCodeRequest) (*EmailCodeResponse, error) {
	email := normalizeEmail(req.Email)
	if err := validateEmail(email); err != nil {
		return nil, err
	}

	switch req.Purpose {
	case "register":
		if _, err := s.repo.GetUserByEmail(ctx, email); err == nil {
			return nil, ErrEmailExists
		} else if !IsNotFound(err) {
			return nil, err
		}
	case "login", "password_reset":
		if _, err := s.repo.GetUserByEmail(ctx, email); err != nil {
			if IsNotFound(err) {
				return nil, ErrUserNotFound
			}
			return nil, err
		}
	case "email_change":
		// no-op: caller has already authenticated and is opting into the new address
	default:
		return nil, ErrInvalidPurpose
	}

	code, err := generate6DigitOTP()
	if err != nil {
		return nil, err
	}

	v := &EmailVerification{
		ID:        uuid.NewString(),
		Email:     email,
		Purpose:   req.Purpose,
		CodeHash:  hashEmailCode(code),
		ExpiresAt: time.Now().Add(emailCodeTTL),
		CreatedAt: time.Now(),
	}
	if err := s.repo.CreateEmailVerification(ctx, v); err != nil {
		return nil, err
	}

	subject := "Your BrightBund verification code"
	body := fmt.Sprintf("Your BrightBund code is %s. It expires in 10 minutes.", code)
	if err := s.email.Send(ctx, email, subject, body); err != nil {
		s.logger.Warn("email_send_failed", zap.String("email", email), zap.Error(err))
		// Fail soft: surface a generic error so we don't leak whether the
		// transport succeeded but the inbox refused, matching SMS behaviour.
		return nil, err
	}

	return &EmailCodeResponse{
		VerificationID: v.ID,
		ExpiresAt:      v.ExpiresAt,
	}, nil
}

// VerifyEmailCode validates a 6-digit code against an outstanding
// EmailVerification row. On success the row is marked consumed. The
// caller (signup, password reset, etc.) is then expected to act on the
// returned verification id within its own flow.
func (s *Service) VerifyEmailCode(ctx context.Context, req EmailVerifyRequest) (*EmailVerifyResponse, error) {
	if req.VerificationID == "" || req.Code == "" {
		return nil, ErrInvalidCode
	}

	v, err := s.repo.GetEmailVerificationByID(ctx, req.VerificationID)
	if err != nil {
		return nil, ErrInvalidCode
	}
	if v.ExpiresAt.Before(time.Now()) {
		return nil, ErrVerificationExpired
	}
	if v.ConsumedAt != nil {
		return nil, ErrVerificationConsumed
	}
	if v.CodeHash != hashEmailCode(req.Code) {
		return nil, ErrInvalidCode
	}

	if err := s.repo.ConsumeEmailVerification(ctx, v.ID, time.Now()); err != nil {
		return nil, err
	}

	return &EmailVerifyResponse{
		Verified:       true,
		VerificationID: v.ID,
	}, nil
}

// завершает регистрацию по телефону
func (s *Service) RegisterPhone(ctx context.Context, req PhoneRegisterRequest, ip string) (*LoginResponse, error) {
	observability.IncRegistrationAttempt("phone")
	fail := func(reason string, err error) (*LoginResponse, error) {
		observability.IncRegistrationFailure("phone", reason)
		return nil, err
	}

	if req.VerificationID == "" || req.FirstName == "" || req.LastName == "" || req.DateOfBirth == "" {
		return fail("invalid_credentials", ErrInvalidCredentials)
	}
	if err := verifyCaptchaToken(ctx, req.CaptchaToken, ip); err != nil {
		return fail("captcha_invalid", err)
	}

	v, err := s.repo.GetPhoneVerificationByID(ctx, req.VerificationID)
	if err != nil {
		return fail("invalid_code", ErrInvalidCode)
	}

	if v.Purpose != "register" {
		return fail("invalid_purpose", ErrInvalidPurpose)
	}
	if v.ExpiresAt.Before(time.Now()) {
		return fail("verification_expired", ErrVerificationExpired)
	}
	if v.ConsumedAt == nil {
		return fail("verification_not_ready", ErrVerificationNotReady)
	}
	if v.UsedAt != nil {
		return fail("verification_consumed", ErrVerificationConsumed)
	}

	if _, err := s.repo.GetUserByPhone(ctx, v.PhoneCountry, v.PhoneNumber); err == nil {
		return fail("phone_exists", ErrPhoneExists)
	} else if !IsNotFound(err) {
		return fail("db_error", err)
	}

	now := time.Now()
	dob, err := validateDateOfBirth(req.DateOfBirth, now)
	if err != nil {
		return fail("invalid_dob", err)
	}

	username, err := s.generateUniqueUsername(ctx, req.FirstName, req.LastName, &dob)
	if err != nil {
		return fail("username_generation_failed", err)
	}

	activationStatus, restrictionsUntil, err := s.resolveInitialActivation(ctx, req.DeviceID, ip)
	if err != nil {
		if err == ErrRegistrationRateLimited {
			s.logger.Warn("phone_registration_rate_limited", zap.String("ip", ip))
			return fail("rate_limited", err)
		}
		s.logger.Warn("initial_activation_resolution_failed", zap.Error(err))
		activationStatus = "restricted"
		restrictionsUntil = nil
	}
	phoneCountry := v.PhoneCountry
	phoneNumber := v.PhoneNumber
	user := &User{
		ID:               uuid.NewString(),
		Email:            "",
		Username:         username,
		FirstName:        req.FirstName,
		LastName:         req.LastName,
		DateOfBirth:      &dob,
		ReferralCode:     "",
		PhoneCountry:     &phoneCountry,
		PhoneNumber:      &phoneNumber,
		AvatarURL:        "",
		IsShadowBanned:   false,
		ActivationStatus: activationStatus,
		ActivationUnlockedAt: func() *time.Time {
			if activationStatus == "active" {
				t := now
				return &t
			}
			return nil
		}(),
		RestrictionsUntil: restrictionsUntil,
		CreatedAt:         now,
		UpdatedAt:         now,
		LastActiveAt:      now,
	}
	if err := s.repo.CreateUser(ctx, user); err != nil {
		return fail("create_user_failed", err)
	}

	if s.economyService != nil {
		if err := s.economyService.GrantSignupBonus(ctx, user.ID); err != nil {
			s.logger.Warn("signup_bonus_failed", zap.String("user_id", user.ID), zap.Error(err))
		}
	}

	if req.ReferrerUserID != "" && s.economyService != nil {
		referralFn := s.economyService.RegisterPendingReferral
		if activationStatus == "active" {
			referralFn = s.economyService.ProcessReferralBonus
		}
		if err := referralFn(ctx, req.ReferrerUserID, user.ID); err != nil {
			s.logger.Warn("referral_bonus_failed",
				zap.String("referrer_user_id", req.ReferrerUserID),
				zap.String("referee_user_id", user.ID),
				zap.Error(err),
			)
		}
	}

	identity := &Identity{
		UserID:    user.ID,
		Provider:  string(ProviderPhone),
		Subject:   phoneKey(v.PhoneCountry, v.PhoneNumber),
		Email:     "",
		CreatedAt: time.Now(),
	}
	if err := s.repo.CreateIdentity(ctx, identity); err != nil {
		return fail("create_identity_failed", err)
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
		return fail("create_session_failed", err)
	}

	access, refresh, _, err := s.jwt.IssueTokens(uuid.MustParse(user.ID), uuid.MustParse(session.ID))
	if err != nil {
		return fail("issue_tokens_failed", err)
	}

	if err := s.repo.UpdateSessionsRefreshToken(ctx, session.ID, HashToken(refresh), time.Now()); err != nil {
		return fail("save_refresh_failed", err)
	}

	if err := s.repo.UsePhoneVerification(ctx, v.ID, time.Now()); err != nil {
		return fail("use_verification_failed", err)
	}

	if _, err := s.onSuccessfulLogin(ctx, user.ID); err != nil {
		s.logger.Warn("activation_login_tracking_failed", zap.String("user_id", user.ID), zap.Error(err))
	}
	observability.IncRegistrationSuccess("phone")

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
	if err := ensureUserCanAuthenticate(user); err != nil {
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
	observability.IncRegistrationAttempt("firebase_phone")
	fail := func(reason string, err error) (*LoginResponse, error) {
		observability.IncRegistrationFailure("firebase_phone", reason)
		return nil, err
	}

	if req.FirebaseIDToken == "" || req.FirstName == "" || req.LastName == "" || req.DateOfBirth == "" {
		return fail("invalid_credentials", ErrInvalidCredentials)
	}
	if err := verifyCaptchaToken(ctx, req.CaptchaToken, ip); err != nil {
		return fail("captcha_invalid", err)
	}

	// Type assert to get Firebase sender
	firebaseSender, ok := s.sms.(*FirebaseSMSSender)
	if !ok {
		return fail("firebase_not_enabled", fmt.Errorf("firebase authentication not enabled"))
	}

	// Verify Firebase ID token
	token, err := firebaseSender.VerifyIDToken(ctx, req.FirebaseIDToken)
	if err != nil {
		s.logger.Warn("firebase_token_verification_failed", zap.Error(err))
		return fail("invalid_provider_token", ErrInvalidProviderToken)
	}

	// Extract phone number from token
	phoneNumber, ok := token.Claims["phone_number"].(string)
	if !ok || phoneNumber == "" {
		return fail("phone_missing", fmt.Errorf("phone number not found in token"))
	}

	s.logger.Info("firebase_phone_register_attempt",
		zap.String("phone", phoneNumber),
		zap.String("uid", token.UID),
	)

	// Parse phone number
	if len(phoneNumber) < 3 || phoneNumber[0] != '+' {
		return fail("invalid_phone_format", fmt.Errorf("invalid phone number format"))
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
		return fail("phone_exists", ErrPhoneExists)
	} else if !IsNotFound(err) {
		return fail("db_error", err)
	}

	// Parse date of birth
	now := time.Now()
	dob, err := validateDateOfBirth(req.DateOfBirth, now)
	if err != nil {
		return fail("invalid_dob", err)
	}

	// Generate username
	username, err := s.generateUniqueUsername(ctx, req.FirstName, req.LastName, &dob)
	if err != nil {
		return fail("username_generation_failed", err)
	}

	// Create user
	activationStatus, restrictionsUntil, err := s.resolveInitialActivation(ctx, req.DeviceID, ip)
	if err != nil {
		if err == ErrRegistrationRateLimited {
			s.logger.Warn("firebase_phone_register_rate_limited", zap.String("ip", ip))
			return fail("rate_limited", err)
		}
		s.logger.Warn("initial_activation_resolution_failed", zap.Error(err))
		activationStatus = "restricted"
		restrictionsUntil = nil
	}

	user := &User{
		ID:               uuid.NewString(),
		Email:            "",
		Username:         username,
		FirstName:        req.FirstName,
		LastName:         req.LastName,
		DateOfBirth:      &dob,
		ReferralCode:     "",
		PhoneCountry:     &countryCode,
		PhoneNumber:      &number,
		AvatarURL:        "",
		IsShadowBanned:   false,
		ActivationStatus: activationStatus,
		ActivationUnlockedAt: func() *time.Time {
			if activationStatus == "active" {
				t := now
				return &t
			}
			return nil
		}(),
		RestrictionsUntil: restrictionsUntil,
		CreatedAt:         now,
		UpdatedAt:         now,
		LastActiveAt:      now,
	}
	if err := s.repo.CreateUser(ctx, user); err != nil {
		return fail("create_user_failed", err)
	}

	if s.economyService != nil {
		if err := s.economyService.GrantSignupBonus(ctx, user.ID); err != nil {
			s.logger.Warn("signup_bonus_failed", zap.String("user_id", user.ID), zap.Error(err))
		}
	}

	if req.ReferrerUserID != "" {
		if err := s.economyService.ProcessReferralBonus(ctx, req.ReferrerUserID, user.ID); err != nil {
			s.logger.Warn("referral_bonus_failed",
				zap.String("referrer_user_id", req.ReferrerUserID),
				zap.String("referee_user_id", user.ID),
				zap.Error(err),
			)
		}
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
		return fail("create_identity_failed", err)
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
		return fail("create_session_failed", err)
	}

	// Issue tokens
	access, refresh, _, err := s.jwt.IssueTokens(uuid.MustParse(user.ID), uuid.MustParse(session.ID))
	if err != nil {
		return fail("issue_tokens_failed", err)
	}

	if err := s.repo.UpdateSessionsRefreshToken(ctx, session.ID, HashToken(refresh), now); err != nil {
		return fail("save_refresh_failed", err)
	}

	s.logger.Info("firebase_phone_register_success", zap.String("user_id", user.ID))
	observability.IncRegistrationSuccess("firebase_phone")

	return &LoginResponse{
		AccessToken:  access,
		RefreshToken: refresh,
		User:         *user,
	}, nil
}

// для генерациии юзернейма универсального (имя_фамилия_деньрождения)
func (s *Service) generateUniqueUsername(ctx context.Context, firstName, lastName string, dob *time.Time) (string, error) {
	var base string
	if firstName != "" && lastName != "" && dob != nil {
		base = fmt.Sprintf("%s_%s_%02d",
			cleanUsername(firstName),
			cleanUsername(lastName),
			dob.Day())
	} else {
		// Fallback for cases where name/dob is missing (e.g. initial OAuth)
		base = "user_" + strings.ReplaceAll(uuid.NewString()[:8], "-", "")
	}
	base = trimUsername(base)

	username := base
	for i := 0; i < 20; i++ {
		exists, err := s.repo.UsernameExists(ctx, username)
		if err != nil {
			return "", err
		}
		if !exists {
			return username, nil
		}
		// If base exists, append a counter
		suffix := fmt.Sprintf("_%d", i+1)
		username = trimUsername(base)
		if len(username)+len(suffix) > maxUsernameLength {
			username = username[:maxUsernameLength-len(suffix)]
		}
		username = username + suffix
	}

	return "", fmt.Errorf("unable to generate unique username after 20 attempts")
}

func trimUsername(username string) string {
	username = strings.TrimSpace(username)
	if username == "" {
		return "user_" + strings.ReplaceAll(uuid.NewString()[:8], "-", "")
	}
	if len(username) <= maxUsernameLength {
		return username
	}
	return username[:maxUsernameLength]
}

// EnsureAdminAccount creates the standalone admin account if it does not exist.
// Username is the email, passwordHash is a bcrypt hash (set in config).
func (s *Service) EnsureAdminAccount(ctx context.Context, username, passwordHash string) error {
	if username == "" || passwordHash == "" {
		return nil
	}

	user, err := s.repo.GetUserByEmail(ctx, username)
	if err == nil {
		// User exists — keep password hash and admin status in sync
		if user.PasswordHash != passwordHash {
			if upErr := s.repo.UpdateUserPasswordHashByID(ctx, user.ID, passwordHash, time.Now()); upErr != nil {
				return upErr
			}
			s.logger.Info("admin_password_updated", zap.String("email", username))
		}
		if !user.IsAdmin {
			if setErr := s.repo.SetAdminStatus(ctx, user.ID, true); setErr != nil {
				return setErr
			}
			s.logger.Info("promoted_existing_user_to_admin", zap.String("email", username))
		}
		return nil
	}
	if !IsNotFound(err) {
		return err
	}

	// User doesn't exist — create it
	now := time.Now()
	createUser := &User{
		ID:               uuid.NewString(),
		Email:            username,
		Username:         strings.Split(username, "@")[0],
		PasswordHash:     passwordHash,
		FirstName:        "Admin",
		LastName:         "",
		DateOfBirth:      nil,
		ReferralCode:     "",
		IsAdmin:          true,
		IsShadowBanned:   false,
		ActivationStatus: "active",
		ActivationUnlockedAt: &now,
		CreatedAt:         now,
		UpdatedAt:         now,
		LastActiveAt:      now,
	}

	if err := s.repo.CreateUser(ctx, createUser); err != nil {
		return err
	}

	// Grant signup bonus wallet
	if s.economyService != nil {
		_ = s.economyService.GetOrCreateWallets(ctx, createUser.ID)
	}

	s.logger.Info("admin_account_created", zap.String("email", username))
	return nil
}

// EnsureAdmins promotes the given emails to admin status
func (s *Service) EnsureAdmins(ctx context.Context, emails []string) error {
	if len(emails) == 0 {
		return nil
	}

	s.logger.Info("ensuring_admins", zap.Strings("emails", emails))

	for _, email := range emails {
		if email == "" {
			continue
		}

		user, err := s.repo.GetUserByEmail(ctx, email)
		if err != nil {
			if IsNotFound(err) {
				s.logger.Warn("admin_seeding_user_not_found", zap.String("email", email))
				continue
			}
			return err
		}

		if !user.IsAdmin {
			if err := s.repo.SetAdminStatus(ctx, user.ID, true); err != nil {
				s.logger.Error("failed_to_promote_admin", zap.String("email", email), zap.Error(err))
				return err
			}
			s.logger.Info("promoted_user_to_admin", zap.String("email", email))
		} else {
			s.logger.Debug("user_already_admin", zap.String("email", email))
		}
	}
	return nil
}

// AdminBanUser applies a temporary or permanent ban to a user and revokes all active sessions.
func (s *Service) AdminBanUser(ctx context.Context, req AdminBanRequest) error {
	s.logger.Info("admin_ban_user_attempt",
		zap.String("user_id", req.UserID),
		zap.String("type", string(req.BanType)),
		zap.String("duration", req.Duration),
	)

	var restrictionsUntil *time.Time
	if req.BanType == BanTypeTemporary {
		if req.Duration == "" {
			return fmt.Errorf("duration is required for temporary bans")
		}
		duration, err := time.ParseDuration(req.Duration)
		if err != nil {
			return fmt.Errorf("invalid duration format: %v", err)
		}
		until := time.Now().Add(duration)
		restrictionsUntil = &until
	} else {
		// Permanent ban: set 100 years or 365 days? Let's use 100 years for "Permanent".
		until := time.Now().Add(100 * 365 * 24 * time.Hour)
		restrictionsUntil = &until
	}

	if err := s.repo.BanUser(ctx, req.UserID, restrictionsUntil, req.Reason); err != nil {
		s.logger.Error("failed_to_ban_user", zap.String("user_id", req.UserID), zap.Error(err))
		return err
	}

	// Revoke all sessions to force logout
	if err := s.repo.RevokeAllSessionsForUser(ctx, req.UserID, time.Now()); err != nil {
		s.logger.Warn("failed_to_revoke_sessions_after_ban", zap.String("user_id", req.UserID), zap.Error(err))
	}

	s.logger.Info("user_banned_successfully", zap.String("user_id", req.UserID))
	return nil
}

// FirebaseEmailAuth handles email authentication using Firebase ID token (Magic Link)
func (s *Service) FirebaseEmailAuth(ctx context.Context, req FirebaseEmailAuthRequest, ip string) (*LoginResponse, error) {
	if req.FirebaseIDToken == "" || req.DeviceID == "" {
		return nil, ErrInvalidCredentials
	}

	firebaseSender, ok := s.sms.(*FirebaseSMSSender)
	if !ok {
		return nil, fmt.Errorf("firebase authentication not enabled")
	}

	token, err := firebaseSender.VerifyIDToken(ctx, req.FirebaseIDToken)
	if err != nil {
		s.logger.Warn("firebase_token_verification_failed", zap.Error(err))
		return nil, ErrInvalidProviderToken
	}

	email, ok := token.Claims["email"].(string)
	if !ok || email == "" {
		return nil, fmt.Errorf("email not found in token")
	}

	// Verify if the email is marked as verified by Firebase
	emailVerified, _ := token.Claims["email_verified"].(bool)
	if !emailVerified {
		// Log warning, though magic links usually verify the email immediately
		s.logger.Warn("firebase_email_not_verified", zap.String("email", email))
	}

	email = normalizeEmail(email)
	if err := validateEmail(email); err != nil {
		return nil, err
	}

	s.logger.Info("firebase_email_auth_attempt",
		zap.String("email", email),
		zap.String("uid", token.UID),
	)

	user, err := s.repo.GetUserByEmail(ctx, email)
	if err != nil {
		if IsNotFound(err) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}
	if err := ensureUserCanAuthenticate(user); err != nil {
		return nil, err
	}

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

	access, refresh, _, err := s.jwt.IssueTokens(uuid.MustParse(user.ID), uuid.MustParse(session.ID))
	if err != nil {
		return nil, err
	}

	if err := s.repo.UpdateSessionsRefreshToken(ctx, session.ID, HashToken(refresh), now); err != nil {
		return nil, err
	}

	_ = s.repo.TouchUser(ctx, user.ID, now)

	if _, err := s.onSuccessfulLogin(ctx, user.ID); err != nil {
		s.logger.Warn("activation_login_tracking_failed", zap.String("user_id", user.ID), zap.Error(err))
	}

	s.logger.Info("firebase_email_auth_success", zap.String("user_id", user.ID))

	return &LoginResponse{
		AccessToken:  access,
		RefreshToken: refresh,
		User:         *user,
	}, nil
}

// FirebaseEmailRegister handles email registration using Firebase ID token (Magic Link)
func (s *Service) FirebaseEmailRegister(ctx context.Context, req FirebaseEmailRegisterRequest, ip string) (*LoginResponse, error) {
	observability.IncRegistrationAttempt("firebase_email")
	fail := func(reason string, err error) (*LoginResponse, error) {
		observability.IncRegistrationFailure("firebase_email", reason)
		return nil, err
	}

	if req.FirebaseIDToken == "" || req.FirstName == "" || req.LastName == "" || req.DateOfBirth == "" {
		return fail("invalid_credentials", ErrInvalidCredentials)
	}
	if err := verifyCaptchaToken(ctx, req.CaptchaToken, ip); err != nil {
		return fail("captcha_invalid", err)
	}

	firebaseSender, ok := s.sms.(*FirebaseSMSSender)
	if !ok {
		return fail("firebase_not_enabled", fmt.Errorf("firebase authentication not enabled"))
	}

	token, err := firebaseSender.VerifyIDToken(ctx, req.FirebaseIDToken)
	if err != nil {
		s.logger.Warn("firebase_token_verification_failed", zap.Error(err))
		return fail("invalid_provider_token", ErrInvalidProviderToken)
	}

	email, ok := token.Claims["email"].(string)
	if !ok || email == "" {
		return fail("email_missing", fmt.Errorf("email not found in token"))
	}

	email = normalizeEmail(email)
	if err := validateEmail(email); err != nil {
		return fail("invalid_email", err)
	}

	s.logger.Info("firebase_email_register_attempt",
		zap.String("email", email),
		zap.String("uid", token.UID),
	)

	if _, err := s.repo.GetUserByEmail(ctx, email); err == nil {
		return fail("email_exists", ErrEmailExists)
	} else if !IsNotFound(err) {
		return fail("db_error", err)
	}

	now := time.Now()
	dob, err := validateDateOfBirth(req.DateOfBirth, now)
	if err != nil {
		return fail("invalid_dob", err)
	}

	username, err := s.generateUniqueUsername(ctx, req.FirstName, req.LastName, &dob)
	if err != nil {
		return fail("username_generation_failed", err)
	}

	activationStatus, restrictionsUntil, err := s.resolveInitialActivation(ctx, req.DeviceID, ip)
	if err != nil {
		if err == ErrRegistrationRateLimited {
			s.logger.Warn("firebase_email_register_rate_limited", zap.String("ip", ip))
			return fail("rate_limited", err)
		}
		s.logger.Warn("initial_activation_resolution_failed", zap.Error(err))
		activationStatus = "restricted"
		restrictionsUntil = nil
	}

	user := &User{
		ID:               uuid.NewString(),
		Email:            email,
		Username:         username,
		FirstName:        req.FirstName,
		LastName:         req.LastName,
		DateOfBirth:      &dob,
		ReferralCode:     "",
		AvatarURL:        "",
		IsShadowBanned:   false,
		ActivationStatus: activationStatus,
		ActivationUnlockedAt: func() *time.Time {
			if activationStatus == "active" {
				t := now
				return &t
			}
			return nil
		}(),
		RestrictionsUntil: restrictionsUntil,
		CreatedAt:         now,
		UpdatedAt:         now,
		LastActiveAt:      now,
	}
	if err := s.repo.CreateUser(ctx, user); err != nil {
		return fail("create_user_failed", err)
	}

	if s.economyService != nil {
		if err := s.economyService.GrantSignupBonus(ctx, user.ID); err != nil {
			s.logger.Warn("signup_bonus_failed", zap.String("user_id", user.ID), zap.Error(err))
		}
	}

	if req.ReferrerUserID != "" {
		if err := s.economyService.ProcessReferralBonus(ctx, req.ReferrerUserID, user.ID); err != nil {
			s.logger.Warn("referral_bonus_failed",
				zap.String("referrer_user_id", req.ReferrerUserID),
				zap.String("referee_user_id", user.ID),
				zap.Error(err),
			)
		}
	}

	identity := &Identity{
		UserID:    user.ID,
		Provider:  string(ProviderEmail),
		Subject:   email,
		Email:     email,
		CreatedAt: now,
	}
	if err := s.repo.CreateIdentity(ctx, identity); err != nil {
		return fail("create_identity_failed", err)
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
		return fail("create_session_failed", err)
	}

	access, refresh, _, err := s.jwt.IssueTokens(uuid.MustParse(user.ID), uuid.MustParse(session.ID))
	if err != nil {
		return fail("issue_tokens_failed", err)
	}

	if err := s.repo.UpdateSessionsRefreshToken(ctx, session.ID, HashToken(refresh), now); err != nil {
		return fail("save_refresh_failed", err)
	}

	if _, err := s.onSuccessfulLogin(ctx, user.ID); err != nil {
		s.logger.Warn("activation_login_tracking_failed", zap.String("user_id", user.ID), zap.Error(err))
	}

	s.logger.Info("firebase_email_register_success", zap.String("user_id", user.ID))
	observability.IncRegistrationSuccess("firebase_email")

	return &LoginResponse{
		AccessToken:  access,
		RefreshToken: refresh,
		User:         *user,
	}, nil
}

func (s *Service) AdminLogin(ctx context.Context, req AdminLoginRequest, ip string) (*LoginResponse, error) {
	s.logger.Info("admin_login_attempt", zap.String("email", req.Email), zap.String("ip", ip))

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
	if !user.IsAdmin {
		return nil, ErrInvalidCredentials
	}
	if err := ensureUserCanAuthenticate(user); err != nil {
		return nil, err
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, ErrInvalidCredentials
	}

	session := &Session{
		ID:           uuid.NewString(),
		UserID:       user.ID,
		DeviceID:     "admin-spa",
		IP:           ip,
		UserAgent:    "admin-spa",
		AppVersion:   "admin",
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

	s.logger.Info("admin_login_success", zap.String("user_id", user.ID))
	return &LoginResponse{
		AccessToken:  access,
		RefreshToken: refresh,
		User:         *user,
	}, nil
}

func (s *Service) AdminGetUserByID(ctx context.Context, userID string) (*AdminUserResponse, error) {
	user, err := s.repo.GetUserByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	resp := AdminUserResponseFromUser(user)
	return &resp, nil
}

func (s *Service) AdminGetUserByEmail(ctx context.Context, email string) (*AdminUserResponse, error) {
	user, err := s.repo.GetUserByEmail(ctx, email)
	if err != nil {
		return nil, err
	}
	resp := AdminUserResponseFromUser(user)
	return &resp, nil
}
