package profiles

import "time"

// Profile represents a user's profile information
type Profile struct {
	UserID      string    `db:"user_id" json:"user_id" example:"550e8400-e29b-41d4-a716-446655440000"`
	DisplayName string    `db:"display_name" json:"display_name" example:"Alice Wonderland"`
	FirstName   string    `json:"first_name" example:"Alice"`     // Computed field, not in DB
	LastName    string    `json:"last_name" example:"Wonderland"` // Computed field, not in DB
	Bio         string    `db:"bio" json:"bio" example:"Explorer and adventurer"`
	AvatarURL   string    `db:"avatar_url" json:"avatar_url" example:"https://storage.example.com/avatars/user123/avatar.jpg"`
	Country     string    `db:"location_country" json:"country" example:"United States"`
	Region      string    `json:"region" example:"California"` // Not in current schema
	City        string    `db:"location_city" json:"city" example:"San Francisco"`
	IsPublic    bool      `db:"is_profile_public" json:"is_public" example:"true"`
	CreatedAt   time.Time `db:"created_at" json:"created_at" example:"2024-01-15T10:30:00Z"`
	UpdatedAt   time.Time `db:"updated_at" json:"updated_at" example:"2024-01-20T14:45:00Z"`
}

// UpdateProfileRequest represents profile update payload
type UpdateProfileRequest struct {
	FirstName   string `json:"first_name" example:"Alice"`
	LastName    string `json:"last_name" example:"Wonderland"`
	DisplayName string `json:"display_name" example:"Alice Wonderland"` // Combined name or custom display name
	Bio         string `json:"bio" example:"Explorer and adventurer"`
	AvatarURL   string `json:"avatar_url" example:"https://storage.example.com/avatar.jpg"`
	Country     string `json:"country" example:"United States"`
	Region      string `json:"region" example:"California"`
	City        string `json:"city" example:"San Francisco"`
	IsPublic    *bool  `json:"is_public" example:"true"`
	ClientIP    string `json:"-"` // Not from JSON, set by handler
}

// PublicProfileResponse represents limited profile info for other users
type PublicProfileResponse struct {
	UserID      string `json:"user_id" example:"550e8400-e29b-41d4-a716-446655440000"`
	DisplayName string `json:"display_name" example:"Alice Wonderland"`
	FirstName   string `json:"first_name" example:"Alice"`
	LastName    string `json:"last_name" example:"Wonderland"`
	Bio         string `json:"bio" example:"Explorer and adventurer"`
	AvatarURL   string `json:"avatar_url" example:"https://storage.example.com/avatar.jpg"`
	Country     string `json:"country" example:"United States"`
	Region      string `json:"region" example:"California"`
	City        string `json:"city" example:"San Francisco"`
}

// ProfileStats represents user's economy statistics
type ProfileStats struct {
	UserID        string `json:"user_id" example:"550e8400-e29b-41d4-a716-446655440000"`
	SilverBalance int64  `json:"silver_balance" example:"12500"` // in centinels (125 Seals)
	GoldBalance   int64  `json:"gold_balance" example:"5000"`    // in centinels (50 Seals)
	TotalSent     int64  `json:"total_sent" example:"8000"`      // in centinels
	TotalReceived int64  `json:"total_received" example:"20000"` // in centinels
}
