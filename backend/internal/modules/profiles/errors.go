package profiles

import "errors"

var (
	ErrProfileNotFound       = errors.New("profile not found")
	ErrProfilePrivate        = errors.New("profile is private")
	ErrStorageNotConfigured  = errors.New("storage is not configured")
	ErrAvatarTooLarge        = errors.New("avatar file is too large")
	ErrInvalidAvatarMimeType = errors.New("invalid avatar content type")
	ErrDisplayNameTooLong    = errors.New("display_name too long (max 100 characters)")
	ErrFirstNameTooLong      = errors.New("first_name too long (max 50 characters)")
	ErrLastNameTooLong       = errors.New("last_name too long (max 50 characters)")
	ErrBioTooLong            = errors.New("bio too long (max 500 characters)")
)
