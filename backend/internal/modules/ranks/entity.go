package ranks

type RankDefinition struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Quality     string   `json:"quality"`
	MinSeals    int      `json:"min_seals"`
	MaxSeals    int      `json:"max_seals"`
	IconURL     string   `json:"icon_url"`
	Description string   `json:"description"`
	Order       int      `json:"order"`
	Levels      []string `json:"levels"`
}

type SubLevelInfo struct {
	Level    string `json:"level"`
	MinSeals int    `json:"min_seals"`
	MaxSeals int    `json:"max_seals"`
}

type RankWithLevels struct {
	RankDefinition
	SubLevels []SubLevelInfo `json:"sub_levels"`
}

type CurrentRankResponse struct {
	RankName            string  `json:"rank_name"`
	QualityName         string  `json:"quality_name"`
	Level               string  `json:"level"`
	FullTitle           string  `json:"full_title"`
	IconURL             string  `json:"icon_url"`
	CurrentSeals        int     `json:"current_seals"`
	RankMinSeals        int     `json:"rank_min_seals"`
	RankMaxSeals        int     `json:"rank_max_seals"`
	LevelMinSeals       int     `json:"level_min_seals"`
	LevelMaxSeals       int     `json:"level_max_seals"`
	NextLevel           string  `json:"next_level,omitempty"`
	NextRank            string  `json:"next_rank,omitempty"`
	ProgressToNextLevel float64 `json:"progress_to_next_level"`
	ProgressInRank      float64 `json:"progress_in_rank"`
	Description         string  `json:"description"`
}

type RankListResponse struct {
	Ranks []RankWithLevels `json:"ranks"`
}
