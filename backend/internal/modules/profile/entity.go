package profile

import (
	"time"
)

// ==================== Constants ====================

// Relationship types for user-to-user interactions
const (
	RelationshipTypeAlly     RelationshipType = "ally"     // User follows/subscribes to target (allies per PRD)
	RelationshipTypeFavorite RelationshipType = "favorite" // User marked target as favorite
	RelationshipTypeBlock    RelationshipType = "block"    // User blocked target
	RelationshipTypeRestrict RelationshipType = "restrict" // User restricted target
)

// Report reasons for user moderation
const (
	ReportReasonSpam          ReportReason = "spam"
	ReportReasonHarassment    ReportReason = "harassment"
	ReportReasonInappropriate ReportReason = "inappropriate"
	ReportReasonFakeAccount   ReportReason = "fake_account"
	ReportReasonOther         ReportReason = "other"
)

// Report status for moderation workflow
const (
	ReportStatusPending   ReportStatus = "pending"
	ReportStatusReviewed  ReportStatus = "reviewed"
	ReportStatusDismissed ReportStatus = "dismissed"
	ReportStatusActioned  ReportStatus = "actioned"
)

// Rank tiers matching PRD gamification system
const (
	RankTierQuartz        = "Quartz" // Default starting rank
	RankTierClarity       = "Clarity"
	RankTierIntegrity     = "Integrity"
	RankTierAscendance    = "Ascendance"
	RankTierFortitude     = "Fortitude"
	RankTierTranscendence = "Transcendence"
	RankTierSovereign     = "Sovereign" // Final rank
)

type RelationshipType string
type ReportReason string
type ReportStatus string

// ==================== Core Entities ====================

// UserDetails represents user information from users table
type UserDetails struct {
	Username  string `db:"username" json:"username"`
	FirstName string `db:"first_name" json:"first_name"`
	LastName  string `db:"last_name" json:"last_name"`
}

// Profile represents extended user profile information (maps to profiles table)
type Profile struct {
	UserID      string  `db:"user_id" json:"user_id"`
	DisplayName *string `db:"display_name" json:"display_name,omitempty"` // Cached name for fast feed loading
	AvatarURL   *string `db:"avatar_url" json:"avatar_url,omitempty"`     // URL to MinIO/S3
	Bio         *string `db:"bio" json:"bio,omitempty"`

	// Location
	LocationCity     *string  `db:"location_city" json:"location_city,omitempty"`
	LocationCountry  *string  `db:"location_country" json:"location_country,omitempty"`
	LocationLat      *float64 `db:"location_lat" json:"-"` // Hidden from JSON for privacy
	LocationLon      *float64 `db:"location_lon" json:"-"` // Hidden from JSON for privacy
	IsLocationPublic bool     `db:"is_location_public" json:"is_location_public"`
	IsProfilePublic  bool     `db:"is_profile_public" json:"is_profile_public"`

	// Cached statistics (updated by workers, read-heavy optimization)
	TotalPosts             int   `db:"total_posts" json:"total_posts"`
	TotalGoldSealsReceived int64 `db:"total_gold_seals_received" json:"total_gold_seals_received"` // Status currency
	TotalSilverSealsGiven  int64 `db:"total_silver_seals_given" json:"total_silver_seals_given"`   // Generosity metric
	TasksCompleted         int   `db:"tasks_completed" json:"tasks_completed"`

	// Gamification / Ranks
	ReputationScore int    `db:"reputation_score" json:"reputation_score"`   // Numeric score for leaderboards
	CurrentRankTier string `db:"current_rank_tier" json:"current_rank_tier"` // 'Quartz', 'Clarity', ... 'Sovereign'

	CreatedAt time.Time `db:"created_at" json:"created_at"`
	UpdatedAt time.Time `db:"updated_at" json:"updated_at"`
}

// UserRelationship represents user-to-user relationships (maps to user_relationships table)
type UserRelationship struct {
	ID               string           `db:"id" json:"id"`
	UserID           string           `db:"user_id" json:"user_id"`                     // The "Follower" or initiator
	TargetUserID     string           `db:"target_user_id" json:"target_user_id"`       // The "Target" user
	RelationshipType RelationshipType `db:"relationship_type" json:"relationship_type"` // ally, favorite, block, restrict
	CreatedAt        time.Time        `db:"created_at" json:"created_at"`
}

// UserReport represents a report filed against a user (maps to user_reports table)
type UserReport struct {
	ID             string       `db:"id" json:"id"`
	ReporterID     string       `db:"reporter_id" json:"reporter_id"`
	ReportedUserID string       `db:"reported_user_id" json:"reported_user_id"`
	Reason         ReportReason `db:"reason" json:"reason"`
	Description    *string      `db:"description" json:"description,omitempty"`
	Status         ReportStatus `db:"status" json:"status"`
	CreatedAt      time.Time    `db:"created_at" json:"created_at"`
	ReviewedAt     *time.Time   `db:"reviewed_at" json:"reviewed_at,omitempty"`
	ReviewedBy     *string      `db:"reviewed_by" json:"reviewed_by,omitempty"`
}

