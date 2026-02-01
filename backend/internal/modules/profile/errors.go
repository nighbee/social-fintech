package profile

import (
	"errors"
	"fmt"
	"time"
)

// ==================== Profile Errors ====================

var (
	// Profile CRUD errors
	ErrProfileNotFound     = errors.New("profile not found")
	ErrProfileExists       = errors.New("profile already exists")
	ErrProfileUpdateFailed = errors.New("failed to update profile")
	ErrProfileCreateFailed = errors.New("failed to create profile")

	// User errors
	ErrUserNotFound = errors.New("user not found")
	ErrUserBlocked  = errors.New("user is blocked")
	ErrSelfAction   = errors.New("cannot perform this action on yourself")

	// Profile visibility and privacy errors
	ErrProfilePrivate          = errors.New("profile is private")
	ErrProfileNotPublic        = errors.New("profile is not public")
	ErrUnauthorizedAccess      = errors.New("unauthorized to access this profile")
	ErrInsufficientPermissions = errors.New("insufficient permissions")
)

// ==================== Relationship Errors ====================

var (
	// Relationship CRUD errors
	ErrRelationshipNotFound     = errors.New("relationship not found")
	ErrRelationshipExists       = errors.New("relationship already exists")
	ErrRelationshipCreateFailed = errors.New("failed to create relationship")
	ErrRelationshipDeleteFailed = errors.New("failed to delete relationship")

	// Relationship validation errors
	ErrInvalidRelationshipType = errors.New("invalid relationship type")
	ErrCannotRelateToSelf      = errors.New("cannot create relationship with yourself")
	ErrRelationshipConflict    = errors.New("conflicting relationship exists")

	// Blocking and restriction errors
	ErrUserBlockedBy    = errors.New("you are blocked by this user")
	ErrUserRestrictedBy = errors.New("you are restricted by this user")
	ErrTargetBlocked    = errors.New("target user is blocked")
	ErrTargetRestricted = errors.New("target user is restricted")

	// Ally/Follow errors
	ErrAlreadyAlly      = errors.New("already following this user")
	ErrNotAlly          = errors.New("not following this user")
	ErrAllyLimitReached = errors.New("ally limit reached")

	// Favorite errors
	ErrAlreadyFavorite = errors.New("user already in favorites")
	ErrNotFavorite     = errors.New("user not in favorites")
)

// ==================== Report Errors ====================

var (
	// Report CRUD errors
	ErrReportNotFound     = errors.New("report not found")
	ErrReportCreateFailed = errors.New("failed to create report")
	ErrReportUpdateFailed = errors.New("failed to update report")

	// Report validation errors
	ErrInvalidReportReason       = errors.New("invalid report reason")
	ErrReportDescriptionRequired = errors.New("report description is required for this reason")
	ErrReportAlreadyExists       = errors.New("you have already reported this user")
	ErrCannotReportSelf          = errors.New("cannot report yourself")

	// Report status errors
	ErrInvalidReportStatus   = errors.New("invalid report status")
	ErrReportAlreadyReviewed = errors.New("report has already been reviewed")
	ErrReportNotPending      = errors.New("report is not in pending state")
)

// ==================== Validation Errors ====================

var (
	// Field validation errors
	ErrInvalidBio          = errors.New("bio exceeds maximum length")
	ErrInvalidLocation     = errors.New("invalid location data")
	ErrInvalidDisplayName  = errors.New("invalid display name")
	ErrDisplayNameTooShort = errors.New("display name too short")
	ErrDisplayNameTooLong  = errors.New("display name too long")
	ErrInvalidCoordinates  = errors.New("invalid GPS coordinates")

	// Avatar/Upload errors
	ErrAvatarUploadFailed  = errors.New("failed to upload avatar")
	ErrInvalidAvatarFormat = errors.New("invalid avatar format")
	ErrAvatarTooLarge      = errors.New("avatar file size exceeds limit")
	ErrAvatarRequired      = errors.New("avatar is required")

	// Username/Search errors
	ErrInvalidUsername     = errors.New("invalid username")
	ErrUsernameNotFound    = errors.New("username not found")
	ErrInvalidSearchQuery  = errors.New("invalid search query")
	ErrSearchQueryTooShort = errors.New("search query too short")
)

// ==================== Rank/Gamification Errors ====================

