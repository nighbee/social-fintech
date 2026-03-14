package settings

import (
	"errors"
	"strings"

	"github.com/gofiber/fiber/v2"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func getUserAndSession(c *fiber.Ctx) (string, string, error) {
	userID, ok := c.Locals("user_id").(string)
	if !ok || userID == "" {
		return "", "", errors.New("unauthorized")
	}
	sessionID, _ := c.Locals("session_id").(string)
	return userID, sessionID, nil
}

func (h *Handler) GetSecurity(c *fiber.Ctx) error {
	userID, sessionID, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	resp, err := h.service.GetSecurityOverview(c.Context(), userID, sessionID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "security_fetch_failed"})
	}
	return c.JSON(resp)
}

func (h *Handler) ChangePassword(c *fiber.Ctx) error {
	userID, sessionID, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	var req ChangePasswordRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}
	err = h.service.ChangePassword(c.Context(), userID, sessionID, req.CurrentPassword, req.NewPassword)
	if err != nil {
		switch err {
		case ErrPasswordTooWeak:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "weak_password"})
		case ErrInvalidCredentials:
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid_credentials"})
		default:
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "password_change_failed"})
		}
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *Handler) GetTwoFA(c *fiber.Ctx) error {
	userID, _, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	resp, err := h.service.GetTwoFAStatus(c.Context(), userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "two_fa_fetch_failed"})
	}
	return c.JSON(resp)
}

func (h *Handler) EnableTwoFA(c *fiber.Ctx) error {
	userID, _, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	var req TwoFAEnableRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}
	resp, err := h.service.EnableTwoFA(c.Context(), userID, req.Methods)
	if err != nil {
		switch err {
		case ErrInvalidTwoFAMethod:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_two_fa_method"})
		case ErrTwoFAMinimumMethods:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "min_two_methods_required"})
		default:
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "two_fa_enable_failed"})
		}
	}
	return c.JSON(resp)
}

func (h *Handler) DisableTwoFA(c *fiber.Ctx) error {
	userID, _, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	var req TwoFADisableRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}
	if err := h.service.DisableTwoFA(c.Context(), userID, req.CurrentPassword); err != nil {
		if err == ErrInvalidCredentials {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid_credentials"})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "two_fa_disable_failed"})
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *Handler) GetSessions(c *fiber.Ctx) error {
	userID, sessionID, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	items, err := h.service.ListSessions(c.Context(), userID, sessionID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "sessions_fetch_failed"})
	}
	return c.JSON(items)
}

func (h *Handler) DeleteSession(c *fiber.Ctx) error {
	userID, currentSessionID, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	targetSessionID := c.Params("id")
	if targetSessionID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_session_id"})
	}
	if err := h.service.RevokeSession(c.Context(), userID, currentSessionID, targetSessionID); err != nil {
		if err == ErrCannotDeleteCurrentSession {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "cannot_delete_current_session"})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "session_delete_failed"})
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *Handler) DeleteAllSessions(c *fiber.Ctx) error {
	userID, currentSessionID, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	if err := h.service.RevokeAllSessionsExceptCurrent(c.Context(), userID, currentSessionID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "sessions_delete_failed"})
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *Handler) DeleteAccountReason(c *fiber.Ctx) error {
	userID, _, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	var req DeleteAccountReasonRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}
	resp, err := h.service.DeleteAccountReason(c.Context(), userID, req.Reason)
	if err != nil {
		if err == ErrDeleteReasonInvalid {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_reason"})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "delete_reason_failed"})
	}
	return c.JSON(resp)
}

func (h *Handler) DeleteAccountVerify(c *fiber.Ctx) error {
	userID, _, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	var req DeleteAccountVerifyRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}
	resp, err := h.service.DeleteAccountVerify(c.Context(), userID, &req)
	if err != nil {
		switch err {
		case ErrDeleteRequestNotFound:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "delete_request_not_found"})
		case ErrInvalidCredentials:
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid_credentials"})
		default:
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "delete_verify_failed"})
		}
	}
	return c.JSON(resp)
}

func (h *Handler) DeleteAccountFinalize(c *fiber.Ctx) error {
	userID, _, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	var req DeleteAccountFinalizeRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}
	if err := h.service.DeleteAccountFinalize(c.Context(), userID, req.VerificationToken); err != nil {
		switch err {
		case ErrDeleteVerificationInvalid:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "delete_verification_invalid"})
		case ErrDeleteVerificationExpired:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "delete_verification_expired"})
		default:
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "delete_finalize_failed"})
		}
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *Handler) GetFeedSettings(c *fiber.Ctx) error {
	userID, _, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	resp, err := h.service.GetFeedSettings(c.Context(), userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "feed_settings_fetch_failed"})
	}
	return c.JSON(resp)
}

