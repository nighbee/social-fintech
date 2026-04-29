package auth

import (
	"log"

	"github.com/gofiber/fiber/v2"
)

// третий слой логики

type Handler struct {
	service *Service
}

// конструктор хэндлера
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// Login godoc
// @Summary OAuth Login (Apple/Google)
// @Description Authenticate or register with Apple or Google OAuth. Auto-creates user if not exists.
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body LoginRequest true "OAuth login request"
// @Success 200 {object} LoginResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /auth/login [post]
func (h *Handler) Login(c *fiber.Ctx) error {
	var req LoginRequest

	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}
	if req.DeviceID == "" || req.ProviderToken == "" || req.ProviderType == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "missing_fields"})
	}

	if req.UserAgent == "" {
		req.UserAgent = c.Get("User-Agent")
	}
	if req.AppVersion == "" {
		req.AppVersion = c.Get("X-App-Version")
	}

	resp, err := h.service.Login(c.Context(), req, c.IP())
	if err != nil {
		switch err {
		case ErrInvalidProviderToken:
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid_provider_token"})
		case ErrEmailRequired:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "email_required"})
		case ErrAccountBlocked:
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "account_blocked"})
		case ErrRegistrationRateLimited:
			return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{"error": "registration_rate_limited"})
		default:
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "server_error"})
		}
	}

	return c.JSON(resp)
}

// RegisterEmail godoc
// @Summary Register with Email and Password
// @Description Create a new account with email, password, and personal details. Password min 8 chars.
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body EmailRegisterRequest true "Complete registration information"
// @Success 200 {object} LoginResponse
// @Failure 400 {object} ErrorResponse
// @Failure 409 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /auth/register-email [post]
func (h *Handler) RegisterEmail(c *fiber.Ctx) error {
	var req EmailRegisterRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}

	if req.UserAgent == "" {
		req.UserAgent = c.Get("User-Agent")
	}
	if req.AppVersion == "" {
		req.AppVersion = c.Get("X-App-Version")
	}

	resp, err := h.service.RegisterEmail(c.Context(), req, c.IP())
	if err != nil {
		switch err {
		case ErrEmailExists:
			return c.Status(fiber.StatusConflict).JSON(fiber.Map{"error": "email_exists"})
		case ErrWeakPassword:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "weak_password"})
		case ErrInvalidDateOfBirth:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_date_of_birth"})
		case ErrDateOfBirthTooOld:
			return c.Status(fiber.StatusUnprocessableEntity).JSON(fiber.Map{"error": "date_of_birth_too_old"})
		case ErrDateOfBirthTooYoung:
			return c.Status(fiber.StatusUnprocessableEntity).JSON(fiber.Map{"error": "date_of_birth_too_young"})
		case ErrRegistrationRateLimited:
			return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{"error": "registration_rate_limited"})
		case ErrCaptchaRequired:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "captcha_required"})
		case ErrCaptchaInvalid:
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "captcha_invalid"})
		case ErrInvalidCredentials:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_credentials", "message": "missing required fields"})
		default:
			// Log the actual error for debugging
			c.Context().Logger().Printf("RegisterEmail error: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "server_error", "message": err.Error()})
		}
	}
	return c.JSON(resp)
}

// LoginEmail godoc
// @Summary Login with Email and Password
// @Description Authenticate existing user with email and password credentials
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body EmailLoginRequest true "Email login credentials"
// @Success 200 {object} LoginResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /auth/login-email [post]
func (h *Handler) LoginEmail(c *fiber.Ctx) error {
	var req EmailLoginRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}

	if req.UserAgent == "" {
		req.UserAgent = c.Get("User-Agent")
	}
	if req.AppVersion == "" {
		req.AppVersion = c.Get("X-App-Version")
	}

	resp, err := h.service.LoginEmail(c.Context(), req, c.IP())
	if err != nil {
		switch err {
		case ErrInvalidCredentials:
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid_credentials"})
		case ErrAccountBlocked:
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "account_blocked"})
		default:
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "server_error", "message": err.Error()})
		}
	}
	return c.JSON(resp)
}

// CheckEmail godoc
// @Summary Check if Email Exists
// @Description Check if an email is already registered in the system
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body CheckEmailRequest true "Email to check"
// @Success 200 {object} CheckEmailResponse
// @Failure 400 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /auth/check-email [post]
func (h *Handler) CheckEmail(c *fiber.Ctx) error {
	var req CheckEmailRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}

	if req.Email == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "email_required"})
	}

	exists, err := h.service.CheckEmailExists(c.Context(), req.Email)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "server_error"})
	}

	return c.JSON(CheckEmailResponse{Exists: exists})
}