var (
	// Rank errors
	ErrInvalidRankTier   = errors.New("invalid rank tier")
	ErrRankUpdateFailed  = errors.New("failed to update rank")
	ErrInvalidReputation = errors.New("invalid reputation score")
	ErrReputationTooLow  = errors.New("reputation score too low")

	// Stats errors
	ErrStatsNotFound     = errors.New("profile stats not found")
	ErrStatsUpdateFailed = errors.New("failed to update profile stats")
	ErrInvalidStatsValue = errors.New("invalid stats value")
)

// ==================== Rate Limiting Errors ====================

var (
	// Rate limiting
	ErrTooManyRequests        = errors.New("too many requests")
	ErrRelationshipRateLimit  = errors.New("relationship creation rate limit exceeded")
	ErrReportRateLimit        = errors.New("report submission rate limit exceeded")
	ErrProfileUpdateRateLimit = errors.New("profile update rate limit exceeded")
)

// ==================== Error Helper Functions ====================

// NewCooldownError creates a cooldown error with remaining time
func NewCooldownError(action string, remainingTime time.Duration) error {
	return fmt.Errorf("cooldown active for %s: %v remaining", action, remainingTime)
}

// NewRateLimitError creates a rate limit error with retry time
func NewRateLimitError(action string, retryAfter time.Duration) error {
	return fmt.Errorf("rate limit exceeded for %s: retry after %v", action, retryAfter)
}

// NewBlockedByError creates a detailed blocked error
func NewBlockedByError(username string) error {
	return fmt.Errorf("you are blocked by user: %s", username)
}

// NewRelationshipExistsError creates a detailed relationship exists error
func NewRelationshipExistsError(relationshipType string) error {
	return fmt.Errorf("relationship of type %s already exists", relationshipType)
}

// IsNotFoundError checks if error is a not-found type error
func IsNotFoundError(err error) bool {
	return errors.Is(err, ErrProfileNotFound) ||
		errors.Is(err, ErrUserNotFound) ||
		errors.Is(err, ErrRelationshipNotFound) ||
		errors.Is(err, ErrReportNotFound) ||
		errors.Is(err, ErrStatsNotFound) ||
		errors.Is(err, ErrUsernameNotFound)
}

// IsValidationError checks if error is a validation type error
func IsValidationError(err error) bool {
	return errors.Is(err, ErrInvalidBio) ||
		errors.Is(err, ErrInvalidLocation) ||
		errors.Is(err, ErrInvalidDisplayName) ||
		errors.Is(err, ErrDisplayNameTooShort) ||
		errors.Is(err, ErrDisplayNameTooLong) ||
		errors.Is(err, ErrInvalidCoordinates) ||
		errors.Is(err, ErrInvalidUsername) ||
		errors.Is(err, ErrInvalidRelationshipType) ||
		errors.Is(err, ErrCannotRelateToSelf) ||
		errors.Is(err, ErrInvalidReportReason) ||
		errors.Is(err, ErrInvalidRankTier) ||
		errors.Is(err, ErrInvalidStatsValue)
}

// IsPermissionError checks if error is a permission type error
func IsPermissionError(err error) bool {
	return errors.Is(err, ErrUnauthorizedAccess) ||
		errors.Is(err, ErrInsufficientPermissions) ||
		errors.Is(err, ErrProfilePrivate) ||
		errors.Is(err, ErrProfileNotPublic) ||
		errors.Is(err, ErrUserBlocked) ||
		errors.Is(err, ErrUserBlockedBy) ||
		errors.Is(err, ErrUserRestrictedBy) ||
		errors.Is(err, ErrTargetBlocked) ||
		errors.Is(err, ErrTargetRestricted)
}

// IsRateLimitError checks if error is a rate limiting type error
func IsRateLimitError(err error) bool {
	return errors.Is(err, ErrTooManyRequests) ||
		errors.Is(err, ErrRelationshipRateLimit) ||
		errors.Is(err, ErrReportRateLimit) ||
		errors.Is(err, ErrProfileUpdateRateLimit)
}

// IsConflictError checks if error is a conflict type error
func IsConflictError(err error) bool {
	return errors.Is(err, ErrProfileExists) ||
		errors.Is(err, ErrRelationshipExists) ||
		errors.Is(err, ErrRelationshipConflict) ||
		errors.Is(err, ErrReportAlreadyExists) ||
		errors.Is(err, ErrAlreadyAlly) ||
		errors.Is(err, ErrAlreadyFavorite)
}
