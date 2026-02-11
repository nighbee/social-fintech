package ranks

import "fmt"

var RankCatalog = []RankDefinition{
	{
		ID:          "pearl",
		Name:        "Pearl",
		Quality:     "Origin",
		MinSeals:    0,
		MaxSeals:    10,
		Order:       1,
		IconURL:     "/assets/ranks/pearl.png",
		Description: "Pearl is a versatile and widely loved gemstone known for its clarity and variety of colors. It’s durable, easy to polish, and used in everything from jewelry to technology. ",
		Levels:      []string{"C", "B", "A", "S"},
	},
	{
		ID:          "moonstone",
		Name:        "Moonstone",
		Quality:     "Clarity",
		MinSeals:    10,
		MaxSeals:    30,
		Order:       2,
		IconURL:     "/assets/ranks/moonstone.png",
		Description: "Moonstone is a gemstone known for its soft, glowing shimmer called adularescence. Its milky, dreamy appearance makes it feel almost magical. It’s often associated with calmness, intuition, and gentle energy.",
		Levels:      []string{"C", "B", "A", "S"},
	},
	{
		ID:          "jade",
		Name:        "Jade",
		Quality:     "Integrity",
		MinSeals:    30,
		MaxSeals:    70,
		Order:       3,
		IconURL:     "/assets/ranks/jade.png",
		Description: "Jade is a durable gemstone famous for its deep, waxy green color. It’s valued for its exceptional toughness and unique internal structure, which give each stone its own character.",
		Levels:      []string{"C", "B", "A", "S"},
	},
	{
		ID:          "lapis",
		Name:        "Lapis Lazuli",
		Quality:     "Ascendance",
		MinSeals:    70,
		MaxSeals:    170,
		Order:       4,
		IconURL:     "/assets/ranks/lapis.png",
		Description: "Lapis Lazuli is a captivating gemstone famous for its intense, deep blue color. It’s valued for its vivid shade and shimmering golden pyrite flecks, which give each stone its own character.",
		Levels:      []string{"C", "B", "A", "S"},
	},
	{
		ID:          "ammolite",
		Name:        "Ammolite",
		Quality:     "Fortitude",
		MinSeals:    170,
		MaxSeals:    300,
		Order:       5,
		IconURL:     "/assets/ranks/ammolite.png",
		Description: "Ammolite is a rare, iridescent gemstone formed from ancient ammonite fossils. Its shifting rainbow colors make it one of the most vibrant natural stones in the world. ",
		Levels:      []string{"C", "B", "A", "S"},
	},
	{
		ID:          "onyx",
		Name:        "Onyx",
		Quality:     "Transcendence",
		MinSeals:    300,
		MaxSeals:    1000,
		Order:       6,
		IconURL:     "/assets/ranks/onyx.png",
		Description: "Onyx is a natural gemstone known for its deep black color and smooth, polished surface. It has long been associated with strength, protection, and timeless elegance, giving it a bold yet refined presence.",
		Levels:      []string{"C", "B", "A", "S"},
	},
	{
		ID:          "supernova",
		Name:        "Supernova",
		Quality:     "Sovereign",
		MinSeals:    1000,
		MaxSeals:    999999,
		Order:       7,
		IconURL:     "/assets/ranks/supernova.png",
		Description: "A supernova is a powerful stellar explosion that occurs when a massive star reaches the end of its life cycle. It releases an enormous amount of energy and creates many of the heavy elements found in the universe.",
		Levels:      []string{"C", "B", "A", "S"},
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
		rangeSize := rank.MaxSeals - rank.MinSeals
		quarterSize := float64(rangeSize) / 4.0

		subLevels := []SubLevelInfo{
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

		result[i] = RankWithLevels{
			RankDefinition: rank,
			SubLevels:      subLevels,
		}
	}

	return result
}

func FormatRankTitle(rankName, quality, level string) string {
	return fmt.Sprintf("%s | %s | %s", rankName, quality, level)
}

func GetRankTierString(goldSeals int) string {
	rank, level, _, _ := CalculateRankAndLevel(goldSeals)
	return FormatRankTitle(rank.Name, rank.Quality, level)
}
