package mapmodule

import "time"

// Task represents a geospatial task stored in PostGIS.
// Reward is stored in centinels (1 seal = 100 centinels).
type Task struct {
	ID        string    `db:"id" json:"id"`
	Title     string    `db:"title" json:"title"`
	Reward    int64     `db:"reward" json:"reward_centinels"`
	CreatorID string    `db:"creator_id" json:"creator_id"`
	Latitude  float64   `db:"latitude" json:"latitude"`
	Longitude float64   `db:"longitude" json:"longitude"`
	IsActive  bool      `db:"is_active" json:"is_active"`
	H3Res5    *string   `db:"h3_res5" json:"h3_res5,omitempty"`
	H3Res4    *string   `db:"h3_res4" json:"h3_res4,omitempty"`
	H3Res2    *string   `db:"h3_res2" json:"h3_res2,omitempty"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
	UpdatedAt time.Time `db:"updated_at" json:"updated_at"`
}

// CreateTaskRequest defines task creation payload.
type CreateTaskRequest struct {
	Title     string  `json:"title" example:"Pick up a package"`
	Reward    float64 `json:"reward" example:"1.5"` // in seals
	Latitude  float64 `json:"latitude" example:"37.7749"`
	Longitude float64 `json:"longitude" example:"-122.4194"`
}

// TaskResponse represents task data returned to clients.
type TaskResponse struct {
	ID        string    `json:"id"`
	Title     string    `json:"title"`
	Reward    float64   `json:"reward"` // in seals
	Latitude  float64   `json:"latitude"`
	Longitude float64   `json:"longitude"`
	CreatedAt time.Time `json:"created_at"`
}

// NearbyTasksResponse is returned for map task search.
type NearbyTasksResponse struct {
	Tasks []TaskResponse `json:"tasks"`
}

// RegionAssignmentRequest assigns a user to H3 cells based on current location.
type RegionAssignmentRequest struct {
	Latitude            float64 `json:"latitude" example:"37.7749"`
	Longitude           float64 `json:"longitude" example:"-122.4194"`
	ParticipateDistrict bool    `json:"participate_district" example:"true"`
	LocationOptIn       bool    `json:"location_opt_in" example:"true"`
}

// RegionAssignmentResponse returns the computed H3 indices for the user.
type RegionAssignmentResponse struct {
	H3Res5             string    `json:"h3_res5,omitempty"`
	H3Res4             string    `json:"h3_res4,omitempty"`
	H3Res2             string    `json:"h3_res2,omitempty"`
	ParticipateDistrict bool     `json:"participate_district"`
	LocationOptIn      bool      `json:"location_opt_in"`
	UpdatedAt          time.Time `json:"updated_at"`
}

// RegionChampion represents weekly champion snapshot for a region.
type RegionChampion struct {
	ID         string    `db:"id" json:"id"`
	H3Index    string    `db:"h3_index" json:"h3_index"`
	Resolution int       `db:"resolution" json:"resolution"`
	UserID     string    `db:"user_id" json:"user_id"`
	Score      int64     `db:"score" json:"score"`
	Week       int       `db:"week" json:"week"`
	Year       int       `db:"year" json:"year"`
	UpdatedAt  time.Time `db:"updated_at" json:"updated_at"`
}

// ChampionPin is used for map pins rendering.
type ChampionPin struct {
	H3Index    string `json:"h3_index"`
	Resolution int    `json:"resolution"`
	UserID     string `json:"user_id"`
	Score      int64  `json:"score"`
}
