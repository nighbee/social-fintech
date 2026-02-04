package profiles

import "errors"

var (
	ErrProfileNotFound       = errors.New("profile not found")
	ErrProfilePrivate        = errors.New("profile is private")
	ErrStorageNotConfigured  = errors.New("storage is not configured")
	ErrAvatarTooLarge        = errors.New("avatar file is too large")
	ErrInvalidAvatarMimeType = errors.New("invalid avatar content type")
)
