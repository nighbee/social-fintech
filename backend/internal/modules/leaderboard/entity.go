package leaderboard

type Scope string

const (
	ScopeDistrict Scope = "district"
	ScopeCity     Scope = "city"
	ScopeCountry  Scope = "country"
	ScopeGlobal   Scope = "global"
)

func (s Scope) Valid() bool {
	switch s {
	case ScopeDistrict, ScopeCity, ScopeCountry, ScopeGlobal:
		return true
	}
	return false
}

type Entry struct {
	Rank          int    `json:"rank"`
	UserID        string `json:"user_id"`
	Username      string `json:"username"`
	DisplayName   string `json:"display_name"`
	AvatarURL     string `json:"avatar_url,omitempty"`
	WeeklyScore   int    `json:"weekly_score"`
	HonorScore    int    `json:"honor_score"`
	RankName      string `json:"rank_name"`
	RankQuality   string `json:"rank_quality"`
	RankLevel     string `json:"rank_level,omitempty"`
	IsCurrentUser bool   `json:"is_current_user"`
}

type Response struct {
	Scope   Scope   `json:"scope"`
	Year    int     `json:"year"`
	Week    int     `json:"week"`
	Entries []Entry `json:"entries"`
}

type userProfile struct {
	UserID      string `db:"user_id"`
	Username    string `db:"username"`
	DisplayName string `db:"display_name"`
	AvatarURL   string `db:"avatar_url"`
	GoldSeals   int    `db:"gold_seals"`
}

type AdminRemoveUserRequest struct {
	UserID string `json:"user_id"`
	Scope  string `json:"scope"`
	Region string `json:"region,omitempty"`
}

type AdminAddUserRequest struct {
	UserID string  `json:"user_id"`
	Scope  string  `json:"scope"`
	Region string  `json:"region,omitempty"`
	Score  float64 `json:"score"`
}

type AdminAdjustScoreRequest struct {
	UserID string  `json:"user_id"`
	Scope  string  `json:"scope"`
	Region string  `json:"region,omitempty"`
	Amount float64 `json:"amount"`
}

type AdminListScopesResponse struct {
	Scopes []ScopeInfo `json:"scopes"`
}

type ScopeInfo struct {
	Scope     Scope  `json:"scope"`
	Region    string `json:"region,omitempty"`
	Key       string `json:"key"`
	Card      int64  `json:"card"`
}
