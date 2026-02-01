package profile

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/jmoiron/sqlx"
)

type Repository interface {
	BeginTx(ctx context.Context) (*sqlx.Tx, error)
	WithTx(tx *sqlx.Tx) Repository

	CreateProfile(ctx context.Context, profile *Profile) error
	GetProfileByUserID(ctx context.Context, userID string) (*Profile, error)
	GetProfileByUsername(ctx context.Context, username string) (*Profile, error)
	UpdateProfile(ctx context.Context, profile *Profile) error
	DeleteProfile(ctx context.Context, userID string) error
	ProfileExists(ctx context.Context, userID string) (bool, error)
	GetUserDetails(ctx context.Context, userID string) (*UserDetails, error)

	SearchProfiles(ctx context.Context, query string, limit, offset int) ([]*Profile, int, error)
	GetProfilesByUserIDs(ctx context.Context, userIDs []string) ([]*Profile, error)
	GetNearbyProfiles(ctx context.Context, lat, lon float64, radiusKm int, limit, offset int) ([]*Profile, int, error)

	UpdateProfileStats(ctx context.Context, userID string, stats *ProfileStats) error
	UpdateAvatarURL(ctx context.Context, userID string, avatarURL string) error
	UpdateReputation(ctx context.Context, userID, rankTier string, reputationScore int) error

	CreateRelationship(ctx context.Context, rel *UserRelationship) error
	GetRelationship(ctx context.Context, userID, targetUserID string, relType RelationshipType) (*UserRelationship, error)
	DeleteRelationship(ctx context.Context, userID, targetUserID string, relType RelationshipType) error
	GetUserRelationships(ctx context.Context, userID string, relType RelationshipType, limit, offset int) ([]*UserRelationship, int, error)
	CheckRelationshipExists(ctx context.Context, userID, targetUserID string, relType RelationshipType) (bool, error)
	GetMutualRelationships(ctx context.Context, userID, targetUserID string, relType RelationshipType) (bool, bool, error)
	CountRelationships(ctx context.Context, userID string, relType RelationshipType) (int, error)

	CreateReport(ctx context.Context, report *UserReport) error
	GetReportByID(ctx context.Context, id string) (*UserReport, error)
	UpdateReportStatus(ctx context.Context, id string, status ReportStatus, reviewedBy *string) error
	GetReportsByReporter(ctx context.Context, reporterID string, limit, offset int) ([]*UserReport, int, error)
	GetReportsByReported(ctx context.Context, reportedUserID string, limit, offset int) ([]*UserReport, int, error)
	CheckExistingReport(ctx context.Context, reporterID, reportedUserID string) (bool, error)
	GetPendingReports(ctx context.Context, limit, offset int) ([]*UserReport, int, error)
}

type repository struct {
	db *sqlx.DB
	tx *sqlx.Tx
}

func NewRepository(db *sqlx.DB) Repository {
	return &repository{db: db}
}

func (r *repository) BeginTx(ctx context.Context) (*sqlx.Tx, error) {
	return r.db.BeginTxx(ctx, &sql.TxOptions{
		Isolation: sql.LevelReadCommitted,
	})
}

func (r *repository) WithTx(tx *sqlx.Tx) Repository {
	return &repository{
		db: r.db,
		tx: tx,
	}
}

func (r *repository) getExecutor() sqlx.ExtContext {
	if r.tx != nil {
		return r.tx
	}
	return r.db
}

func (r *repository) CreateProfile(ctx context.Context, profile *Profile) error {
	query := `
		INSERT INTO profiles (
			user_id, display_name, avatar_url, bio, 
			location_city, location_country, location_lat, location_lon,
			is_location_public, is_profile_public,
			total_posts, total_gold_seals_received, total_silver_seals_given, tasks_completed,
			reputation_score, current_rank_tier, created_at, updated_at
		) VALUES (
			:user_id, :display_name, :avatar_url, :bio,
			:location_city, :location_country, :location_lat, :location_lon,
			:is_location_public, :is_profile_public,
			:total_posts, :total_gold_seals_received, :total_silver_seals_given, :tasks_completed,
			:reputation_score, :current_rank_tier, :created_at, :updated_at
		)
	`
	_, err := sqlx.NamedExecContext(ctx, r.getExecutor(), query, profile)
	return err
}

