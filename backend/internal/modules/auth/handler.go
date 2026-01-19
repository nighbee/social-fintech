package auth

import "github.com/gofiber/fiber/v2"

// третий слой логики

type Handler struct {
	service *Service
}

//конструктор хэндлера
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// логин пост запрос на /auth/login 
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

// /auth/register-email post
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
		default:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_registration"})
		}
	}
	return c.JSON(resp)
}

// /auth/login-email post
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

// /auth/phone/request post 
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

// /auth/phone/verify post
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


// /auth/register-phone post
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
		default:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_registration"})
		}
	}
	return c.JSON(resp)
}

// /auth/refresh post
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


// /auth/logout post
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
