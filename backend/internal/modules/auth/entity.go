package auth

import "time"


// модель для аккаунта для хранения имени, юзернейма имейла и дату рождения тд...
type User struct {
	ID             string     `db:"id" json:"id"`
	Email          string     `db:"email" json:"email"`
	Username       string     `db:"username" json:"username"`
	PasswordHash   string     `db:"password_hash" json:"-"`
	FirstName      string     `db:"first_name" json:"first_name"`
	LastName       string     `db:"last_name" json:"last_name"`
	DateOfBirth    *time.Time `db:"date_of_birth" json:"date_of_birth"`
	ReferralCode   string     `db:"referral_code" json:"referral_code"`
	PhoneCountry   string     `db:"phone_country_code" json:"-"`
	PhoneNumber    string     `db:"phone_number" json:"-"`
	AvatarURL      string     `db:"avatar_url" json:"avatar_url"`
	IsShadowBanned bool       `db:"is_shadow_banned" json:"is_shadow_banned"`
	CreatedAt      time.Time  `db:"created_at" json:"created_at"`
	UpdatedAt      time.Time  `db:"updated_at" json:"updated_at"`
	LastActiveAt   time.Time  `db:"last_active_at" json:"last_active_at"`
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
	Email       string `json:"email"`
	Password    string `json:"password"`
	FirstName   string `json:"first_name"`
	LastName    string `json:"last_name"`
	DateOfBirth string `json:"date_of_birth"` // YYYY-MM-DD
	Referral    string `json:"referral"`
	DeviceID    string `json:"device_id"`
	UserAgent   string `json:"user_agent"`
	AppVersion  string `json:"app_version"`
}


//логин по имейлу
type EmailLoginRequest struct {
	Email      string `json:"email"`
	Password   string `json:"password"`
	DeviceID   string `json:"device_id"`
	UserAgent  string `json:"user_agent"`
	AppVersion string `json:"app_version"`
}


// запрос для кода верифиакиций нужен
type PhoneCodeRequest struct {
	CountryCode string `json:"country_code"`
	PhoneNumber string `json:"phone_number"`
	Purpose     string `json:"purpose"` // login|register
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
	Verified        bool   `json:"verified"`
	VerificationID  string `json:"verification_id,omitempty"`
	AccessToken     string `json:"access_token,omitempty"`
	RefreshToken    string `json:"refresh_token,omitempty"`
	User            *User  `json:"user,omitempty"`
}


// для завершения регистрации с телефоном
type PhoneRegisterRequest struct {
	VerificationID string `json:"verification_id"`
	FirstName      string `json:"first_name"`
	LastName       string `json:"last_name"`
	DateOfBirth    string `json:"date_of_birth"` // YYYY-MM-DD
	Referral       string `json:"referral"`
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