func (r *repository) GetProfileByUserID(ctx context.Context, userID string) (*Profile, error) {
	query := `
		SELECT 
			user_id, display_name, avatar_url, bio,
			location_city, location_country, CAST(location_lat AS FLOAT) as location_lat, CAST(location_lon AS FLOAT) as location_lon,
			is_location_public, is_profile_public,
			total_posts, total_gold_seals_received, total_silver_seals_given, tasks_completed,
			reputation_score, current_rank_tier, created_at, updated_at
		FROM profiles
		WHERE user_id = $1
	`
	var profile Profile
	err := sqlx.GetContext(ctx, r.getExecutor(), &profile, query, userID)
	if err == sql.ErrNoRows {
		return nil, ErrProfileNotFound
	}
	if err != nil {
		// Print error for debugging scan/mapping issues
		fmt.Printf("[DEBUG] GetProfileByUserID scan error for user_id=%s: %v\n", userID, err)
	}
	return &profile, err
}

func (r *repository) GetProfileByUsername(ctx context.Context, username string) (*Profile, error) {
	query := `
		SELECT 
			p.user_id, p.display_name, p.avatar_url, p.bio,
			p.location_city, p.location_country, CAST(p.location_lat AS FLOAT) as location_lat, CAST(p.location_lon AS FLOAT) as location_lon,
			p.is_location_public, p.is_profile_public,
			p.total_posts, p.total_gold_seals_received, p.total_silver_seals_given, p.tasks_completed,
			p.reputation_score, p.current_rank_tier, p.created_at, p.updated_at
		FROM profiles p
		JOIN users u ON p.user_id = u.id
		WHERE u.username = $1
	`
	var profile Profile
	err := sqlx.GetContext(ctx, r.getExecutor(), &profile, query, username)
	if err == sql.ErrNoRows {
		return nil, ErrProfileNotFound
	}
	return &profile, err
}

func (r *repository) UpdateProfile(ctx context.Context, profile *Profile) error {
	query := `
		UPDATE profiles SET
			display_name = :display_name,
			avatar_url = :avatar_url,
			bio = :bio,
			location_city = :location_city,
			location_country = :location_country,
			location_lat = :location_lat,
			location_lon = :location_lon,
			is_location_public = :is_location_public,
			is_profile_public = :is_profile_public,
			updated_at = :updated_at
		WHERE user_id = :user_id
	`
	result, err := sqlx.NamedExecContext(ctx, r.getExecutor(), query, profile)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrProfileNotFound
	}
	return nil
}

func (r *repository) DeleteProfile(ctx context.Context, userID string) error {
	query := `DELETE FROM profiles WHERE user_id = $1`
	result, err := r.getExecutor().ExecContext(ctx, query, userID)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrProfileNotFound
	}
	return nil
}

func (r *repository) ProfileExists(ctx context.Context, userID string) (bool, error) {
	query := `SELECT EXISTS(SELECT 1 FROM profiles WHERE user_id = $1)`
	var exists bool
	err := r.getExecutor().QueryRowxContext(ctx, query, userID).Scan(&exists)
	return exists, err
}

func (r *repository) GetUserDetails(ctx context.Context, userID string) (*UserDetails, error) {
	query := `SELECT username, first_name, last_name FROM users WHERE id = $1`
	var details UserDetails
	err := sqlx.GetContext(ctx, r.getExecutor(), &details, query, userID)
	if err == sql.ErrNoRows {
		return nil, ErrProfileNotFound
	}
	return &details, err
}

func (r *repository) SearchProfiles(ctx context.Context, query string, limit, offset int) ([]*Profile, int, error) {
	searchQuery := `
		SELECT 
			p.user_id, p.display_name, p.avatar_url, p.bio,
			p.location_city, p.location_country, CAST(p.location_lat AS FLOAT) as location_lat, CAST(p.location_lon AS FLOAT) as location_lon,
			p.is_location_public, p.is_profile_public,
			p.total_posts, p.total_gold_seals_received, p.total_silver_seals_given, p.tasks_completed,
			p.reputation_score, p.current_rank_tier, p.created_at, p.updated_at
		FROM profiles p
		JOIN users u ON p.user_id = u.id
		WHERE p.is_profile_public = true 
		  AND (u.username ILIKE $1 OR p.display_name ILIKE $1 OR p.bio ILIKE $1)
		ORDER BY p.reputation_score DESC, u.username
		LIMIT $2 OFFSET $3
	`
	countQuery := `
		SELECT COUNT(*)
		FROM profiles p
		JOIN users u ON p.user_id = u.id
		WHERE p.is_profile_public = true 
		  AND (u.username ILIKE $1 OR p.display_name ILIKE $1 OR p.bio ILIKE $1)
	`

	searchPattern := "%" + query + "%"
	var profiles []*Profile
	err := sqlx.SelectContext(ctx, r.getExecutor(), &profiles, searchQuery, searchPattern, limit, offset)
	if err != nil {
		return nil, 0, err
	}

	var total int
	err = r.getExecutor().QueryRowxContext(ctx, countQuery, searchPattern).Scan(&total)
	if err != nil {
		return nil, 0, err
	}

	return profiles, total, nil
}