func (h *Handler) PatchFeedSettings(c *fiber.Ctx) error {
	userID, _, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	var req PatchFeedSettingsRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}
	if err := h.service.PatchFeedSettings(c.Context(), userID, req.NewLimitMins); err != nil {
		if err == ErrInvalidFeedLimit {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_feed_limit"})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "feed_settings_update_failed"})
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *Handler) GetInteractions(c *fiber.Ctx) error {
	userID, _, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	resp, err := h.service.GetInteractions(c.Context(), userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "interactions_fetch_failed"})
	}
	return c.JSON(resp)
}

func (h *Handler) GetMessagesSettings(c *fiber.Ctx) error {
	userID, _, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	resp, err := h.service.GetMessagesSettings(c.Context(), userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "messages_settings_fetch_failed"})
	}
	return c.JSON(resp)
}

func (h *Handler) PatchMessagesSettings(c *fiber.Ctx) error {
	userID, _, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	var req PatchMessagesSettingsRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}
	if err := h.service.PatchMessagesSettings(c.Context(), userID, &req); err != nil {
		if err == ErrInvalidPrivacyOption {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_privacy_option"})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "messages_settings_update_failed"})
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *Handler) AddMessageKeyword(c *fiber.Ctx) error {
	userID, _, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	var req AddKeywordRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}
	id, err := h.service.AddMessageKeyword(c.Context(), userID, req.Keyword)
	if err != nil {
		if err == ErrKeywordEmpty {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "keyword_empty"})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "keyword_add_failed"})
	}
	return c.Status(fiber.StatusCreated).JSON(fiber.Map{"id": id})
}

func (h *Handler) DeleteMessageKeyword(c *fiber.Ctx) error {
	userID, _, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	if err := h.service.DeleteMessageKeyword(c.Context(), userID, c.Params("id")); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "keyword_delete_failed"})
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *Handler) GetCommentsSettings(c *fiber.Ctx) error {
	userID, _, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	resp, err := h.service.GetCommentsSettings(c.Context(), userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "comments_settings_fetch_failed"})
	}
	return c.JSON(resp)
}

func (h *Handler) PatchCommentsSettings(c *fiber.Ctx) error {
	userID, _, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	var req PatchCommentsSettingsRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}
	if err := h.service.PatchCommentsSettings(c.Context(), userID, &req); err != nil {
		if err == ErrInvalidPrivacyOption {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_privacy_option"})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "comments_settings_update_failed"})
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *Handler) GetMentionsSettings(c *fiber.Ctx) error {
	userID, _, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	resp, err := h.service.GetMentionsSettings(c.Context(), userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "mentions_settings_fetch_failed"})
	}
	return c.JSON(resp)
}

func (h *Handler) PatchMentionsSettings(c *fiber.Ctx) error {
	userID, _, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	var req PatchMentionsSettingsRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
	}
	if err := h.service.PatchMentionsSettings(c.Context(), userID, &req); err != nil {
		if err == ErrInvalidPrivacyOption {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_privacy_option"})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "mentions_settings_update_failed"})
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *Handler) GetBlockedUsers(c *fiber.Ctx) error {
	userID, _, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	cursor := c.Query("cursor")
	limit := c.QueryInt("limit", 20)
	resp, err := h.service.ListBlockedUsers(c.Context(), userID, cursor, limit)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "blocked_fetch_failed"})
	}
	return c.JSON(resp)
}

func (h *Handler) UnblockUser(c *fiber.Ctx) error {
	userID, _, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	target := c.Params("userId")
	if target == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_user_id"})
	}
	if err := h.service.UnblockUser(c.Context(), userID, target); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "unblock_failed"})
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *Handler) ReportBug(c *fiber.Ctx) error {
	userID, _, err := getUserAndSession(c)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}
	var req BugReportRequest
	ct := strings.ToLower(c.Get("Content-Type"))
	if strings.Contains(ct, "multipart/form-data") {
		req.Description = c.FormValue("description")
		req.AppVersion = c.FormValue("app_version")
		req.DeviceOS = c.FormValue("device_os")
		if file, ferr := c.FormFile("screenshot"); ferr == nil && file != nil {
			req.Screenshot = file.Filename
		}
	} else {
		if err := c.BodyParser(&req); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
		}
	}
	if err := h.service.CreateBugReport(c.Context(), userID, &req); err != nil {
		switch err {
		case ErrDescriptionRequired:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "description_required"})
		case ErrDescriptionTooLong:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "description_too_long"})
		default:
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "bug_report_failed"})
		}
	}
	return c.SendStatus(fiber.StatusCreated)
}
