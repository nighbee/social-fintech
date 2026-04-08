package mapmodule

import (
	"time"

	"github.com/google/uuid"
)

// Task represents a geospatial task stored in PostGIS.
// Reward is stored in centinels (1 seal = 100 centinels).
type Task struct {
	ID            string  `db:"id"                json:"id"`
	Title         string  `db:"title"             json:"title"`
	Description   *string `db:"description"       json:"description,omitempty"`
	Reward        int64   `db:"reward"            json:"reward_centinels"`
	CreatorID     string  `db:"creator_id"        json:"creator_id"`
	Latitude      float64 `db:"latitude"          json:"latitude"`
	Longitude     float64 `db:"longitude"         json:"longitude"`
	WorkersNeeded int     `db:"workers_needed"    json:"workers_needed"`
	WorkersFilled int     `db:"workers_filled"    json:"workers_filled"`
	// VerificationCode is only returned to the task creator — never in list/nearby responses.
	VerificationCode string     `db:"verification_code" json:"verification_code,omitempty"`
	Status           string     `db:"status"            json:"status"`
	AutoShutdownAt   *time.Time `db:"auto_shutdown_at"  json:"auto_shutdown_at,omitempty"`
	IsActive         bool       `db:"is_active"    json:"is_active"`
	CompletedBy      *string    `db:"completed_by" json:"completed_by,omitempty"`
	CompletedAt      *time.Time `db:"completed_at" json:"completed_at,omitempty"`
	H3Res5           *string    `db:"h3_res5"      json:"h3_res5,omitempty"`
	H3Res4           *string    `db:"h3_res4"      json:"h3_res4,omitempty"`
	H3Res2           *string    `db:"h3_res2"      json:"h3_res2,omitempty"`
	CreatedAt        time.Time  `db:"created_at"   json:"created_at"`
	UpdatedAt        time.Time  `db:"updated_at"   json:"updated_at"`
}

// TaskApplication represents a user2 offer to help complete a task.
// Status lifecycle: pending → code_verified → confirmed
//
//	└→ rejected
type TaskApplication struct {
	ID              string     `db:"id"               json:"id"`
	TaskID          string     `db:"task_id"          json:"task_id"`
	ApplicantID     string     `db:"applicant_id"     json:"applicant_id"`
	Status          string     `db:"status"           json:"status"`
	CodeSubmittedAt *time.Time `db:"code_submitted_at" json:"code_submitted_at,omitempty"`
	ConfirmedAt     *time.Time `db:"confirmed_at"     json:"confirmed_at,omitempty"`
	CreatedAt       time.Time  `db:"created_at"       json:"created_at"`
	UpdatedAt       time.Time  `db:"updated_at"       json:"updated_at"`
}

type CreateTaskRequest struct {
	Title         string  `json:"title" example:"Pick up a package"`
	Description   string  `json:"description" example:"Please pick up the red package from the lobby"`
	Reward        int     `json:"reward" example:"2"`
	WorkersNeeded int     `json:"workers_needed" example:"1"`
	Latitude      float64 `json:"latitude"       example:"37.7749"`
	Longitude     float64 `json:"longitude"      example:"-122.4194"`
	AutoShutdown  bool    `json:"auto_shutdown" example:"true"`
}
type TaskResponse struct {
	ID             string     `json:"id"`
	Title          string     `json:"title"`
	Description    *string    `json:"description,omitempty"`
	Reward         float64    `json:"reward"` // in seals
	WorkersNeeded  int        `json:"workers_needed"`
	WorkersFilled  int        `json:"workers_filled"`
	Status         string     `json:"status"`
	AutoShutdownAt *time.Time `json:"auto_shutdown_at,omitempty"`
	Latitude       float64    `json:"latitude"`
	Longitude      float64    `json:"longitude"`
	CreatedAt      time.Time  `json:"created_at"`
}

type CreateTaskResponse struct {
	TaskResponse
	VerificationCode string `json:"verification_code"`
}

type CancelTaskResponse struct {
	TaskID string `json:"task_id"`
	Status string `json:"status"`
}

type NearbyTasksResponse struct {
	Tasks []TaskResponse `json:"tasks"`
}

type AppliedTasksResponse struct {
	Tasks []TaskResponse `json:"tasks"`
}

type ApplyToTaskResponse struct {
	ApplicationID string `json:"application_id"`
	TaskID        string `json:"task_id"`
	Status        string `json:"status"` // always "pending" on creation
}