func (r *repository) GetProfilesByUserIDs(ctx context.Context, userIDs []string) ([]*Profile, error) {
	if len(userIDs) == 0 {
		return []*Profile{}, nil
	}

	query, args, err := sqlx.In(`
		SELECT 
			user_id, display_name, avatar_url, bio,
			location_city, location_country, CAST(location_lat AS FLOAT) as location_lat, CAST(location_lon AS FLOAT) as location_lon,
			is_location_public, is_profile_public,
			total_posts, total_gold_seals_received, total_silver_seals_given, tasks_completed,
			reputation_score, current_rank_tier, created_at, updated_at
		FROM profiles
		WHERE user_id IN (?)
	`, userIDs)
	if err != nil {
		return nil, err
	}

	query = r.db.Rebind(query)
	var profiles []*Profile
	err = sqlx.SelectContext(ctx, r.getExecutor(), &profiles, query, args...)
	return profiles, err
}

func (r *repository) GetNearbyProfiles(ctx context.Context, lat, lon float64, radiusKm int, limit, offset int) ([]*Profile, int, error) {
	searchQuery := `
		SELECT 
			user_id, display_name, avatar_url, bio,
			location_city, location_country, CAST(location_lat AS FLOAT) as location_lat, CAST(location_lon AS FLOAT) as location_lon,
			is_location_public, is_profile_public,
			total_posts, total_gold_seals_received, total_silver_seals_given, tasks_completed,
			reputation_score, current_rank_tier, created_at, updated_at,
			ST_Distance(
				ST_SetSRID(ST_MakePoint(location_lon, location_lat), 4326)::geography,
				ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
			) / 1000 as distance_km
		FROM profiles
		WHERE is_profile_public = true 
		  AND location_lat IS NOT NULL 
		  AND location_lon IS NOT NULL
		  AND ST_DWithin(
				ST_SetSRID(ST_MakePoint(location_lon, location_lat), 4326)::geography,
				ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
				$3 * 1000
			)
		ORDER BY ST_SetSRID(ST_MakePoint(location_lon, location_lat), 4326) <-> ST_SetSRID(ST_MakePoint($1, $2), 4326)
		LIMIT $4 OFFSET $5
	`
	countQuery := `
		SELECT COUNT(*)
		FROM profiles
		WHERE is_profile_public = true 
		  AND location_lat IS NOT NULL 
		  AND location_lon IS NOT NULL
		  AND ST_DWithin(
				ST_SetSRID(ST_MakePoint(location_lon, location_lat), 4326)::geography,
				ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
				$3 * 1000
			)
	`

	var profiles []*Profile
	err := sqlx.SelectContext(ctx, r.getExecutor(), &profiles, searchQuery, lon, lat, radiusKm, limit, offset)
	if err != nil {
		return nil, 0, err
	}

	var total int
	err = r.getExecutor().QueryRowxContext(ctx, countQuery, lon, lat, radiusKm).Scan(&total)
	if err != nil {
		return nil, 0, err
	}

	return profiles, total, nil
}

func (r *repository) UpdateProfileStats(ctx context.Context, userID string, stats *ProfileStats) error {
	query := `
		UPDATE profiles SET
			total_posts = $1,
			total_gold_seals_received = $2,
			total_silver_seals_given = $3,
			tasks_completed = $4,
			reputation_score = $5,
			updated_at = NOW()
		WHERE user_id = $6
	`
	result, err := r.getExecutor().ExecContext(ctx, query,
		stats.TotalPosts, stats.TotalGoldSealsReceived,
		stats.TotalSilverSealsGiven, stats.TasksCompleted,
		stats.ReputationScore, userID)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrProfileNotFound
	}
	return nil
}

func (r *repository) UpdateAvatarURL(ctx context.Context, userID string, avatarURL string) error {
	query := `UPDATE profiles SET avatar_url = $1, updated_at = NOW() WHERE user_id = $2`
	result, err := r.getExecutor().ExecContext(ctx, query, avatarURL, userID)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrProfileNotFound
	}
	return nil
}