// RequestPhoneCode godoc
// @Summary Request Phone Verification Code
// @Description Send 4-digit SMS code. Purpose: login (phone must exist) or register (phone must not exist)
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body PhoneCodeRequest true "Phone number and purpose"
// @Success 200 {object} PhoneCodeResponse
// @Failure 400 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 409 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /auth/phone/request [post]
func (h *Handler) RequestPhoneCode(c *fiber.Ctx) error {
	var req PhoneCodeRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}

	resp, err := h.service.RequestPhoneCode(c.Context(), req)
	if err != nil {
		switch err {
		case ErrPhoneExists:
			return c.Status(fiber.StatusConflict).JSON(fiber.Map{"error": "phone_exists"})
		case ErrUserNotFound:
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "user_not_found"})
		default:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_phone_request"})
		}
	}
	return c.JSON(resp)
}

// RequestEmailCode godoc
// @Summary Request Email Verification Code
// @Description Send a 6-digit confirmation code to the supplied email address.
// @Description Purpose drives existence checks:
// @Description   register → email must NOT exist
// @Description   login | password_reset → email MUST exist
// @Description   email_change → no check (used after the user is already authenticated)
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body EmailCodeRequest true "Email and purpose"
// @Success 200 {object} EmailCodeResponse
// @Failure 400 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 409 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /auth/email/request [post]
func (h *Handler) RequestEmailCode(c *fiber.Ctx) error {
	var req EmailCodeRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}

	resp, err := h.service.RequestEmailCode(c.Context(), req)
	if err != nil {
		switch err {
		case ErrInvalidEmail:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_email"})
		case ErrInvalidPurpose:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_purpose"})
		case ErrEmailExists:
			return c.Status(fiber.StatusConflict).JSON(fiber.Map{"error": "email_exists"})
		case ErrUserNotFound:
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "user_not_found"})
		default:
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "email_request_failed"})
		}
	}
	return c.JSON(resp)
}

// VerifyEmailCode godoc
// @Summary Verify Email Code
// @Description Verify the 6-digit code returned to the user's inbox during the
// @Description email confirmation step. Returns the verification_id which higher
// @Description level flows (registration, password reset) reference to prove the
// @Description email is owned by the requester.
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body EmailVerifyRequest true "Verification ID and email code"
// @Success 200 {object} EmailVerifyResponse
// @Failure 400 {object} ErrorResponse
// @Router /auth/email/verify [post]
func (h *Handler) VerifyEmailCode(c *fiber.Ctx) error {
	var req EmailVerifyRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}

	resp, err := h.service.VerifyEmailCode(c.Context(), req)
	if err != nil {
		switch err {
		case ErrInvalidCode, ErrVerificationExpired, ErrVerificationConsumed:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_code"})
		default:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_verification"})
		}
	}
	return c.JSON(resp)
}

// VerifyPhoneCode godoc
// @Summary Verify Phone Code (Step 2)
// @Description Verify SMS code. Returns tokens for login, or verification_id for register flow
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body PhoneVerifyRequest true "Verification ID and SMS code"
// @Success 200 {object} PhoneVerifyResponse
// @Failure 400 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /auth/phone/verify [post]
func (h *Handler) VerifyPhoneCode(c *fiber.Ctx) error {
	var req PhoneVerifyRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}

	if req.UserAgent == "" {
		req.UserAgent = c.Get("User-Agent")
	}
	if req.AppVersion == "" {
		req.AppVersion = c.Get("X-App-Version")
	}

	resp, err := h.service.VerifyPhoneCode(c.Context(), req, c.IP())
	if err != nil {
		switch err {
		case ErrInvalidCode, ErrVerificationExpired, ErrVerificationConsumed:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_code"})
		case ErrUserNotFound:
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "user_not_found"})
		case ErrAccountBlocked:
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "account_blocked"})
		default:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_verification"})
		}
	}
	return c.JSON(resp)
}

