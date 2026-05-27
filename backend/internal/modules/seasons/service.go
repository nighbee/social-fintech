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

func (s *Service) ListAllSeasons(ctx context.Context) (*AdminSeasonsListResponse, error) {
	seasons, err := s.repo.ListAllSeasons(ctx)
	if err != nil {
		return nil, fmt.Errorf("seasons: list all: %w", err)
	}

	out := make([]AdminSeasonInfo, 0, len(seasons))
	for _, season := range seasons {
		count, _ := s.repo.CountParticipants(ctx, season.ID)
		out = append(out, AdminSeasonInfo{
			Season:       season,
			IsClosed:     season.ClosedAt != nil,
			Participants: count,
		})
	}

	return &AdminSeasonsListResponse{Seasons: out}, nil
}

func (s *Service) ForceCloseSeason(ctx context.Context, seasonID uuid.UUID, snap SnapshotProvider) (*AdminForceCloseResponse, error) {
	seasons, err := s.repo.ListAllSeasons(ctx)
	if err != nil {
		return nil, err
	}

	var found *Season
	for i := range seasons {
		if seasons[i].ID == seasonID {
			found = &seasons[i]
			break
		}
	}
	if found == nil {
		return nil, fmt.Errorf("seasons: season %s not found", seasonID)
	}
	if found.ClosedAt != nil {
		return nil, fmt.Errorf("seasons: season %s is already closed", seasonID)
	}

	archived := 0
	if snap != nil {
		rows, snapErr := snap.SnapshotSeason(ctx, found)
		if snapErr != nil {
			return nil, snapErr
		}
		for j := range rows {
			rows[j].SeasonID = found.ID
			rows[j].SeasonYear = found.SeasonYear
			rows[j].SeasonHalf = found.SeasonHalf
			if err := s.repo.UpsertArchive(ctx, &rows[j]); err != nil {
				return nil, err
			}
		}
		archived = len(rows)
	}

	if s.goldResetter != nil {
		if _, resetErr := s.goldResetter.ResetAllGoldSeals(ctx); resetErr != nil {
			return nil, fmt.Errorf("seasons: gold seal reset failed: %w", resetErr)
		}
	}

	if err := s.repo.MarkClosed(ctx, seasonID, time.Now().UTC()); err != nil {
		return nil, err
	}

	if s.eventBus != nil {
		_ = s.eventBus.Publish(ctx, eventbus.TypeSeasonResult, eventbus.LeaderboardEvent{
			BaseEvent: eventbus.BaseEvent{
				Type:      eventbus.TypeSeasonResult,
				Timestamp: time.Now(),
			},
			SeasonID: seasonID.String(),
			Scope:    fmt.Sprintf("season_%d_%d", found.SeasonYear, found.SeasonHalf),
		})
	}

	return &AdminForceCloseResponse{
		SeasonID:      seasonID.String(),
		ArchivedUsers: archived,
	}, nil
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
