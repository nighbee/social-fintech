package mapmodule

import "time"

// Task represents a geospatial task stored in PostGIS.
// Reward is stored in centinels (1 seal = 100 centinels).
type Task struct {
	ID               string     `db:"id"                json:"id"`
	Title            string     `db:"title"             json:"title"`
	Description      *string    `db:"description"       json:"description,omitempty"`
	Reward           int64      `db:"reward"            json:"reward_centinels"`
	CreatorID        string     `db:"creator_id"        json:"creator_id"`
	Latitude         float64    `db:"latitude"          json:"latitude"`
	Longitude        float64    `db:"longitude"         json:"longitude"`
	WorkersNeeded    int        `db:"workers_needed"    json:"workers_needed"`
	WorkersFilled    int        `db:"workers_filled"    json:"workers_filled"`
	// VerificationCode is only returned to the task creator — never in list/nearby responses.
	VerificationCode string     `db:"verification_code" json:"verification_code,omitempty"`
	Status           string     `db:"status"            json:"status"`
	AutoShutdownAt   *time.Time `db:"auto_shutdown_at"  json:"auto_shutdown_at,omitempty"`
	// Legacy fields kept for backward compatibility; status is now canonical.
	IsActive    bool       `db:"is_active"    json:"is_active"`
	CompletedBy *string    `db:"completed_by" json:"completed_by,omitempty"`
	CompletedAt *time.Time `db:"completed_at" json:"completed_at,omitempty"`
	H3Res5      *string    `db:"h3_res5"      json:"h3_res5,omitempty"`
	H3Res4      *string    `db:"h3_res4"      json:"h3_res4,omitempty"`
	H3Res2      *string    `db:"h3_res2"      json:"h3_res2,omitempty"`
	CreatedAt   time.Time  `db:"created_at"   json:"created_at"`
	UpdatedAt   time.Time  `db:"updated_at"   json:"updated_at"`
}

// TaskApplication represents a user2 offer to help complete a task.
// Status lifecycle: pending → code_verified → confirmed
//
//	                         └→ rejected
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

// ─── Request / Response DTOs ──────────────────────────────────────────────────

// CreateTaskRequest defines the task creation payload from the Flutter client.
type CreateTaskRequest struct {
	Title string `json:"title" example:"Pick up a package"`
	Description string `json:"description" example:"Please pick up the red package from the lobby"`
	// Reward must be 1, 2, or 3 Silver Seals.
	Reward int `json:"reward" example:"2"`
	// WorkersNeeded is the number of helpers required to close the task (1–20).
	WorkersNeeded int     `json:"workers_needed" example:"1"`
	Latitude      float64 `json:"latitude"       example:"37.7749"`
	Longitude     float64 `json:"longitude"      example:"-122.4194"`
	// AutoShutdown enables automatic task cancellation 24 hours after creation.
	AutoShutdown bool `json:"auto_shutdown" example:"true"`
}

// TaskResponse is the public task view — no verification code.
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

// CreateTaskResponse extends TaskResponse with the verification code shown only to the creator.
type CreateTaskResponse struct {
	TaskResponse
	VerificationCode string `json:"verification_code"`
}

// CancelTaskResponse is returned after a successful task cancellation.
type CancelTaskResponse struct {
	TaskID string `json:"task_id"`
	Status string `json:"status"`
}

// NearbyTasksResponse is returned for map task search.
type NearbyTasksResponse struct {
	Tasks []TaskResponse `json:"tasks"`
}

// ApplyToTaskResponse is returned when user2 presses "I can help".
type ApplyToTaskResponse struct {
	ApplicationID string `json:"application_id"`
	TaskID        string `json:"task_id"`
	Status        string `json:"status"` // always "pending" on creation
}

// SubmitVerificationCodeRequest carries the 4-digit code entered by user2.
type SubmitVerificationCodeRequest struct {
	Code string `json:"code" example:"4821"`
}

// VerifyCodeResponse is returned after user2 submits the verification code.
type VerifyCodeResponse struct {
	ApplicationID string `json:"application_id"`
	Status        string `json:"status"` // "code_verified" on success
}

// ConfirmCompletionResponse is returned after user1 confirms user2 helped.
// The silver transfer is triggered at this point.
type ConfirmCompletionResponse struct {
	TaskID        string  `json:"task_id"`
	ApplicationID string  `json:"application_id"`
	Reward        float64 `json:"reward"` // seals paid to user2
	TaskStatus    string  `json:"task_status"`
}

// ApplicationResponse is a public view of a TaskApplication (no sensitive fields).
type ApplicationResponse struct {
	ID          string    `json:"id"`
	TaskID      string    `json:"task_id"`
	ApplicantID string    `json:"applicant_id"`
	Status      string    `json:"status"`
	CreatedAt   time.Time `json:"created_at"`
}

// TaskCompletionResponse — legacy, kept until service Phase 3 removes CompleteTask.
type TaskCompletionResponse struct {
	TaskID    string  `json:"task_id"`
	Reward    float64 `json:"reward"`
	Completed bool    `json:"completed"`
}

// RegionAssignmentRequest assigns a user to H3 cells based on current location.
type RegionAssignmentRequest struct {
	Latitude            float64 `json:"latitude"             example:"37.7749"`
	Longitude           float64 `json:"longitude"            example:"-122.4194"`
	ParticipateDistrict bool    `json:"participate_district" example:"true"`
	LocationOptIn       bool    `json:"location_opt_in"      example:"true"`
}

// RegionAssignmentResponse returns the computed H3 indices for the user.
type RegionAssignmentResponse struct {
	H3Res5              string    `json:"h3_res5,omitempty"`
	H3Res4              string    `json:"h3_res4,omitempty"`
	H3Res2              string    `json:"h3_res2,omitempty"`
	ParticipateDistrict bool      `json:"participate_district"`
	LocationOptIn       bool      `json:"location_opt_in"`
	UpdatedAt           time.Time `json:"updated_at"`
}

// RegionChampion represents the weekly champion snapshot for a region.
type RegionChampion struct {
	ID         string    `db:"id"         json:"id"`
	H3Index    string    `db:"h3_index"   json:"h3_index"`
	Resolution int       `db:"resolution" json:"resolution"`
	UserID     string    `db:"user_id"    json:"user_id"`
	Score      int64     `db:"score"      json:"score"`
	Week       int       `db:"week"       json:"week"`
	Year       int       `db:"year"       json:"year"`
	UpdatedAt  time.Time `db:"updated_at" json:"updated_at"`
}

// ChampionPin is used for map pin rendering on the Flutter client.
type ChampionPin struct {
	H3Index    string `json:"h3_index"`
	Resolution int    `json:"resolution"`
	UserID     string `json:"user_id"`
	Score      int64  `json:"score"`
}
