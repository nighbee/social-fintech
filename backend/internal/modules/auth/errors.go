package auth

import "errors"

//errors

var (
	ErrInvalidProviderToken = errors.New("invalid+provider_token")
	ErrEmailRequired = errors.New("email_required")
	ErrUserNotFound = errors.New("user_not_found")
	ErrSessionNotFound = errors.New("session_not_found")
)