// RegisterPhone godoc
// @Summary Complete Phone Registration (Step 3)
// @Description Complete registration with profile info after phone verification
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body PhoneRegisterRequest true "Profile info and verification ID"
// @Success 200 {object} LoginResponse
// @Failure 400 {object} ErrorResponse
// @Failure 409 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /auth/register-phone [post]
func (h *Handler) RegisterPhone(c *fiber.Ctx) error {
	var req PhoneRegisterRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}

	if req.UserAgent == "" {
		req.UserAgent = c.Get("User-Agent")
	}
	if req.AppVersion == "" {
		req.AppVersion = c.Get("X-App-Version")
	}

	resp, err := h.service.RegisterPhone(c.Context(), req, c.IP())
	if err != nil {
		switch err {
		case ErrPhoneExists:
			return c.Status(fiber.StatusConflict).JSON(fiber.Map{"error": "phone_exists"})
		case ErrInvalidDateOfBirth:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_date_of_birth"})
		case ErrDateOfBirthTooOld:
			return c.Status(fiber.StatusUnprocessableEntity).JSON(fiber.Map{"error": "date_of_birth_too_old"})
		case ErrDateOfBirthTooYoung:
			return c.Status(fiber.StatusUnprocessableEntity).JSON(fiber.Map{"error": "date_of_birth_too_young"})
		case ErrRegistrationRateLimited:
			return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{"error": "registration_rate_limited"})
		case ErrCaptchaRequired:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "captcha_required"})
		case ErrCaptchaInvalid:
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "captcha_invalid"})
		case ErrInvalidCredentials:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "missing_required_fields"})
		case ErrInvalidCode, ErrVerificationExpired, ErrVerificationConsumed:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_verification"})
		case ErrVerificationNotReady:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "verification_not_ready"})
		case ErrInvalidPurpose:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_purpose"})
		default:
			log.Printf("RegisterPhone unexpected error: %v", err)
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_registration"})
		}
	}
	return c.JSON(resp)
}

// Refresh godoc
// @Summary Refresh Access Token
// @Description Exchange refresh token for new access and refresh tokens (token rotation)
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body RefreshRequest true "Refresh token from login/register"
// @Success 200 {object} LoginResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /auth/refresh [post]
func (h *Handler) Refresh(c *fiber.Ctx) error {
	var req RefreshRequest
	if err := c.BodyParser(&req); err != nil || req.RefreshToken == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}

	resp, err := h.service.Refresh(c.Context(), req.RefreshToken)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid_refresh"})
	}

	return c.JSON(resp)
}

// Logout godoc
// @Summary Logout Current Session
// @Description Revoke current session and invalidate refresh token. Requires auth.
// @Tags Auth
// @Accept json
// @Produce json
// @Security Bearer
// @Success 204
// @Failure 401 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /auth/logout [post]
func (h *Handler) Logout(c *fiber.Ctx) error {
	sessionID, ok := c.Locals("session_id").(string)
	if !ok || sessionID == "" {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}

	if err := h.service.Logout(c.Context(), sessionID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "server_err"})
	}

	return c.SendStatus(fiber.StatusNoContent)
}

// FirebasePhoneAuth godoc
// @Summary Firebase Phone Authentication
// @Description Authenticate user with Firebase ID token from phone verification. For existing users.
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body FirebasePhoneAuthRequest true "Firebase ID token and device info"
// @Success 200 {object} LoginResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /auth/firebase-phone-login [post]
func (h *Handler) FirebasePhoneAuth(c *fiber.Ctx) error {
	var req FirebasePhoneAuthRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}

	if req.UserAgent == "" {
		req.UserAgent = c.Get("User-Agent")
	}
	if req.AppVersion == "" {
		req.AppVersion = c.Get("X-App-Version")
	}

	resp, err := h.service.FirebasePhoneAuth(c.Context(), req, c.IP())
	if err != nil {
		switch err {
		case ErrInvalidProviderToken:
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid_firebase_token"})
		case ErrUserNotFound:
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "user_not_found", "message": "Please register first"})
		case ErrInvalidCredentials:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "missing_required_fields"})
		case ErrAccountBlocked:
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "account_blocked"})
		default:
			log.Printf("FirebasePhoneAuth unexpected error: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "server_error"})
		}
	}
	return c.JSON(resp)
}

// FirebasePhoneRegister godoc
// @Summary Firebase Phone Registration
// @Description Register new user with Firebase ID token and profile information
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body FirebasePhoneRegisterRequest true "Firebase ID token and user profile"
// @Success 200 {object} LoginResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 409 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /auth/firebase-phone-register [post]
func (h *Handler) FirebasePhoneRegister(c *fiber.Ctx) error {
	var req FirebasePhoneRegisterRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}

	if req.UserAgent == "" {
		req.UserAgent = c.Get("User-Agent")
	}
	if req.AppVersion == "" {
		req.AppVersion = c.Get("X-App-Version")
	}

	resp, err := h.service.FirebasePhoneRegister(c.Context(), req, c.IP())
	if err != nil {
		switch err {
		case ErrInvalidProviderToken:
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid_firebase_token"})
		case ErrPhoneExists:
			return c.Status(fiber.StatusConflict).JSON(fiber.Map{"error": "phone_exists", "message": "User already exists, please login"})
		case ErrInvalidDateOfBirth:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_date_of_birth"})
		case ErrDateOfBirthTooOld:
			return c.Status(fiber.StatusUnprocessableEntity).JSON(fiber.Map{"error": "date_of_birth_too_old"})
		case ErrDateOfBirthTooYoung:
			return c.Status(fiber.StatusUnprocessableEntity).JSON(fiber.Map{"error": "date_of_birth_too_young"})
		case ErrRegistrationRateLimited:
			return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{"error": "registration_rate_limited"})
		case ErrCaptchaRequired:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "captcha_required"})
		case ErrCaptchaInvalid:
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "captcha_invalid"})
		case ErrInvalidCredentials:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "missing_required_fields"})
		default:
			log.Printf("FirebasePhoneRegister unexpected error: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "server_error"})
		}
	}
	return c.JSON(resp)
}

