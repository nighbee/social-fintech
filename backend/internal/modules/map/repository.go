package mapmodule

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/jmoiron/sqlx"
	"github.com/lib/pq"
)

type Repository interface {
	BeginTx(ctx context.Context) (*sqlx.Tx, error)
	WithTx(tx *sqlx.Tx) Repository

	CreateTask(ctx context.Context, task *Task) error
	GetTaskByID(ctx context.Context, taskID string) (*Task, error)
	MarkTaskCompleted(ctx context.Context, taskID, completedBy string) (bool, error)
	GetTasksNearby(ctx context.Context, lat, lon, radiusMeters float64, limit int) ([]Task, error)
	UpdateUserRegion(ctx context.Context, userID string, h3Res5, h3Res4, h3Res2 *string, participateDistrict, locationOptIn bool) error

	UpsertRegionChampion(ctx context.Context, champion *RegionChampion) error
	GetRegionChampions(ctx context.Context, h3Indexes []string, resolution, year, week int) ([]RegionChampion, error)
}

type repository struct {
	db *sqlx.DB
	tx *sqlx.Tx
}

func NewRepository(db *sqlx.DB) Repository {
	return &repository{db: db}
}

func (r *repository) BeginTx(ctx context.Context) (*sqlx.Tx, error) {
	return r.db.BeginTxx(ctx, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
}

func (r *repository) WithTx(tx *sqlx.Tx) Repository {
	return &repository{db: r.db, tx: tx}
}

func (r *repository) executor() sqlx.ExtContext {
	if r.tx != nil {
		return r.tx
	}
	return r.db
}

func (r *repository) CreateTask(ctx context.Context, task *Task) error {
	query := `
		INSERT INTO tasks (
			id, title, reward, creator_id, location, is_active,
			h3_res5, h3_res4, h3_res2, created_at, updated_at
		) VALUES (
			$1, $2, $3, $4,
			ST_SetSRID(ST_MakePoint($5, $6), 4326),
			$7, $8, $9, $10, NOW(), NOW()
		)
	`

	_, err := r.executor().ExecContext(ctx, query,
		task.ID, task.Title, task.Reward, task.CreatorID,
		task.Longitude, task.Latitude, task.IsActive,
		task.H3Res5, task.H3Res4, task.H3Res2,
	)
	if err != nil {
		return fmt.Errorf("failed to create task: %w", err)
	}
	return nil
}

func (r *repository) GetTaskByID(ctx context.Context, taskID string) (*Task, error) {
	query := `
		SELECT id, title, reward, creator_id,
		       ST_Y(location) AS latitude,
		       ST_X(location) AS longitude,
		       is_active, completed_by, completed_at,
		       h3_res5, h3_res4, h3_res2, created_at, updated_at
		FROM tasks
		WHERE id = $1
	`

	var task Task
	err := sqlx.GetContext(ctx, r.executor(), &task, query, taskID)
	if err == sql.ErrNoRows {
		return nil, ErrTaskNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get task: %w", err)
	}
	return &task, nil
}

func (r *repository) MarkTaskCompleted(ctx context.Context, taskID, completedBy string) (bool, error) {
	query := `
		UPDATE tasks
		SET is_active = false,
		    completed_by = $1,
		    completed_at = NOW(),
		    updated_at = NOW()
		WHERE id = $2 AND is_active = true
	`

	res, err := r.executor().ExecContext(ctx, query, completedBy, taskID)
	if err != nil {
		return false, fmt.Errorf("failed to mark task completed: %w", err)
	}
	rows, err := res.RowsAffected()
	if err != nil {
		return false, fmt.Errorf("failed to get rows affected: %w", err)
	}
	return rows > 0, nil
}

func (r *repository) GetTasksNearby(ctx context.Context, lat, lon, radiusMeters float64, limit int) ([]Task, error) {
	query := `
		SELECT id, title, reward, creator_id,
		       ST_Y(location) AS latitude,
		       ST_X(location) AS longitude,
		       is_active, h3_res5, h3_res4, h3_res2, created_at, updated_at
		FROM tasks
		WHERE is_active = true
		  AND ST_DWithin(
		      location::geography,
		      ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
		      $3
		  )
		ORDER BY created_at DESC
		LIMIT $4
	`

	var tasks []Task
	if err := sqlx.SelectContext(ctx, r.executor(), &tasks, query, lon, lat, radiusMeters, limit); err != nil {
		return nil, fmt.Errorf("failed to fetch nearby tasks: %w", err)
	}
	return tasks, nil
}

func (r *repository) UpdateUserRegion(ctx context.Context, userID string, h3Res5, h3Res4, h3Res2 *string, participateDistrict, locationOptIn bool) error {
	query := `
		UPDATE users
		SET h3_res5 = $1,
		    h3_res4 = $2,
		    h3_res2 = $3,
		    participate_district = $4,
		    location_opt_in = $5,
		    location_updated_at = NOW()
		WHERE id = $6
	`

	_, err := r.executor().ExecContext(ctx, query,
		nullString(h3Res5),
		nullString(h3Res4),
		nullString(h3Res2),
		participateDistrict,
		locationOptIn,
		userID,
	)
	if err != nil {
		return fmt.Errorf("failed to update user region: %w", err)
	}
	return nil
}

func (r *repository) UpsertRegionChampion(ctx context.Context, champion *RegionChampion) error {
	query := `
		INSERT INTO region_champions (
			id, h3_index, resolution, user_id, score, week, year, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
		ON CONFLICT (h3_index, resolution, week, year)
		DO UPDATE SET
			user_id = EXCLUDED.user_id,
			score = EXCLUDED.score,
			updated_at = NOW()
	`

	_, err := r.executor().ExecContext(ctx, query,
		champion.ID, champion.H3Index, champion.Resolution, champion.UserID,
		champion.Score, champion.Week, champion.Year,
	)
	if err != nil {
		return fmt.Errorf("failed to upsert region champion: %w", err)
	}
	return nil
}

func (r *repository) GetRegionChampions(ctx context.Context, h3Indexes []string, resolution, year, week int) ([]RegionChampion, error) {
	query := `
		SELECT id, h3_index, resolution, user_id, score, week, year, updated_at
		FROM region_champions
		WHERE resolution = $1
		  AND year = $2
		  AND week = $3
		  AND h3_index = ANY($4)
	`

	var champs []RegionChampion
	if err := sqlx.SelectContext(ctx, r.executor(), &champs, query, resolution, year, week, pq.Array(h3Indexes)); err != nil {
		return nil, fmt.Errorf("failed to get region champions: %w", err)
	}
	return champs, nil
}

func nullString(s *string) sql.NullString {
	if s == nil || *s == "" {
		return sql.NullString{Valid: false}
	}
	return sql.NullString{String: *s, Valid: true}
}