func (r *repository) UpdateReputation(ctx context.Context, userID, rankTier string, reputationScore int) error {
	query := `
		UPDATE profiles SET 
			reputation_score = $1, 
			current_rank_tier = $2, 
			updated_at = NOW() 
		WHERE user_id = $3
	`
	result, err := r.getExecutor().ExecContext(ctx, query, reputationScore, rankTier, userID)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrProfileNotFound
	}
	return nil
}

func (r *repository) CreateRelationship(ctx context.Context, rel *UserRelationship) error {
	query := `
		INSERT INTO user_relationships (
			id, user_id, target_user_id, relationship_type, created_at
		) VALUES (
			:id, :user_id, :target_user_id, :relationship_type, :created_at
		)
	`
	_, err := sqlx.NamedExecContext(ctx, r.getExecutor(), query, rel)
	return err
}

func (r *repository) GetRelationship(ctx context.Context, userID, targetUserID string, relType RelationshipType) (*UserRelationship, error) {
	query := `
		SELECT id, user_id, target_user_id, relationship_type, created_at
		FROM user_relationships
		WHERE user_id = $1 AND target_user_id = $2 AND relationship_type = $3
	`
	var rel UserRelationship
	err := sqlx.GetContext(ctx, r.getExecutor(), &rel, query, userID, targetUserID, relType)
	if err == sql.ErrNoRows {
		return nil, ErrRelationshipNotFound
	}
	return &rel, err
}

func (r *repository) DeleteRelationship(ctx context.Context, userID, targetUserID string, relType RelationshipType) error {
	query := `
		DELETE FROM user_relationships 
		WHERE user_id = $1 AND target_user_id = $2 AND relationship_type = $3
	`
	result, err := r.getExecutor().ExecContext(ctx, query, userID, targetUserID, relType)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrRelationshipNotFound
	}
	return nil
}

func (r *repository) GetUserRelationships(ctx context.Context, userID string, relType RelationshipType, limit, offset int) ([]*UserRelationship, int, error) {
	selectQuery := `
		SELECT id, user_id, target_user_id, relationship_type, created_at
		FROM user_relationships
		WHERE user_id = $1 AND relationship_type = $2
		ORDER BY created_at DESC
		LIMIT $3 OFFSET $4
	`
	countQuery := `
		SELECT COUNT(*)
		FROM user_relationships
		WHERE user_id = $1 AND relationship_type = $2
	`

	var relationships []*UserRelationship
	err := sqlx.SelectContext(ctx, r.getExecutor(), &relationships, selectQuery, userID, relType, limit, offset)
	if err != nil {
		return nil, 0, err
	}

	var total int
	err = r.getExecutor().QueryRowxContext(ctx, countQuery, userID, relType).Scan(&total)
	if err != nil {
		return nil, 0, err
	}

	return relationships, total, nil
}

func (r *repository) CheckRelationshipExists(ctx context.Context, userID, targetUserID string, relType RelationshipType) (bool, error) {
	query := `
		SELECT EXISTS(
			SELECT 1 FROM user_relationships 
			WHERE user_id = $1 AND target_user_id = $2 AND relationship_type = $3
		)
	`
	var exists bool
	err := r.getExecutor().QueryRowxContext(ctx, query, userID, targetUserID, relType).Scan(&exists)
	return exists, err
}

func (r *repository) GetMutualRelationships(ctx context.Context, userID, targetUserID string, relType RelationshipType) (bool, bool, error) {
	query := `
		SELECT 
			EXISTS(SELECT 1 FROM user_relationships WHERE user_id = $1 AND target_user_id = $2 AND relationship_type = $3) as follows,
			EXISTS(SELECT 1 FROM user_relationships WHERE user_id = $2 AND target_user_id = $1 AND relationship_type = $3) as followed_by
	`
	var follows, followedBy bool
	err := r.getExecutor().QueryRowxContext(ctx, query, userID, targetUserID, relType).Scan(&follows, &followedBy)
	return follows, followedBy, err
}

func (r *repository) CountRelationships(ctx context.Context, userID string, relType RelationshipType) (int, error) {
	query := `SELECT COUNT(*) FROM user_relationships WHERE user_id = $1 AND relationship_type = $2`
	var count int
	err := r.getExecutor().QueryRowxContext(ctx, query, userID, relType).Scan(&count)
	return count, err
}