// AdminBanUser godoc
// @Summary Admin: Ban user
// @Description Ban a user temporarily or permanently (admin only)
// @Tags Auth Admin
// @Accept json
// @Produce json
// @Security Bearer
// @Param request body AdminBanRequest true "Ban details"
// @Success 204
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 403 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /auth/admin/ban [post]
func (h *Handler) AdminBanUser(c *fiber.Ctx) error {
	var req AdminBanRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}

	if err := h.service.AdminBanUser(c.Context(), req); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "ban_failed", "message": err.Error()})
	}

	return c.SendStatus(fiber.StatusNoContent)
}

// FirebaseEmailAuth godoc
// @Summary Firebase Email Authentication (Magic Link)
// @Description Authenticate user with Firebase ID token from email link verification. For existing users.
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body FirebaseEmailAuthRequest true "Firebase ID token and device info"
// @Success 200 {object} LoginResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /auth/firebase-email-login [post]
func (h *Handler) FirebaseEmailAuth(c *fiber.Ctx) error {
	var req FirebaseEmailAuthRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}

	if req.UserAgent == "" {
		req.UserAgent = c.Get("User-Agent")
	}
	if req.AppVersion == "" {
		req.AppVersion = c.Get("X-App-Version")
	}

	resp, err := h.service.FirebaseEmailAuth(c.Context(), req, c.IP())
	if err != nil {
		switch err {
		case ErrInvalidProviderToken:
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid_firebase_token"})
		case ErrUserNotFound:
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "user_not_found", "message": "Please register first"})
		case ErrInvalidCredentials:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "missing_required_fields"})
		case ErrAccountBlocked:
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "account_blocked"})
		case ErrInvalidEmailDomain:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_email_domain", "message": "Unsupported email provider domain"})
		case ErrInvalidEmail:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_email"})
		default:
			log.Printf("FirebaseEmailAuth unexpected error: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "server_error"})
		}
	}
	return c.JSON(resp)
}

// FirebaseEmailRegister godoc
// @Summary Firebase Email Registration (Magic Link)
// @Description Register new user with Firebase ID token (email link) and profile information
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body FirebaseEmailRegisterRequest true "Firebase ID token and user profile"
// @Success 200 {object} LoginResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 409 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /auth/firebase-email-register [post]
func (h *Handler) FirebaseEmailRegister(c *fiber.Ctx) error {
	var req FirebaseEmailRegisterRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}

	if req.UserAgent == "" {
		req.UserAgent = c.Get("User-Agent")
	}
	if req.AppVersion == "" {
		req.AppVersion = c.Get("X-App-Version")
	}

	resp, err := h.service.FirebaseEmailRegister(c.Context(), req, c.IP())
	if err != nil {
		switch err {
		case ErrInvalidProviderToken:
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid_firebase_token"})
		case ErrEmailExists:
			return c.Status(fiber.StatusConflict).JSON(fiber.Map{"error": "email_exists", "message": "User already exists, please login"})
		case ErrInvalidDateOfBirth:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_date_of_birth"})
		case ErrDateOfBirthTooOld:
			return c.Status(fiber.StatusUnprocessableEntity).JSON(fiber.Map{"error": "date_of_birth_too_old"})
		case ErrDateOfBirthTooYoung:
			return c.Status(fiber.StatusUnprocessableEntity).JSON(fiber.Map{"error": "date_of_birth_too_young"})
		case ErrRegistrationRateLimited:
			return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{"error": "registration_rate_limited"})
		case ErrCaptchaRequired:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "captcha_required"})
		case ErrCaptchaInvalid:
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "captcha_invalid"})
		case ErrInvalidCredentials:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "missing_required_fields"})
		case ErrInvalidEmailDomain:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_email_domain", "message": "Unsupported email provider domain"})
		case ErrInvalidEmail:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_email"})
		default:
			log.Printf("FirebaseEmailRegister unexpected error: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "server_error"})
		}
	}
	return c.JSON(resp)
}
