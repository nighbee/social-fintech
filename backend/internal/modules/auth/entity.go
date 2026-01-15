package auth

import "time"

type User struct {
	ID             string `db:"id" json:"id"`
	Email          string `db:"email" json:"email"`
	Username       string `db:"username" json:"username"`
	AvatarURL      string `db:"avatar_url" json:"avatar_url"`
	IsShadowBanned bool   `db:"is_shadow_banned" json:"is_shadow_banned"`
	CreatedAt      time.Time `db:"created_at" json:"created_at"`
	UpdatedAt		time.Time `db:"updated_at" json:"updated_at"`
	LastActiveAt time.Time `db:"last_active_at" json:"last_active_at"`
}

type Session struct {
	ID string `db:"id"`
	UserID string `db:"user_id"`
	DeviceID string `db:"device_id"`
	IP string 	`db:"ip"`
	LastActiveAt time.Time `db:"last_active_at"`
	CreatedAt time.Time `db:"created_at"`
}

type Identity struct {
	UserID string `db:"user_id"`
	Provider string `db:"provider"`
	Subject string `db:"subject"`
	Email string `db:"email"`
	CreatedAt time.Time `db:"created_at"`
}

type LoginRequest struct {
	ProviderType ProviderType `json:"provider_type"`
	ProviderToken string `json:"provider_token"`
	DeviceID string `json:"device_id"`
}

type LoginResponse struct {
	AccessToken string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	User User `json:"user"`
}

type RefreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}