package settings

import "errors"

var (
	ErrInvalidFeedLimit           = errors.New("invalid_feed_limit")
	ErrInvalidPrivacyOption       = errors.New("invalid_privacy_option")
	ErrKeywordEmpty               = errors.New("keyword_empty")
	ErrPasswordTooWeak            = errors.New("password_too_weak")
	ErrInvalidCredentials         = errors.New("invalid_credentials")
	ErrTwoFAMinimumMethods        = errors.New("two_fa_minimum_methods")
	ErrInvalidTwoFAMethod         = errors.New("invalid_two_fa_method")
	ErrCannotDeleteCurrentSession = errors.New("cannot_delete_current_session")
	ErrDeleteRequestNotFound      = errors.New("delete_request_not_found")
	ErrDeleteVerificationExpired  = errors.New("delete_verification_expired")
	ErrDeleteVerificationInvalid  = errors.New("delete_verification_invalid")
	ErrDeleteReasonInvalid        = errors.New("delete_reason_invalid")
	ErrDescriptionRequired        = errors.New("description_required")
	ErrDescriptionTooLong         = errors.New("description_too_long")
	ErrRateLimited                = errors.New("rate_limited")

	ErrInvalidContactCategory = errors.New("invalid_contact_category")
	ErrMessageRequired        = errors.New("message_required")
	ErrMessageTooLong         = errors.New("message_too_long")
	ErrUsernameTaken          = errors.New("username_taken")
	ErrInvalidUsername        = errors.New("invalid_username")
	ErrUsernameTooLong        = errors.New("username_too_long")
)
