package seasons

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

type Repository interface {
	GetOrCreateSeason(ctx context.Context, year, half int) (*Season, error)
	ListUnclosedDueSeasons(ctx context.Context, now time.Time) ([]Season, error)
	ListAllSeasons(ctx context.Context) ([]Season, error)
	CountParticipants(ctx context.Context, seasonID uuid.UUID) (int64, error)
	MarkClosed(ctx context.Context, seasonID uuid.UUID, closedAt time.Time) error
	UpsertArchive(ctx context.Context, item *ArchiveItem) error
	ListArchiveByUser(ctx context.Context, userID uuid.UUID, limit int) ([]ArchiveItem, error)
}

type PostgresRepository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *PostgresRepository {
	return &PostgresRepository{db: db}
}

// GetOrCreateSeason returns the season row for (year, half), creating it
// if missing so callers don't have to special-case the bootstrap path.
func (r *PostgresRepository) GetOrCreateSeason(ctx context.Context, year, half int) (*Season, error) {
	if half != 1 && half != 2 {
		return nil, errors.New("seasons: half must be 1 or 2")
	}

	var existing Season
	err := r.db.GetContext(ctx, &existing, `
		SELECT id, season_year, season_half, starts_at, ends_at, closed_at, created_at
		FROM seasons
		WHERE season_year = $1 AND season_half = $2
	`, year, half)
	if err == nil {
		return &existing, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return nil, err
	}

	starts, ends := SeasonWindow(year, half)
	id := uuid.New()
	if _, err := r.db.ExecContext(ctx, `
		INSERT INTO seasons (id, season_year, season_half, starts_at, ends_at, created_at)
		VALUES ($1, $2, $3, $4, $5, NOW())
		ON CONFLICT (season_year, season_half) DO NOTHING
	`, id, year, half, starts, ends); err != nil {
		return nil, err
	}

	if err := r.db.GetContext(ctx, &existing, `
		SELECT id, season_year, season_half, starts_at, ends_at, closed_at, created_at
		FROM seasons
		WHERE season_year = $1 AND season_half = $2
	`, year, half); err != nil {
		return nil, err
	}
	return &existing, nil
}

// ListUnclosedDueSeasons returns every season whose ends_at is in the
// past and that hasn't been closed yet.
func (r *PostgresRepository) ListUnclosedDueSeasons(ctx context.Context, now time.Time) ([]Season, error) {
	var out []Season
	err := r.db.SelectContext(ctx, &out, `
		SELECT id, season_year, season_half, starts_at, ends_at, closed_at, created_at
		FROM seasons
		WHERE closed_at IS NULL AND ends_at <= $1
		ORDER BY ends_at ASC
	`, now)
	return out, err
}

func (r *PostgresRepository) ListAllSeasons(ctx context.Context) ([]Season, error) {
	var out []Season
	err := r.db.SelectContext(ctx, &out, `
		SELECT id, season_year, season_half, starts_at, ends_at, closed_at, created_at
		FROM seasons
		ORDER BY season_year DESC, season_half DESC
	`)
	return out, err
}

func (r *PostgresRepository) CountParticipants(ctx context.Context, seasonID uuid.UUID) (int64, error) {
	var count int64
	err := r.db.GetContext(ctx, &count, `
		SELECT COUNT(*) FROM user_season_archive WHERE season_id = $1
	`, seasonID)
	return count, err
}

func (r *PostgresRepository) MarkClosed(ctx context.Context, seasonID uuid.UUID, closedAt time.Time) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE seasons SET closed_at = $2 WHERE id = $1
	`, seasonID, closedAt)
	return err
}

func (r *PostgresRepository) UpsertArchive(ctx context.Context, item *ArchiveItem) error {
	payload := []byte(item.SnapshotPayload)
	if len(payload) == 0 {
		payload = []byte("{}")
	}
	var positionArg interface{}
	if item.FinalPosition != nil {
		positionArg = *item.FinalPosition
	}
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO user_season_archive (
			user_id, season_id, season_year, season_half,
			final_position, seal_count, region, scope, snapshot_payload
		) VALUES ($1, $2, $3, $4, $5, $6, NULLIF($7, ''), NULLIF($8, ''), $9::jsonb)
		ON CONFLICT (user_id, season_id) DO UPDATE SET
			final_position   = EXCLUDED.final_position,
			seal_count       = EXCLUDED.seal_count,
			region           = EXCLUDED.region,
			scope            = EXCLUDED.scope,
			snapshot_payload = EXCLUDED.snapshot_payload
	`,
		item.UserID, item.SeasonID, item.SeasonYear, item.SeasonHalf,
		positionArg, item.SealCount, item.Region, item.Scope, string(payload),
	)
	return err
}

func (r *PostgresRepository) ListArchiveByUser(ctx context.Context, userID uuid.UUID, limit int) ([]ArchiveItem, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}

	type row struct {
		SeasonID        uuid.UUID       `db:"season_id"`
		SeasonYear      int             `db:"season_year"`
		SeasonHalf      int             `db:"season_half"`
		FinalPosition   sql.NullInt64   `db:"final_position"`
		SealCount       int64           `db:"seal_count"`
		Region          sql.NullString  `db:"region"`
		Scope           sql.NullString  `db:"scope"`
		SnapshotPayload json.RawMessage `db:"snapshot_payload"`
		StartsAt        time.Time       `db:"starts_at"`
		EndsAt          time.Time       `db:"ends_at"`
		CreatedAt       time.Time       `db:"created_at"`
	}

	var rows []row
	err := r.db.SelectContext(ctx, &rows, `
		SELECT
			a.season_id,
			a.season_year,
			a.season_half,
			a.final_position,
			a.seal_count,
			a.region,
			a.scope,
			a.snapshot_payload,
			s.starts_at,
			s.ends_at,
			a.created_at
		FROM user_season_archive a
		JOIN seasons s ON s.id = a.season_id
		WHERE a.user_id = $1
		ORDER BY a.season_year DESC, a.season_half DESC
		LIMIT $2
	`, userID, limit)
	if err != nil {
		return nil, err
	}

	out := make([]ArchiveItem, 0, len(rows))
	for _, r := range rows {
		item := ArchiveItem{
			SeasonID:        r.SeasonID,
			SeasonYear:      r.SeasonYear,
			SeasonHalf:      r.SeasonHalf,
			SealCount:       r.SealCount,
			SnapshotPayload: r.SnapshotPayload,
			StartsAt:        r.StartsAt,
			EndsAt:          r.EndsAt,
			CreatedAt:       r.CreatedAt,
		}
		if r.FinalPosition.Valid {
			pos := int(r.FinalPosition.Int64)
			item.FinalPosition = &pos
		}
		if r.Region.Valid {
			item.Region = r.Region.String
		}
		if r.Scope.Valid {
			item.Scope = r.Scope.String
		}
		out = append(out, item)
	}
	return out, nil
}
