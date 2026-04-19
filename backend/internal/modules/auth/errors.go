package auth

import "errors"

var (
	ErrInvalidProviderToken = errors.New("invalid_provider_token")
	ErrEmailRequired        = errors.New("email_required")
	ErrUserNotFound         = errors.New("user_not_found")
	ErrSessionNotFound      = errors.New("session_not_found")
	ErrInvalidRefresh       = errors.New("invalid_refresh")
	ErrAccountBlocked       = errors.New("account_blocked")

	ErrEmailExists        = errors.New("email_exists")
	ErrInvalidCredentials = errors.New("invalid_credentials")
	ErrWeakPassword       = errors.New("weak_password")
	ErrInvalidDateOfBirth = errors.New("invalid_date_of_birth")

	ErrPhoneExists           = errors.New("phone_exists")
	ErrInvalidPhone          = errors.New("invalid_phone")
	ErrInvalidCode           = errors.New("invalid_code")
	ErrVerificationExpired   = errors.New("verification_expired")
	ErrVerificationConsumed  = errors.New("verification_consumed")
	ErrVerificationNotReady  = errors.New("verification_not_ready")
	ErrInvalidPurpose        = errors.New("invalid_purpose")
)