// ==================== Response DTOs ====================

// ProfileStats represents aggregated profile statistics
type ProfileStats struct {
	TotalPosts             int   `json:"total_posts"`
	TotalGoldSealsReceived int64 `json:"total_gold_seals_received"` // Status currency received
	TotalSilverSealsGiven  int64 `json:"total_silver_seals_given"`  // Support/generosity given
	TasksCompleted         int   `json:"tasks_completed"`
	ReputationScore        int   `json:"reputation_score"` // Overall reputation score
}

// ProfileResponse is the full profile response returned by API
type ProfileResponse struct {
	// User Details (Nested to match Auth response structure)
	User UserDetails `json:"user"`

	// From users table (ID Only at root if needed, or rely on User object)
	UserID string `json:"user_id"` // Keep for backward compat if needed, or remove? Keeping for safety.

	DisplayName *string `json:"display_name,omitempty"` // Cached display name
	AvatarURL   string  `json:"avatar_url"`

	// From profiles table
	Bio      *string `json:"bio,omitempty"`
	Location *string `json:"location,omitempty"` // "City, Country" formatted

	// Privacy settings
	IsLocationPublic bool `json:"is_location_public"`
	IsProfilePublic  bool `json:"is_profile_public"`

	// Statistics - CRITICAL: NO follower/subscriber counts shown per PRD
	Stats ProfileStats `json:"stats"`

	// Ranking (from profiles table + gamification module)
	CurrentRankTier string `json:"current_rank_tier"`       // e.g., "Quartz", "Clarity", "Sovereign"
	ReputationScore int    `json:"reputation_score"`        // Numeric score for leaderboards
	RankProgress    *int   `json:"rank_progress,omitempty"` // Progress to next rank (0-100)

	// Economy (from economy module wallets)
	SilverSeals *int64 `json:"silver_seals,omitempty"` // Current support/help currency balance
	GoldSeals   *int64 `json:"gold_seals,omitempty"`   // Status/dignity marker (shown in profile per PRD)

	// Leaderboard position (from leaderboard module - optional)
	LeaderboardRank       *int `json:"leaderboard_rank,omitempty"`        // Position in regional leaderboard
	LocalLeaderboardRank  *int `json:"local_leaderboard_rank,omitempty"`  // Position in local leaderboard
	GlobalLeaderboardRank *int `json:"global_leaderboard_rank,omitempty"` // Position in global leaderboard

	// Donor status (from economy module seasons)
	IsActiveDonor      bool   `json:"is_active_donor"`                // Public badge for donors
	CurrentSeasonSeals *int64 `json:"current_season_seals,omitempty"` // Seals donated this season

	// Relationship context (when viewing other profiles)
	IsAlly     bool `json:"is_ally"`     // Viewer follows this profile (subscribed as ally)
	IsFavorite bool `json:"is_favorite"` // Viewer favorited this profile
	IsBlocked  bool `json:"is_blocked"`  // Viewer blocked this profile
	IsOwn      bool `json:"is_own"`      // This is the viewer's own profile

	CreatedAt time.Time `json:"created_at"`
}

// RelationshipResponse is returned when creating/listing relationships
type RelationshipResponse struct {
	ID                string           `json:"id"`
	TargetUserID      string           `json:"target_user_id"`
	TargetUsername    string           `json:"target_username"`
	TargetDisplayName *string          `json:"target_display_name,omitempty"`
	TargetAvatarURL   string           `json:"target_avatar_url"`
	RelationshipType  RelationshipType `json:"relationship_type"`
	CreatedAt         time.Time        `json:"created_at"`
}

// AlliesListResponse is returned when fetching allies (people user follows)
type AlliesListResponse struct {
	Allies []RelationshipResponse `json:"allies"`
	Total  int                    `json:"total"`
	Page   int                    `json:"page"`
	Limit  int                    `json:"limit"`
}

// FavoritesListResponse is returned when fetching favorites
type FavoritesListResponse struct {
	Favorites []RelationshipResponse `json:"favorites"`
	Total     int                    `json:"total"`
	Page      int                    `json:"page"`
	Limit     int                    `json:"limit"`
}

