package mapmodule

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"
	"github.com/lib/pq"
)

type Repository interface {
	BeginTx(ctx context.Context) (*sqlx.Tx, error)
	WithTx(tx *sqlx.Tx) Repository

	// Task CRUD
	CreateTask(ctx context.Context, task *Task) error
	GetTaskByID(ctx context.Context, taskID string) (*Task, error)
	GetMyTasks(ctx context.Context, userID string) ([]Task, error)
	GetTasksNearby(ctx context.Context, userID string, lat, lon, radiusMeters float64, limit int) ([]Task, error)
	GetAppliedTasks(ctx context.Context, applicantID string) ([]Task, error)
	GetLastTaskCreatedAt(ctx context.Context, userID string) (*time.Time, error)
	CancelTask(ctx context.Context, taskID, creatorID string) (bool, error)
	GetOpenTasksForShutdown(ctx context.Context) ([]Task, error)

	// Task applications
	CreateTaskApplication(ctx context.Context, app *TaskApplication) error
	GetApplicationByID(ctx context.Context, applicationID string) (*TaskApplication, error)
	GetApplicationsByTaskID(ctx context.Context, taskID string) ([]TaskApplication, error)
	DeleteApplication(ctx context.Context, applicationID string) (bool, error)
	MarkApplicationAccepted(ctx context.Context, applicationID string) (bool, error)
	MarkApplicationRejected(ctx context.Context, applicationID string) (bool, error)
	MarkApplicationCodeVerified(ctx context.Context, applicationID string) (bool, error)
	MarkApplicationConfirmed(ctx context.Context, applicationID string) (bool, error)
	IncrementWorkersFilled(ctx context.Context, taskID string) error

	// Legacy — removed in Phase 3 service refactor
	MarkTaskCompleted(ctx context.Context, taskID, completedBy string) (bool, error)

	// User region
	UpdateUserRegion(ctx context.Context, userID string, h3Res5, h3Res4, h3Res2 *string, participateDistrict, locationOptIn bool) error

	// Champions
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
			id, title, description, reward, creator_id, location, is_active,
			workers_needed, verification_code, auto_shutdown_at, status,
			h3_res5, h3_res4, h3_res2, created_at, updated_at
		) VALUES (
			$1, $2, $3, $4, $5,
			ST_SetSRID(ST_MakePoint($6, $7), 4326),
			$8, $9, $10, $11, $12, $13, $14, $15, NOW(), NOW()
		)
	`
	_, err := r.executor().ExecContext(ctx, query,
		task.ID,
		task.Title,
		nullString(task.Description),
		task.Reward,
		task.CreatorID,
		task.Longitude,
		task.Latitude,
		task.IsActive,
		task.WorkersNeeded,
		task.VerificationCode,
		task.AutoShutdownAt,
		task.Status,
		task.H3Res5,
		task.H3Res4,
		task.H3Res2,
	)
	if err != nil {
		return fmt.Errorf("failed to create task: %w", err)
	}
	return nil
}

func (r *repository) GetTaskByID(ctx context.Context, taskID string) (*Task, error) {
	query := `
		SELECT id, title, description, reward, creator_id,
		       ST_Y(location) AS latitude,
		       ST_X(location) AS longitude,
		       workers_needed, workers_filled, verification_code, status, auto_shutdown_at,
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