type SubmitVerificationCodeRequest struct {
	Code string `json:"code" example:"4821"`
}

type VerifyCodeResponse struct {
	ApplicationID string `json:"application_id"`
	Status        string `json:"status"` // "code_verified" on success
}

// H3AdminLookupResponse returns the administrative hierarchy for a given H3 index.
type H3AdminLookupResponse struct {
	H3Index     string `json:"h3_index" example:"8a2830707fc1fff"`
	CityName    string `json:"city_name" example:"Almaty"`
	RegionName  string `json:"region_name" example:"Almaty Region"`
	CountryName string `json:"country_name" example:"Kazakhstan"`
	CountryCode string `json:"country_code" example:"KZ"`
	ResolvedAt  string `json:"resolved_at" example:"2026-03-21T12:00:00Z"`
}

type ConfirmCompletionResponse struct {
	TaskID        string  `json:"task_id"`
	ApplicationID string  `json:"application_id"`
	Reward        float64 `json:"reward"` // seals paid to user2
	TaskStatus    string  `json:"task_status"`
}

type ApplicationResponse struct {
	ID          string    `json:"id"`
	TaskID      string    `json:"task_id"`
	ApplicantID string    `json:"applicant_id"`
	Status      string    `json:"status"`
	CreatedAt   time.Time `json:"created_at"`
}

type TaskCompletionResponse struct {
	TaskID    string  `json:"task_id"`
	Reward    float64 `json:"reward"`
	Completed bool    `json:"completed"`
}

type RegionAssignmentRequest struct {
	Latitude            float64 `json:"latitude"             example:"37.7749"`
	Longitude           float64 `json:"longitude"            example:"-122.4194"`
	ParticipateDistrict bool    `json:"participate_district" example:"true"`
	LocationOptIn       bool    `json:"location_opt_in"      example:"true"`
}

type RegionAssignmentResponse struct {
	H3Res5              string    `json:"h3_res5,omitempty"`
	H3Res4              string    `json:"h3_res4,omitempty"`
	H3Res2              string    `json:"h3_res2,omitempty"`
	ParticipateDistrict bool      `json:"participate_district"`
	LocationOptIn       bool      `json:"location_opt_in"`
	UpdatedAt           time.Time `json:"updated_at"`
}

type UserRegionState struct {
	H3Res5            *string    `db:"h3_res5"`
	H3Res4            *string    `db:"h3_res4"`
	H3Res2            *string    `db:"h3_res2"`
	LocationUpdatedAt *time.Time `db:"location_updated_at"`
}

type RegionChampion struct {
	ID         uuid.UUID `db:"id"          json:"id"`
	H3Index    string    `db:"h3_index"    json:"h3_index"`
	Resolution int       `db:"resolution"  json:"resolution"`
	UserID     uuid.UUID `db:"user_id"     json:"user_id"`
	Score      int64     `db:"score"       json:"score"`
	Week       int       `db:"week"        json:"week"`
	Year       int       `db:"year"        json:"year"`
	UpdatedAt  time.Time `db:"updated_at"  json:"updated_at"`

	// Enriched fields from geo-metadata
	CityName    string `db:"city_name"    json:"city_name,omitempty"`
	RegionName  string `db:"region_name"  json:"region_name,omitempty"`
	CountryName string `db:"country_name" json:"country_name,omitempty"`

	// Enriched from users + profiles
	Username  string `db:"username"   json:"username,omitempty"`
	AvatarURL string `db:"avatar_url" json:"avatar_url,omitempty"`
}

type H3GeoMetadata struct {
	H3Index     string    `db:"h3_index"     json:"h3_index"`
	CityName    string    `db:"city_name"    json:"city_name"`
	RegionName  string    `db:"region_name"  json:"region_name"`
	CountryName string    `db:"country_name" json:"country_name"`
	CountryCode string    `db:"country_code" json:"country_code"`
	ResolvedAt  time.Time `db:"resolved_at"  json:"resolved_at"`
}

type ChampionPin struct {
	H3Index     string `json:"h3_index"`
	Resolution  int    `json:"resolution"`
	UserID      string `json:"user_id"`
	Score       int64  `json:"score"`
	Username    string `json:"username"`
	AvatarURL   string `json:"avatar_url"`
	CityName    string `json:"city_name,omitempty"`
	CountryName string `json:"country_name,omitempty"`
}