func (r *repository) CreateReport(ctx context.Context, report *UserReport) error {
	query := `
		INSERT INTO user_reports (
			id, reporter_id, reported_user_id, reason, description, 
			status, created_at
		) VALUES (
			:id, :reporter_id, :reported_user_id, :reason, :description,
			:status, :created_at
		)
	`
	_, err := sqlx.NamedExecContext(ctx, r.getExecutor(), query, report)
	return err
}

func (r *repository) GetReportByID(ctx context.Context, id string) (*UserReport, error) {
	query := `
		SELECT id, reporter_id, reported_user_id, reason, description,
		       status, reviewed_by, reviewed_at, created_at
		FROM user_reports
		WHERE id = $1
	`
	var report UserReport
	err := sqlx.GetContext(ctx, r.getExecutor(), &report, query, id)
	if err == sql.ErrNoRows {
		return nil, ErrReportNotFound
	}
	return &report, err
}

func (r *repository) UpdateReportStatus(ctx context.Context, id string, status ReportStatus, reviewedBy *string) error {
	query := `
		UPDATE user_reports SET
			status = $1,
			reviewed_by = $2,
			reviewed_at = CASE WHEN $2 IS NOT NULL THEN NOW() ELSE reviewed_at END
		WHERE id = $3
	`
	result, err := r.getExecutor().ExecContext(ctx, query, status, reviewedBy, id)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrReportNotFound
	}
	return nil
}

func (r *repository) GetReportsByReporter(ctx context.Context, reporterID string, limit, offset int) ([]*UserReport, int, error) {
	selectQuery := `
		SELECT id, reporter_id, reported_user_id, reason, description,
		       status, reviewed_by, reviewed_at, created_at
		FROM user_reports
		WHERE reporter_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`
	countQuery := `SELECT COUNT(*) FROM user_reports WHERE reporter_id = $1`

	var reports []*UserReport
	err := sqlx.SelectContext(ctx, r.getExecutor(), &reports, selectQuery, reporterID, limit, offset)
	if err != nil {
		return nil, 0, err
	}

	var total int
	err = r.getExecutor().QueryRowxContext(ctx, countQuery, reporterID).Scan(&total)
	if err != nil {
		return nil, 0, err
	}

	return reports, total, nil
}

func (r *repository) GetReportsByReported(ctx context.Context, reportedUserID string, limit, offset int) ([]*UserReport, int, error) {
	selectQuery := `
		SELECT id, reporter_id, reported_user_id, reason, description,
		       status, reviewed_by, reviewed_at, created_at
		FROM user_reports
		WHERE reported_user_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`
	countQuery := `SELECT COUNT(*) FROM user_reports WHERE reported_user_id = $1`

	var reports []*UserReport
	err := sqlx.SelectContext(ctx, r.getExecutor(), &reports, selectQuery, reportedUserID, limit, offset)
	if err != nil {
		return nil, 0, err
	}

	var total int
	err = r.getExecutor().QueryRowxContext(ctx, countQuery, reportedUserID).Scan(&total)
	if err != nil {
		return nil, 0, err
	}

	return reports, total, nil
}

func (r *repository) CheckExistingReport(ctx context.Context, reporterID, reportedUserID string) (bool, error) {
	query := `
		SELECT EXISTS(
			SELECT 1 FROM user_reports 
			WHERE reporter_id = $1 AND reported_user_id = $2
		)
	`
	var exists bool
	err := r.getExecutor().QueryRowxContext(ctx, query, reporterID, reportedUserID).Scan(&exists)
	return exists, err
}

func (r *repository) GetPendingReports(ctx context.Context, limit, offset int) ([]*UserReport, int, error) {
	selectQuery := `
		SELECT id, reporter_id, reported_user_id, reason, description,
		       status, reviewed_by, reviewed_at, created_at
		FROM user_reports
		WHERE status = $1
		ORDER BY created_at ASC
		LIMIT $2 OFFSET $3
	`
	countQuery := `SELECT COUNT(*) FROM user_reports WHERE status = $1`

	var reports []*UserReport
	err := sqlx.SelectContext(ctx, r.getExecutor(), &reports, selectQuery, ReportStatusPending, limit, offset)
	if err != nil {
		return nil, 0, err
	}

	var total int
	err = r.getExecutor().QueryRowxContext(ctx, countQuery, ReportStatusPending).Scan(&total)
	if err != nil {
		return nil, 0, err
	}

	return reports, total, nil
}
