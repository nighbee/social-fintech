package auth

import "time"

// модель для аккаунта для хранения имени, юзернейма имейла и дату рождения тд...
type User struct {
	ID                  string     `db:"id" json:"id"`
	Email               string     `db:"email" json:"email"`
	Username            string     `db:"username" json:"username"`
	PasswordHash        string     `db:"password_hash" json:"-"`
	FirstName           string     `db:"first_name" json:"first_name"`
	LastName            string     `db:"last_name" json:"last_name"`
	DateOfBirth         *time.Time `db:"date_of_birth" json:"date_of_birth"`
	ReferralCode        string     `db:"referral_code" json:"referral_code"`
	PhoneCountry        *string    `db:"phone_country_code" json:"-"`
	PhoneNumber         *string    `db:"phone_number" json:"-"`
	AvatarURL           string     `db:"avatar_url" json:"avatar_url"`
	IsShadowBanned      bool       `db:"is_shadow_banned" json:"is_shadow_banned"`
	IsAdmin             bool       `db:"is_admin" json:"is_admin"`
	H3Res5              *string    `db:"h3_res5" json:"h3_res5,omitempty"`
	H3Res4              *string    `db:"h3_res4" json:"h3_res4,omitempty"`
	H3Res2              *string    `db:"h3_res2" json:"h3_res2,omitempty"`
	ParticipateDistrict bool       `db:"participate_district" json:"participate_district"`
	LocationOptIn       bool       `db:"location_opt_in" json:"location_opt_in"`
	LocationUpdatedAt   *time.Time `db:"location_updated_at" json:"location_updated_at,omitempty"`
	FeedTimeLimitMins   int        `db:"feed_time_limit_mins" json:"-"`
	CreatedAt           time.Time  `db:"created_at" json:"created_at"`
	UpdatedAt           time.Time  `db:"updated_at" json:"updated_at"`
	LastActiveAt        time.Time  `db:"last_active_at" json:"last_active_at"`
}

// модель для определенной сессии входа, чтобы рефрешить и трекать их (юзер активити)
type Session struct {
	ID               string     `db:"id"`
	UserID           string     `db:"user_id"`
	DeviceID         string     `db:"device_id"`
	IP               string     `db:"ip"`
	UserAgent        string     `db:"user_agent"`
	AppVersion       string     `db:"app_version"`
	LastActiveAt     time.Time  `db:"last_active_at"`
	CreatedAt        time.Time  `db:"created_at"`
	RefreshTokenHash string     `db:"refresh_token_hash"`
	RevokedAt        *time.Time `db:"revoked_at"`
}

// запись для кода верификации + номер телефона
type PhoneVerification struct {
	ID           string     `db:"id"`
	PhoneCountry string     `db:"phone_country_code"`
	PhoneNumber  string     `db:"phone_number"`
	Purpose      string     `db:"purpose"`
	CodeHash     string     `db:"code_hash"`
	ExpiresAt    time.Time  `db:"expires_at"`
	ConsumedAt   *time.Time `db:"consumed_at"`
	UsedAt       *time.Time `db:"used_at"`
	CreatedAt    time.Time  `db:"created_at"`
}

//вот здесь сделал связку с провайдером через что пользовательно заходит (oauth/телефон/имейл)
type Identity struct {
	UserID    string    `db:"user_id"`
	Provider  string    `db:"provider"`
	Subject   string    `db:"subject"`
	Email     string    `db:"email"`
	CreatedAt time.Time `db:"created_at"`
}

// для входа через oauth
type LoginRequest struct {
	ProviderType  ProviderType `json:"provider_type"`
	ProviderToken string       `json:"provider_token"`
	DeviceID      string       `json:"device_id"`
	UserAgent     string       `json:"user_agent"`
	AppVersion    string       `json:"app_version"`
}