// MarkTaskCompleted is the legacy single-actor completion path.
// Deprecated: replaced by the multi-actor flow in Phase 3.
func (r *repository) MarkTaskCompleted(ctx context.Context, taskID, completedBy string) (bool, error) {
	query := `
		UPDATE tasks
		SET is_active = false,
		    status = 'completed',
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

func (r *repository) GetMyTasks(ctx context.Context, userID string) ([]Task, error) {
	query := `
		SELECT id, title, description, reward, creator_id,
		       ST_Y(location) AS latitude,
		       ST_X(location) AS longitude,
		       workers_needed, workers_filled, verification_code, status, auto_shutdown_at,
		       is_active, completed_by, completed_at,
		       h3_res5, h3_res4, h3_res2, created_at, updated_at
		FROM tasks
		WHERE creator_id = $1
		ORDER BY created_at DESC
	`
	var tasks []Task
	if err := sqlx.SelectContext(ctx, r.executor(), &tasks, query, userID); err != nil {
		return nil, fmt.Errorf("failed to fetch my tasks: %w", err)
	}
	return tasks, nil
}

func (r *repository) GetTasksNearby(ctx context.Context, userID string, lat, lon, radiusMeters float64, limit int) ([]Task, error) {
	query := `
		SELECT id, title, description, reward, creator_id,
		       ST_Y(location) AS latitude,
		       ST_X(location) AS longitude,
		       workers_needed, workers_filled, status, auto_shutdown_at,
		       h3_res5, h3_res4, h3_res2, created_at, updated_at
		FROM tasks
		WHERE status = 'open'
		  AND (auto_shutdown_at IS NULL OR auto_shutdown_at > NOW())
		  AND creator_id != $1
		  AND id NOT IN (
			  SELECT task_id FROM task_applications WHERE applicant_id = $1 AND status != 'rejected'
		  )
		  AND ST_DWithin(
		      location::geography,
		      ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography,
		      $4
		  )
		ORDER BY created_at DESC
		LIMIT $5
	`
	var tasks []Task
	if err := sqlx.SelectContext(ctx, r.executor(), &tasks, query, userID, lon, lat, radiusMeters, limit); err != nil {
		return nil, fmt.Errorf("failed to fetch nearby tasks: %w", err)
	}
	return tasks, nil
}

func (r *repository) GetAppliedTasks(ctx context.Context, applicantID string) ([]Task, error) {
	query := `
		SELECT t.id, t.title, t.description, t.reward, t.creator_id,
		       ST_Y(t.location) AS latitude,
		       ST_X(t.location) AS longitude,
		       t.workers_needed, t.workers_filled, t.status, t.auto_shutdown_at,
		       t.h3_res5, t.h3_res4, t.h3_res2, t.created_at, t.updated_at
		FROM tasks t
		JOIN task_applications ta ON t.id = ta.task_id
		WHERE ta.applicant_id = $1 AND ta.status != 'rejected'
		ORDER BY ta.created_at DESC
	`
	var tasks []Task
	if err := sqlx.SelectContext(ctx, r.executor(), &tasks, query, applicantID); err != nil {
		return nil, fmt.Errorf("failed to fetch applied tasks: %w", err)
	}
	return tasks, nil
}

// GetLastTaskCreatedAt returns the creation time of the most recent task by userID.
// Returns nil (no error) if the user has never created a task.
func (r *repository) GetLastTaskCreatedAt(ctx context.Context, userID string) (*time.Time, error) {
	query := `
		SELECT created_at FROM tasks
		WHERE creator_id = $1
		ORDER BY created_at DESC
		LIMIT 1
	`
	var t time.Time
	err := sqlx.GetContext(ctx, r.executor(), &t, query, userID)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get last task created_at: %w", err)
	}
	return &t, nil
}

// CancelTask sets a task to 'cancelled'.
// Only succeeds if the caller is the creator, the task is 'open', and no workers have been filled yet.
// Returns true if the task was actually cancelled.
func (r *repository) CancelTask(ctx context.Context, taskID, creatorID string) (bool, error) {
	query := `
		UPDATE tasks
		SET status = 'cancelled',
		    is_active = false,
		    updated_at = NOW()
		WHERE id = $1
		  AND creator_id = $2
		  AND status = 'open'
		  AND workers_filled = 0
	`
	res, err := r.executor().ExecContext(ctx, query, taskID, creatorID)
	if err != nil {
		return false, fmt.Errorf("failed to cancel task: %w", err)
	}
	rows, err := res.RowsAffected()
	if err != nil {
		return false, fmt.Errorf("failed to get rows affected: %w", err)
	}
	return rows > 0, nil
}

// GetOpenTasksForShutdown returns all open tasks whose auto_shutdown_at has passed.
// Used by the worker to trigger automatic cancellation.
func (r *repository) GetOpenTasksForShutdown(ctx context.Context) ([]Task, error) {
	query := `
		SELECT id, title, reward, creator_id,
		       ST_Y(location) AS latitude,
		       ST_X(location) AS longitude,
		       workers_needed, workers_filled, status,
		       h3_res5, h3_res4, h3_res2, created_at, updated_at
		FROM tasks
		WHERE status = 'open'
		  AND auto_shutdown_at IS NOT NULL
		  AND auto_shutdown_at <= NOW()
		  AND NOT EXISTS (
			  SELECT 1 FROM task_applications ta
			  WHERE ta.task_id = tasks.id
		  )
	`
	var tasks []Task
	if err := sqlx.SelectContext(ctx, r.executor(), &tasks, query); err != nil {
		return nil, fmt.Errorf("failed to fetch tasks for auto-shutdown: %w", err)
	}
	return tasks, nil
}

// ─── Task Applications ────────────────────────────────────────────────────────

func (r *repository) CreateTaskApplication(ctx context.Context, app *TaskApplication) error {
	query := `
		INSERT INTO task_applications (
			id, task_id, applicant_id, status, created_at, updated_at
		) VALUES ($1, $2, $3, 'pending', NOW(), NOW())
	`
	_, err := r.executor().ExecContext(ctx, query, app.ID, app.TaskID, app.ApplicantID)
	if err != nil {
		return fmt.Errorf("failed to create task application: %w", err)
	}
	return nil
}

func (r *repository) GetApplicationByID(ctx context.Context, applicationID string) (*TaskApplication, error) {
	query := `
		SELECT id, task_id, applicant_id, status,
		       code_submitted_at, confirmed_at, created_at, updated_at
		FROM task_applications
		WHERE id = $1
	`
	var app TaskApplication
	err := sqlx.GetContext(ctx, r.executor(), &app, query, applicationID)
	if err == sql.ErrNoRows {
		return nil, ErrApplicationNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get application: %w", err)
	}
	return &app, nil
}

func (r *repository) GetApplicationsByTaskID(ctx context.Context, taskID string) ([]TaskApplication, error) {
	query := `
		SELECT id, task_id, applicant_id, status,
		       code_submitted_at, confirmed_at, created_at, updated_at
		FROM task_applications
		WHERE task_id = $1
		ORDER BY created_at ASC
	`
	var apps []TaskApplication
	if err := sqlx.SelectContext(ctx, r.executor(), &apps, query, taskID); err != nil {
		return nil, fmt.Errorf("failed to get applications for task: %w", err)
	}
	return apps, nil
}

// DeleteApplication physically removes an application record from the database.
// Returns true if a row was actually deleted.
func (r *repository) DeleteApplication(ctx context.Context, applicationID string) (bool, error) {
	query := `DELETE FROM task_applications WHERE id = $1`
	res, err := r.db.ExecContext(ctx, query, applicationID)
	if err != nil {
		return false, fmt.Errorf("failed to delete application: %w", err)
	}
	rowsAffected, err := res.RowsAffected()
	if err != nil {
		return false, err
	}
	return rowsAffected > 0, nil
}

// MarkApplicationAccepted transitions a pending application to accepted.
// Returns true if the row was actually updated.
func (r *repository) MarkApplicationAccepted(ctx context.Context, applicationID string) (bool, error) {
	query := `
		UPDATE task_applications
		SET status = 'accepted',
		    updated_at = NOW()
		WHERE id = $1 AND status = 'pending'
	`
	res, err := r.executor().ExecContext(ctx, query, applicationID)
	if err != nil {
		return false, fmt.Errorf("failed to mark application accepted: %w", err)
	}
	rows, err := res.RowsAffected()
	if err != nil {
		return false, fmt.Errorf("failed to get rows affected: %w", err)
	}
	return rows > 0, nil
}

// MarkApplicationRejected transitions a pending application to rejected.
// Returns true if the row was actually updated.
func (r *repository) MarkApplicationRejected(ctx context.Context, applicationID string) (bool, error) {
	query := `
		UPDATE task_applications
		SET status = 'rejected',
		    updated_at = NOW()
		WHERE id = $1 AND status = 'pending'
	`
	res, err := r.executor().ExecContext(ctx, query, applicationID)
	if err != nil {
		return false, fmt.Errorf("failed to mark application rejected: %w", err)
	}
	rows, err := res.RowsAffected()
	if err != nil {
		return false, fmt.Errorf("failed to get rows affected: %w", err)
	}
	return rows > 0, nil
}

// MarkApplicationCodeVerified transitions an accepted application to code_verified.
// Returns true if the row was actually updated.
func (r *repository) MarkApplicationCodeVerified(ctx context.Context, applicationID string) (bool, error) {
	query := `
		UPDATE task_applications
		SET status = 'code_verified',
		    code_submitted_at = NOW(),
		    updated_at = NOW()
		WHERE id = $1 AND status = 'accepted'
	`
	res, err := r.executor().ExecContext(ctx, query, applicationID)
	if err != nil {
		return false, fmt.Errorf("failed to mark application code verified: %w", err)
	}
	rows, err := res.RowsAffected()
	if err != nil {
		return false, fmt.Errorf("failed to get rows affected: %w", err)
	}
	return rows > 0, nil
}

// MarkApplicationConfirmed transitions a code_verified application to confirmed.
// Returns true if the row was actually updated.
func (r *repository) MarkApplicationConfirmed(ctx context.Context, applicationID string) (bool, error) {
	query := `
		UPDATE task_applications
		SET status = 'confirmed',
		    confirmed_at = NOW(),
		    updated_at = NOW()
		WHERE id = $1 AND status = 'code_verified'
	`
	res, err := r.executor().ExecContext(ctx, query, applicationID)
	if err != nil {
		return false, fmt.Errorf("failed to mark application confirmed: %w", err)
	}
	rows, err := res.RowsAffected()
	if err != nil {
		return false, fmt.Errorf("failed to get rows affected: %w", err)
	}
	return rows > 0, nil
}

// IncrementWorkersFilled atomically increments workers_filled.
// When workers_filled reaches workers_needed the task status transitions to 'completed'.
func (r *repository) IncrementWorkersFilled(ctx context.Context, taskID string) error {
	query := `
		UPDATE tasks
		SET workers_filled = workers_filled + 1,
		    status = CASE
		        WHEN workers_filled + 1 >= workers_needed THEN 'completed'
		        ELSE status
		    END,
		    is_active = CASE
		        WHEN workers_filled + 1 >= workers_needed THEN false
		        ELSE is_active
		    END,
		    updated_at = NOW()
		WHERE id = $1
		  AND status IN ('open', 'in_progress')
		  AND workers_filled < workers_needed
	`
	_, err := r.executor().ExecContext(ctx, query, taskID)
	if err != nil {
		return fmt.Errorf("failed to increment workers_filled: %w", err)
	}
	return nil
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

// ─── Helpers ──────────────────────────────────────────────────────────────────

func nullString(s *string) sql.NullString {
	if s == nil || *s == "" {
		return sql.NullString{Valid: false}
	}
	return sql.NullString{String: *s, Valid: true}
}
