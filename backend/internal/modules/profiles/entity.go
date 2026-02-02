package profiles

import "time"

type Profile struct {
	UserID    string    `db:"user_id" json:"user_id"`
	FirstName string    `db:"first_name" json:"first_name"`
	LastName  string    `db:"last_name" json:"last_name"`
	Bio       string    `db:"bio" json:"bio"`
	AvatarURL string    `db:"avatar_url" json:"avatar_url"`
	Country   string    `db:"country" json:"country"`
	Region    string    `db:"region" json:"region"`
	City      string    `db:"city" json:"city"`
	IsPublic  bool      `db:"is_public" json:"is_public"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
	UpdatedAt time.Time `db:"updated_at" json:"updated_at"`
}

type UpdateProfileRequest struct {
	FirstName string `json:"first_name"`
	LastName  string `json:"last_name"`
	Bio       string `json:"bio"`
	AvatarURL string `json:"avatar_url"`
	Country   string `json:"country"`
	Region    string `json:"region"`
	City      string `json:"city"`
	IsPublic  *bool  `json:"is_public"`
}

type PublicProfileResponse struct {
	UserID    string `json:"user_id"`
	FirstName string `json:"first_name"`
	LastName  string `json:"last_name"`
	Bio       string `json:"bio"`
	AvatarURL string `json:"avatar_url"`
	Country   string `json:"country"`
	Region    string `json:"region"`
	City      string `json:"city"`
}

type ProfileStats struct {
	UserID        string `json:"user_id"`
	SilverBalance int64  `json:"silver_balance"`
	GoldBalance   int64  `json:"gold_balance"`
	TotalSent     int64  `json:"total_sent"`
	TotalReceived int64  `json:"total_received"`
}
