package ranks

import "fmt"

var RankCatalog = []RankDefinition{
	{
		ID:          "pearl",
		Name:        "Pearl",
		Quality:     "Awareness",
		MinSeals:    0,
		MaxSeals:    10,
		Order:       1,
		IconURL:     "/assets/ranks/pearl.png",
		Description: "Beginning of the path. The member shows conscious participation and earns recognition for consistent, real actions.",
		Levels:      []string{"C", "B", "A", "S"},
	},
	{
		ID:          "moonstone",
		Name:        "Moonstone",
		Quality:     "Intention",
		MinSeals:    10,
		MaxSeals:    25,
		Order:       2,
		IconURL:     "/assets/ranks/moonstone.png",
		Description: "Actions become deliberate. The member acts with purpose and supports others in a meaningful way.",
		Levels:      []string{"C", "B", "A", "S"},
	},
	{
		ID:          "jade",
		Name:        "Jade",
		Quality:     "Discipline",
		MinSeals:    25,
		MaxSeals:    60,
		Order:       3,
		IconURL:     "/assets/ranks/jade.png",
		Description: "Consistency under control. Recognition reflects reliability, self-control, and repeated contribution over time.",
		Levels:      []string{"C", "B", "A", "S"},
	},
	{
		ID:          "lapis",
		Name:        "Lapis Lazuli",
		Quality:     "Influence",
		MinSeals:    60,
		MaxSeals:    140,
		Order:       4,
		IconURL:     "/assets/ranks/lapis.png",
		Description: "Impact extends beyond self. The member's actions begin shaping the behavior and standards of others.",
		Levels:      []string{"C", "B", "A", "S"},
	},
	{
		ID:          "ammolite",
		Name:        "Ammolite",
		Quality:     "Fortitude",
		MinSeals:    140,
		MaxSeals:    260,
		Order:       5,
		IconURL:     "/assets/ranks/ammolite.png",
		Description: "Strength through pressure. Recognition reflects resilience, long-term commitment, and stability in difficult moments.",
		Levels:      []string{"C", "B", "A", "S"},
	},
	{
		ID:          "onyx",
		Name:        "Onyx",
		Quality:     "Transcendence",
		MinSeals:    260,
		MaxSeals:    700,
		Order:       6,
		IconURL:     "/assets/ranks/onyx.png",
		Description: "Above ego and noise. The member is respected for composure, principles, and clean conduct even when unseen.",
		Levels:      []string{"C", "B", "A", "S"},
	},
	{
		ID:          "supernova",
		Name:        "Supernova",
		Quality:     "Sovereign",
		MinSeals:    700,
		MaxSeals:    999999,
		Order:       7,
		IconURL:     "/assets/ranks/supernova.png",
		Description: "System-level recognition. Top-tier rank awarded for sustained impact, influence, and community-wide respect.",
		Levels:      nil,
	},
}

func GetRankBySeals(seals int) *RankDefinition {
	if seals < 0 {
		seals = 0
	}

	for i := range RankCatalog {
		if seals >= RankCatalog[i].MinSeals && seals < RankCatalog[i].MaxSeals {
			return &RankCatalog[i]
		}
	}

	return &RankCatalog[len(RankCatalog)-1]
}

func CalculateRankAndLevel(seals int) (rank *RankDefinition, level string, levelMin int, levelMax int) {
	rank = GetRankBySeals(seals)
	if len(rank.Levels) == 0 {
		return rank, "", rank.MinSeals, rank.MaxSeals
	}

	rangeSize := rank.MaxSeals - rank.MinSeals
	quarterSize := float64(rangeSize) / 4.0
	sealsInRank := seals - rank.MinSeals

	if sealsInRank < 0 {
		sealsInRank = 0
	}

	switch {
	case float64(sealsInRank) < quarterSize:
		level = "C"
		levelMin = rank.MinSeals
		levelMax = rank.MinSeals + int(quarterSize)
	case float64(sealsInRank) < quarterSize*2:
		level = "B"
		levelMin = rank.MinSeals + int(quarterSize)
		levelMax = rank.MinSeals + int(quarterSize*2)
	case float64(sealsInRank) < quarterSize*3:
		level = "A"
		levelMin = rank.MinSeals + int(quarterSize*2)
		levelMax = rank.MinSeals + int(quarterSize*3)
	default:
		level = "S"
		levelMin = rank.MinSeals + int(quarterSize*3)
		levelMax = rank.MaxSeals
	}

	return rank, level, levelMin, levelMax
}

func GetAllRanksWithLevels() []RankWithLevels {
	result := make([]RankWithLevels, len(RankCatalog))

	for i, rank := range RankCatalog {
		var subLevels []SubLevelInfo
		if len(rank.Levels) > 0 {
			rangeSize := rank.MaxSeals - rank.MinSeals
			quarterSize := float64(rangeSize) / 4.0

			subLevels = []SubLevelInfo{
				{
					Level:    "C",
					MinSeals: rank.MinSeals,
					MaxSeals: rank.MinSeals + int(quarterSize),
				},
				{
					Level:    "B",
					MinSeals: rank.MinSeals + int(quarterSize),
					MaxSeals: rank.MinSeals + int(quarterSize*2),
				},
				{
					Level:    "A",
					MinSeals: rank.MinSeals + int(quarterSize*2),
					MaxSeals: rank.MinSeals + int(quarterSize*3),
				},
				{
					Level:    "S",
					MinSeals: rank.MinSeals + int(quarterSize*3),
					MaxSeals: rank.MaxSeals,
				},
			}
		}

		result[i] = RankWithLevels{
			RankDefinition: rank,
			SubLevels:      subLevels,
		}
	}

	return result
}

func FormatRankTitle(rankName, quality, level string) string {
	if level == "" {
		return fmt.Sprintf("%s | %s", rankName, quality)
	}
	return fmt.Sprintf("%s | %s | %s", rankName, quality, level)
}

func GetRankTierString(goldSeals int) string {
	rank, level, _, _ := CalculateRankAndLevel(goldSeals)
	return FormatRankTitle(rank.Name, rank.Quality, level)
}
