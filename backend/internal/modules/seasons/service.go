package seasons

import (
	"context"
	"time"

	"github.com/google/uuid"
)

type Service struct {
	repo Repository
}

func NewService(repo Repository) *Service {
	return &Service{repo: repo}
}

// GetCurrentSeason returns the currently-active season, creating it on
// the fly if no row exists yet (e.g. first cold start of the year).
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

// GetUserArchive returns the user's archived season summaries, newest
// first. Empty result means the user has not lived through a closed
// season yet.
func (s *Service) GetUserArchive(ctx context.Context, userID uuid.UUID, limit int) (*ArchiveResponse, error) {
	items, err := s.repo.ListArchiveByUser(ctx, userID, limit)
	if err != nil {
		return nil, err
	}
	return &ArchiveResponse{Items: items}, nil
}

// CloseDueSeasons is the idempotent close-out worker. It is safe to run
// repeatedly: seasons already marked closed are skipped, and archive
// rows use ON CONFLICT updates so re-runs converge on the same state.
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
		}
		if err := s.repo.MarkClosed(ctx, season.ID, time.Now().UTC()); err != nil {
			return err
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
