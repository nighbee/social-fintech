package seasons

import (
	"context"
	"fmt"
	"time"

	"github.com/brightbund-backend/internal/platform/eventbus"
	"github.com/google/uuid"
)

type Service struct {
	repo           Repository
	eventBus       *eventbus.Producer
	goldResetter   GoldSealResetter
}

func NewService(repo Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) SetEventBus(eb *eventbus.Producer) {
	s.eventBus = eb
}

func (s *Service) SetGoldResetter(r GoldSealResetter) {
	s.goldResetter = r
}

func (s *Service) GetCurrentSeason(ctx context.Context, now time.Time) (*CurrentSeasonResponse, error) {
	year, half := SeasonForTime(now)
	season, err := s.repo.GetOrCreateSeason(ctx, year, half)
	if err != nil {
		return nil, err
	}
	remaining := int64(season.EndsAt.Sub(now).Seconds())
	if remaining < 0 {
		remaining = 0
	}
	return &CurrentSeasonResponse{
		Season:           *season,
		SecondsRemaining: remaining,
	}, nil
}

func (s *Service) GetUserArchive(ctx context.Context, userID uuid.UUID, limit int) (*ArchiveResponse, error) {
	items, err := s.repo.ListArchiveByUser(ctx, userID, limit)
	if err != nil {
		return nil, err
	}
	return &ArchiveResponse{Items: items}, nil
}

func (s *Service) CloseDueSeasons(ctx context.Context, now time.Time, snap SnapshotProvider) error {
	due, err := s.repo.ListUnclosedDueSeasons(ctx, now)
	if err != nil {
		return err
	}
	for _, season := range due {
		if snap != nil {
			rows, snapErr := snap.SnapshotSeason(ctx, &season)
			if snapErr != nil {
				return snapErr
			}
			for i := range rows {
				rows[i].SeasonID = season.ID
				rows[i].SeasonYear = season.SeasonYear
				rows[i].SeasonHalf = season.SeasonHalf
				if err := s.repo.UpsertArchive(ctx, &rows[i]); err != nil {
					return err
				}
			}

			if s.goldResetter != nil {
				resetCount, resetErr := s.goldResetter.ResetAllGoldSeals(ctx)
				if resetErr != nil {
					return fmt.Errorf("seasons: gold seal reset failed for season %s: %w", season.ID, resetErr)
				}
				_ = resetCount
			}
		}
		if err := s.repo.MarkClosed(ctx, season.ID, time.Now().UTC()); err != nil {
			return err
		}

		if s.eventBus != nil {
			_ = s.eventBus.Publish(ctx, eventbus.TypeSeasonResult, eventbus.LeaderboardEvent{
				BaseEvent: eventbus.BaseEvent{
					Type:      eventbus.TypeSeasonResult,
					Timestamp: time.Now(),
				},
				SeasonID: season.ID.String(),
				Scope:    fmt.Sprintf("season_%d_%d", season.SeasonYear, season.SeasonHalf),
			})
		}
	}
	return nil
}

// SnapshotProvider is implemented by callers that know how to compute
// per-user final standings for a season (typically by reading the
// economy / leaderboard tables). The seasons module does not own that
// data, so it depends on this small interface to stay decoupled.
type SnapshotProvider interface {
	SnapshotSeason(ctx context.Context, season *Season) ([]ArchiveItem, error)
}

// GoldSealResetter is implemented by the economy module to reset all
// GOLD_SEAL wallet balances and total_received_amount to zero when a
// season closes, effectively resetting ranks for the new season.
type GoldSealResetter interface {
	ResetAllGoldSeals(ctx context.Context) (int64, error)
}