// регистрация по имейлу
type EmailRegisterRequest struct {
	Email          string `json:"email" example:"john.doe@example.com"`
	Password       string `json:"password" example:"SecurePass123!"`
	FirstName      string `json:"first_name" example:"John"`
	LastName       string `json:"last_name" example:"Doe"`
	DateOfBirth    string `json:"date_of_birth" example:"2000-01-01"` // YYYY-MM-DD
	ReferrerUserID string `json:"referrer_user_id" example:"FRIEND123"`
	DeviceID       string `json:"device_id" example:"device-uuid-12345"`
	UserAgent      string `json:"user_agent" example:"BrightBund-iOS/1.0"`
	AppVersion     string `json:"app_version" example:"1.0.0"`
}

//логин по имейлу
type EmailLoginRequest struct {
	Email      string `json:"email" example:"john.doe@example.com"`
	Password   string `json:"password" example:"SecurePass123!"`
	DeviceID   string `json:"device_id" example:"device-uuid-12345"`
	UserAgent  string `json:"user_agent" example:"BrightBund-iOS/1.0"`
	AppVersion string `json:"app_version" example:"1.0.0"`
}

// проверка существования имейла
type CheckEmailRequest struct {
	Email string `json:"email" example:"john.doe@example.com"`
}

// ответ проверки имейла
type CheckEmailResponse struct {
	Exists bool `json:"exists" example:"true"`
}

// запрос для кода верифиакиций нужен
type PhoneCodeRequest struct {
	CountryCode string `json:"country_code" example:"+1"`
	PhoneNumber string `json:"phone_number" example:"5551234567"`
	Purpose     string `json:"purpose" example:"register"` // login|register
}

// ответ с верификацией
type PhoneCodeResponse struct {
	VerificationID string    `json:"verification_id"`
	ExpiresAt      time.Time `json:"expires_at"`
}

type PhoneVerifyRequest struct {
	VerificationID string `json:"verification_id"`
	Code           string `json:"code"`
	DeviceID       string `json:"device_id"`
	UserAgent      string `json:"user_agent"`
	AppVersion     string `json:"app_version"`
}

type PhoneVerifyResponse struct {
	Verified       bool   `json:"verified"`
	VerificationID string `json:"verification_id,omitempty"`
	AccessToken    string `json:"access_token,omitempty"`
	RefreshToken   string `json:"refresh_token,omitempty"`
	User           *User  `json:"user,omitempty"`
}

// для завершения регистрации с телефоном
type PhoneRegisterRequest struct {
	VerificationID string `json:"verification_id"`
	FirstName      string `json:"first_name"`
	LastName       string `json:"last_name"`
	DateOfBirth    string `json:"date_of_birth"` // YYYY-MM-DD
	ReferrerUserID string `json:"referrer_user_id"`
	DeviceID       string `json:"device_id"`
	UserAgent      string `json:"user_agent"`
	AppVersion     string `json:"app_version"`
}

// ответ единый токенами
type LoginResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	User         User   `json:"user"`
}

//запрос на рефреш токена
type RefreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

// Firebase phone authentication request
// Client sends Firebase ID token after successful OTP verification
type FirebasePhoneAuthRequest struct {
	FirebaseIDToken string `json:"firebase_id_token"`
	DeviceID        string `json:"device_id"`
	UserAgent       string `json:"user_agent"`
	AppVersion      string `json:"app_version"`
}

// Firebase phone registration request
// Used when Firebase token is verified but user doesn't exist yet
type FirebasePhoneRegisterRequest struct {
	FirebaseIDToken string `json:"firebase_id_token"`
	FirstName       string `json:"first_name"`
	LastName        string `json:"last_name"`
	DateOfBirth     string `json:"date_of_birth"` // YYYY-MM-DD
	ReferrerUserID  string `json:"referrer_user_id"`
	DeviceID        string `json:"device_id"`
	UserAgent       string `json:"user_agent"`
	AppVersion      string `json:"app_version"`
}

// Swagger error response
type ErrorResponse struct {
	Error   string `json:"error" example:"invalid_credentials"`
	Message string `json:"message,omitempty" example:"Invalid email or password"`
}
