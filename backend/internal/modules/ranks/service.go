package ranks

import (
	"context"
	"fmt"
)

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) GetAllRanks(ctx context.Context) (*RankListResponse, error) {
	ranksWithLevels := GetAllRanksWithLevels()
	return &RankListResponse{
		Ranks: ranksWithLevels,
	}, nil
}

func (s *Service) GetCurrentRank(ctx context.Context, goldSeals int) (*CurrentRankResponse, error) {
	if goldSeals < 0 {
		return nil, ErrInvalidSeals
	}

	rank, level, levelMin, levelMax := CalculateRankAndLevel(goldSeals)

	progressInRank := 0.0
	rangeSize := rank.MaxSeals - rank.MinSeals
	if rangeSize > 0 {
		sealsInRank := goldSeals - rank.MinSeals
		progressInRank = (float64(sealsInRank) / float64(rangeSize)) * 100
	}

	progressToNextLevel := 0.0
	levelRange := levelMax - levelMin
	if levelRange > 0 {
		sealsInLevel := goldSeals - levelMin
		progressToNextLevel = (float64(sealsInLevel) / float64(levelRange)) * 100
	}

	nextLevel := ""
	nextRank := ""

	switch level {
	case "C":
		nextLevel = "B"
	case "B":
		nextLevel = "A"
	case "A":
		nextLevel = "S"
	case "S":
		if rank.Order < len(RankCatalog) {
			nextRank = RankCatalog[rank.Order].Name
		}
	}

	return &CurrentRankResponse{
		RankName:            rank.Name,
		QualityName:         rank.Quality,
		Level:               level,
		FullTitle:           FormatRankTitle(rank.Name, rank.Quality, level),
		IconURL:             rank.IconURL,
		CurrentSeals:        goldSeals,
		RankMinSeals:        rank.MinSeals,
		RankMaxSeals:        rank.MaxSeals,
		LevelMinSeals:       levelMin,
		LevelMaxSeals:       levelMax,
		NextLevel:           nextLevel,
		NextRank:            nextRank,
		ProgressToNextLevel: progressToNextLevel,
		ProgressInRank:      progressInRank,
		Description:         rank.Description,
	}, nil
}

func (s *Service) GetRankTierString(goldSeals int) string {
	rank, level, _, _ := CalculateRankAndLevel(goldSeals)
	return FormatRankTitle(rank.Name, rank.Quality, level)
}

func (s *Service) GetMyRank(ctx context.Context, userID string) (*CurrentRankResponse, error) {
	goldSeals, err := s.repo.GetUserGoldSeals(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get user gold seals: %w", err)
	}

	return s.GetCurrentRank(ctx, goldSeals)
}
