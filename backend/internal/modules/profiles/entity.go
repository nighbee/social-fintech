package profiles

import "time"

// Profile represents a user's profile information
type Profile struct {
	UserID          string `db:"user_id" json:"user_id" example:"550e8400-e29b-41d4-a716-446655440000"`
	DisplayName     string `db:"display_name" json:"display_name" example:"Alice Wonderland"`
	FirstName       string `db:"first_name" json:"first_name" example:"Alice"`
	LastName        string `db:"last_name" json:"last_name" example:"Wonderland"`
	DateOfBirth     string `db:"date_of_birth" json:"date_of_birth" example:"2000-01-01"`
	Bio             string `db:"bio" json:"bio" example:"Explorer and adventurer"`
	AvatarURL       string `db:"avatar_url" json:"avatar_url" example:"https://storage.example.com/avatars/user123/avatar.jpg"`
	Country         string `db:"location_country" json:"country" example:"United States"`
	City            string `db:"location_city" json:"city" example:"San Francisco"`
	IsPublic        bool   `db:"is_profile_public" json:"is_public" example:"true"`
	ReputationScore int    `db:"reputation_score" json:"reputation_score" example:"100"`
	RankTier        string `db:"current_rank_tier" json:"rank_tier" example:"Quartz"`
	// FeedTimeLimitMins controls the Anti-Doomscroll ceiling.
	// 0 = No limit; 20/40/60 = limit in minutes. Defaults to 20.
	FeedTimeLimitMins int       `db:"feed_time_limit_mins" json:"feed_time_limit_mins" example:"20"`
	IsPatron          bool      `db:"is_patron" json:"is_patron" example:"true"`
	CreatedAt         time.Time `db:"created_at" json:"created_at" example:"2024-01-15T10:30:00Z"`
	UpdatedAt         time.Time `db:"updated_at" json:"updated_at" example:"2024-01-20T14:45:00Z"`
}

// UpdateProfileRequest represents profile update payload
// Uses pointers for optional fields to support partial updates (PATCH semantics)
// nil = don't update, empty string = clear field, value = update field
type UpdateProfileRequest struct {
	FirstName   *string `json:"first_name" example:"Alice"`
	LastName    *string `json:"last_name" example:"Wonderland"`
	DisplayName *string `json:"display_name" example:"Alice Wonderland"` // Combined name or custom display name
	Bio         *string `json:"bio" example:"Explorer and adventurer"`
	AvatarURL   *string `json:"avatar_url" example:"https://storage.example.com/avatar.jpg"`
	Country     *string `json:"country" example:"United States"`
	Region      *string `json:"region" example:"California"`
	City        *string `json:"city" example:"San Francisco"`
	IsPublic    *bool   `json:"is_public" example:"true"`
	// FeedTimeLimitMins: 0 = no limit, 20 / 40 / 60 = limit in minutes
	FeedTimeLimitMins *int   `json:"feed_time_limit_mins" example:"60"`
	ClientIP          string `json:"-"` // Not from JSON, set by handler
}

// PublicProfileResponse represents limited profile info for other users
type PublicProfileResponse struct {
	UserID          string `json:"user_id" example:"550e8400-e29b-41d4-a716-446655440000"`
	DisplayName     string `json:"display_name" example:"Alice Wonderland"`
	FirstName       string `json:"first_name" example:"Alice"`
	LastName        string `json:"last_name" example:"Wonderland"`
	Bio             string `json:"bio" example:"Explorer and adventurer"`
	AvatarURL       string `json:"avatar_url" example:"https://storage.example.com/avatar.jpg"`
	Country         string `json:"country" example:"United States"`
	City            string `json:"city" example:"San Francisco"`
	ReputationScore int    `json:"reputation_score" example:"100"`
	RankTier        string `json:"rank_tier" example:"Quartz"`
	IsPatron        bool   `json:"is_patron" example:"true"`
}

// ProfileStats represents user's economy statistics
type ProfileStats struct {
	UserID        string `json:"user_id" example:"550e8400-e29b-41d4-a716-446655440000"`
	SilverBalance int64  `json:"silver_balance" example:"12500"` // in centinels (125 Seals)
	GoldBalance   int64  `json:"gold_balance" example:"5000"`    // in centinels (50 Seals)
	TotalSent     int64  `json:"total_sent" example:"8000"`      // in centinels
	TotalReceived int64  `json:"total_received" example:"20000"` // in centinels
}

// AllyProfile represents a user in the Allies list
type AllyProfile struct {
	UserID          string `db:"user_id" json:"user_id"`
	DisplayName     string `db:"display_name" json:"display_name"`
	AvatarURL       string `db:"avatar_url" json:"avatar_url"`
	ReputationScore int    `db:"reputation_score" json:"reputation_score"`
	RankTier        string `json:"rank_tier"` // Computed
}

type ReportRequest struct {
	Reason      string `json:"reason" validate:"required,oneof=spam harassment inappropriate fake_account other" example:"spam"`
	Description string `json:"description" example:"Sent spam messages"`
}

// RelationshipStatus represents the relationship status between two users
type RelationshipStatus struct {
	UserID          string `json:"user_id" example:"550e8400-e29b-41d4-a716-446655440000"`
	IFollowThem     bool   `json:"i_follow_them" example:"true"`
	TheyFollowMe    bool   `json:"they_follow_me" example:"false"`
	IBlockedThem    bool   `json:"i_blocked_them" example:"false"`
	TheyBlockedMe   bool   `json:"they_blocked_me" example:"false"`
	IRestrictedThem bool   `json:"i_restricted_them" example:"false"`
}

// UserSearchResult — результат поиска реферера по имен/фамилии
type UserSearchResult struct {
	UserID          string `db:"user_id" json:"user_id" example:"550e8400-e29b-41d4-a716-446655440000"`
	Username        string `db:"username" json:"username" example:"john_doe"`
	FirstName       string `db:"first_name" json:"first_name" example:"John"`
	LastName        string `db:"last_name" json:"last_name" example:"Doe"`
	DisplayName     string `db:"display_name" json:"display_name" example:"John Doe"`
	AvatarURL       string `db:"avatar_url" json:"avatar_url" example:"https://storage.example.com/avatars/u1.jpg"`
	ReputationScore int    `db:"reputation_score" json:"reputation_score" example:"42"`
	RankTier        string `json:"rank_tier" example:"Moonstone | Intention | S"`
}

// ProfileSearchResult — результат поиска профилей для домашней ленты
type ProfileSearchResult struct {
	UserID          string `db:"user_id" json:"user_id" example:"550e8400-e29b-41d4-a716-446655440000"`
	DisplayName     string `db:"display_name" json:"display_name" example:"John Doe"`
	AvatarURL       string `db:"avatar_url" json:"avatar_url" example:"https://storage.example.com/avatars/u1.jpg"`
	ReputationScore int    `db:"reputation_score" json:"reputation_score" example:"100"`
	RankTier        string `json:"rank_tier" example:"Quartz"`
}
