package auth

import (
	"log"

	"github.com/gofiber/fiber/v2"
)

// третий слой логики

type Handler struct {
	service *Service
}

//конструктор хэндлера
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// Login godoc
// @Summary Login or register with OAuth provider
// @Description Authenticate with Apple or Google OAuth token
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body LoginRequest true "Login request"
// @Success 200 {object} LoginResponse
// @Failure 400 {object} fiber.Map
// @Failure 401 {object} fiber.Map
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
		default:
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "server_error"})
		}
	}

	return c.JSON(resp)
}

// RegisterEmail godoc
// @Summary Register with email and password
// @Description Create a new account with email, password, and personal details
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body EmailRegisterRequest true "Registration request"
// @Success 200 {object} LoginResponse
// @Failure 400 {object} fiber.Map
// @Failure 409 {object} fiber.Map "Email already exists"
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
		case ErrInvalidCredentials:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "missing_required_fields"})
		default:
			log.Printf("RegisterEmail unexpected error: %v", err)
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_registration"})
		}
	}
	return c.JSON(resp)
}

// LoginEmail godoc
// @Summary Login with email and password
// @Description Authenticate using email and password
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body EmailLoginRequest true "Login request"
// @Success 200 {object} LoginResponse
// @Failure 401 {object} fiber.Map
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
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid_credentials"})
	}
	return c.JSON(resp)
}

// RequestPhoneCode godoc
// @Summary Request phone verification code
// @Description Send SMS verification code to phone number for login or registration
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body PhoneCodeRequest true "Phone code request"
// @Success 200 {object} PhoneCodeResponse
// @Failure 400 {object} fiber.Map
// @Failure 404 {object} fiber.Map "User not found (login purpose)"
// @Failure 409 {object} fiber.Map "Phone already exists (register purpose)"
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

// VerifyPhoneCode godoc
// @Summary Verify phone code
// @Description Verify the SMS code and complete phone login
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body PhoneVerifyRequest true "Phone verification request"
// @Success 200 {object} PhoneVerifyResponse
// @Failure 400 {object} fiber.Map "Invalid or expired code"
// @Failure 404 {object} fiber.Map
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
		default:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_verification"})
		}
	}
	return c.JSON(resp)
}

// RegisterPhone godoc
// @Summary Complete phone registration
// @Description Complete registration after phone verification with personal details
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body PhoneRegisterRequest true "Phone registration request"
// @Success 200 {object} LoginResponse
// @Failure 400 {object} fiber.Map
// @Failure 409 {object} fiber.Map
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
// @Summary Refresh access token
// @Description Get a new access token using refresh token
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body RefreshRequest true "Refresh token request"
// @Success 200 {object} LoginResponse
// @Failure 401 {object} fiber.Map
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
// @Summary Logout
// @Description Revoke the current session and refresh token
// @Tags Auth
// @Accept json
// @Produce json
// @Security Bearer
// @Success 204
// @Failure 401 {object} fiber.Map
// @Failure 500 {object} fiber.Map
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