// ReportResponse is returned after filing a report
type ReportResponse struct {
	ID        string    `json:"id"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
	Message   string    `json:"message" example:"Report submitted successfully. Our team will review it."`
}

// ShareProfileResponse contains the shareable profile URL
type ShareProfileResponse struct {
	URL      string `json:"url" example:"https://app.brightbund.com/@username"`
	Username string `json:"username" example:"johndoe"`
}

// ProfileSearchResult represents a single search result
type ProfileSearchResult struct {
	UserID          string  `json:"user_id"`
	Username        string  `json:"username"`
	DisplayName     *string `json:"display_name,omitempty"`
	FirstName       string  `json:"first_name"`
	LastName        string  `json:"last_name"`
	AvatarURL       string  `json:"avatar_url"`
	Location        string  `json:"location,omitempty"`
	CurrentRankTier string  `json:"current_rank_tier"`
	ReputationScore int     `json:"reputation_score"`
}

// ProfileSearchResponse contains search results
type ProfileSearchResponse struct {
	Results []ProfileSearchResult `json:"results"`
	Total   int                   `json:"total"`
	Page    int                   `json:"page"`
	Limit   int                   `json:"limit"`
}

// ==================== Request DTOs ====================

// UpdateProfileRequest is the request body for updating profile
type UpdateProfileRequest struct {
	DisplayName      *string `json:"display_name,omitempty" example:"John Doe"`
	FirstName        *string `json:"first_name,omitempty" example:"John"`
	LastName         *string `json:"last_name,omitempty" example:"Doe"`
	Bio              *string `json:"bio,omitempty" example:"Love exploring the world"`
	LocationCity     *string `json:"location_city,omitempty" example:"San Francisco"`
	LocationCountry  *string `json:"location_country,omitempty" example:"USA"`
	IsLocationPublic *bool   `json:"is_location_public,omitempty" example:"true"`
	IsProfilePublic  *bool   `json:"is_profile_public,omitempty" example:"true"`
}

// UploadAvatarResponse is returned after avatar upload
type UploadAvatarResponse struct {
	AvatarURL string `json:"avatar_url" example:"https://storage.example.com/avatars/uuid.jpg"`
}

// CreateRelationshipRequest is the request to create a user relationship
type CreateRelationshipRequest struct {
	TargetUserID     string           `json:"target_user_id" example:"550e8400-e29b-41d4-a716-446655440000"`
	RelationshipType RelationshipType `json:"relationship_type" example:"ally"` // ally, favorite, block, restrict
}

// RemoveRelationshipRequest is the request to remove a user relationship
type RemoveRelationshipRequest struct {
	TargetUserID     string           `json:"target_user_id" example:"550e8400-e29b-41d4-a716-446655440000"`
	RelationshipType RelationshipType `json:"relationship_type" example:"ally"` // ally, favorite, block, restrict
}

// ReportUserRequest is the request to report a user
type ReportUserRequest struct {
	ReportedUserID string       `json:"reported_user_id" example:"550e8400-e29b-41d4-a716-446655440000"`
	Reason         ReportReason `json:"reason" example:"spam"`
	Description    *string      `json:"description,omitempty" example:"This user is spamming inappropriate content"`
}

// ==================== Helper Methods ====================

// IsValidRelationshipType checks if relationship type is valid
func (rt RelationshipType) IsValid() bool {
	switch rt {
	case RelationshipTypeAlly, RelationshipTypeFavorite, RelationshipTypeBlock, RelationshipTypeRestrict:
		return true
	}
	return false
}

// IsValidReportReason checks if report reason is valid
func (rr ReportReason) IsValid() bool {
	switch rr {
	case ReportReasonSpam, ReportReasonHarassment, ReportReasonInappropriate,
		ReportReasonFakeAccount, ReportReasonOther:
		return true
	}
	return false
}

// IsValidReportStatus checks if report status is valid
func (rs ReportStatus) IsValid() bool {
	switch rs {
	case ReportStatusPending, ReportStatusReviewed, ReportStatusDismissed, ReportStatusActioned:
		return true
	}
	return false
}

// IsValidRankTier checks if rank tier is valid
func IsValidRankTier(tier string) bool {
	switch tier {
	case RankTierQuartz, RankTierClarity, RankTierIntegrity, RankTierAscendance,
		RankTierFortitude, RankTierTranscendence, RankTierSovereign:
		return true
	}
	return false
}

// GetLocationString formats location as "City, Country"
func (p *Profile) GetLocationString() *string {
	if p.LocationCity != nil && p.LocationCountry != nil {
		location := *p.LocationCity + ", " + *p.LocationCountry
		return &location
	}
	if p.LocationCity != nil {
		return p.LocationCity
	}
	if p.LocationCountry != nil {
		return p.LocationCountry
	}
	return nil
}

// HasLocation checks if profile has GPS coordinates
func (p *Profile) HasLocation() bool {
	return p.LocationLat != nil && p.LocationLon != nil
}

// IsPublicProfile checks if profile is visible to others
func (p *Profile) IsPublicProfile() bool {
	return p.IsProfilePublic
}

// CanShowLocation checks if location should be shown
func (p *Profile) CanShowLocation() bool {
	return p.IsLocationPublic && p.HasLocation()
}
