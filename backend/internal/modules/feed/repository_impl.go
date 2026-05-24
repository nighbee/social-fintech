package feed

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/brightbund-backend/internal/modules/economy"
	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
	"github.com/lib/pq"
)

func (r *repository) buildURL(u string) string {
	if u == "" {
		return u
	}
	if !strings.HasPrefix(u, "http") && !strings.HasPrefix(u, "local-media") {
		baseURL := r.publicURL
		if baseURL == "" {
			baseURL = "http://10.0.2.2:8080" // fallback if config incomplete
		}
		baseURL = strings.TrimSuffix(baseURL, "/")
		if strings.HasPrefix(u, "/") {
			return baseURL + u
		}
		return baseURL + "/" + u
	}
	return u
}

func (r *repository) buildAvatarURL(u string, updatedAt sql.NullTime) string {
	if strings.TrimSpace(u) == "" {
		return ""
	}
	avatarURL := r.buildURL(u)
	version := fmt.Sprintf("v=%d", updatedAt.Time.Unix())
	if updatedAt.Valid {
		if strings.Contains(avatarURL, "?") {
			return avatarURL + "&" + version
		}
		return avatarURL + "?" + version
	}
	return avatarURL
}

type repository struct {
	db          *sqlx.DB
	publicURL   string
	adaptiveGeo AdaptiveGeoConfig
}

func NewRepository(db *sqlx.DB, publicURL string) Repository {
	return NewRepositoryWithAdaptiveGeo(db, publicURL, DefaultAdaptiveGeoConfig())
}

func NewRepositoryWithAdaptiveGeo(db *sqlx.DB, publicURL string, adaptiveGeo AdaptiveGeoConfig) Repository {
	return &repository{db: db, publicURL: publicURL, adaptiveGeo: adaptiveGeo.normalize()}
}

func (r *repository) GetFatigueState(ctx context.Context, userID uuid.UUID) (*FeedFatigueState, error) {
	query := `
		SELECT user_id, accumulated_active_seconds, accumulated_break_seconds, last_sync_timestamp, is_in_cooldown, break_start_at
		FROM feed_fatigue_states
		WHERE user_id = $1
	`
	var row struct {
		UserID                   uuid.UUID    `db:"user_id"`
		AccumulatedActiveSeconds int          `db:"accumulated_active_seconds"`
		AccumulatedBreakSeconds  int          `db:"accumulated_break_seconds"`
		LastSyncTimestamp        time.Time    `db:"last_sync_timestamp"`
		IsInCooldown             bool         `db:"is_in_cooldown"`
		BreakStartedAt           sql.NullTime `db:"break_start_at"`
	}
	err := sqlx.GetContext(ctx, r.db, &row, query, userID)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("state not found")
	}
	if err != nil {
		return nil, err
	}

	state := &FeedFatigueState{
		UserID:                   row.UserID,
		AccumulatedActiveSeconds: row.AccumulatedActiveSeconds,
		AccumulatedBreakSeconds:  row.AccumulatedBreakSeconds,
		LastSyncTimestamp:        row.LastSyncTimestamp,
		IsInCooldown:             row.IsInCooldown,
	}
	if row.BreakStartedAt.Valid {
		t := row.BreakStartedAt.Time
		state.BreakStartedAt = &t
	}
	return state, nil
}

func (r *repository) UpsertFatigueState(ctx context.Context, state *FeedFatigueState) error {
	query := `
		INSERT INTO feed_fatigue_states (user_id, accumulated_active_seconds, accumulated_break_seconds, last_sync_timestamp, is_in_cooldown, break_start_at)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (user_id) DO UPDATE SET
			accumulated_active_seconds = EXCLUDED.accumulated_active_seconds,
			accumulated_break_seconds  = EXCLUDED.accumulated_break_seconds,
			last_sync_timestamp = EXCLUDED.last_sync_timestamp,
			is_in_cooldown = EXCLUDED.is_in_cooldown,
			break_start_at = EXCLUDED.break_start_at
	`
	_, err := r.db.ExecContext(ctx, query, state.UserID, state.AccumulatedActiveSeconds, state.AccumulatedBreakSeconds, state.LastSyncTimestamp, state.IsInCooldown, state.BreakStartedAt)
	return err
}

func (r *repository) GetPostByIdempotencyKey(ctx context.Context, userID uuid.UUID, idempotencyKey string) (*uuid.UUID, string, error) {
	var postID sql.NullString
	var fingerprint sql.NullString
	err := r.db.QueryRowContext(ctx, `
		SELECT COALESCE(post_id::text, ''), COALESCE(request_fingerprint, '')
		FROM post_idempotency_keys
		WHERE user_id = $1 AND idempotency_key = $2
	`, userID, idempotencyKey).Scan(&postID, &fingerprint)
	if err == sql.ErrNoRows {
		return nil, "", nil
	}
	if err != nil {
		return nil, "", err
	}
	if !postID.Valid || strings.TrimSpace(postID.String) == "" {
		return nil, strings.TrimSpace(fingerprint.String), nil
	}
	parsed, err := uuid.Parse(postID.String)
	if err != nil {
		return nil, "", err
	}
	return &parsed, strings.TrimSpace(fingerprint.String), nil
}

func (r *repository) CreatePost(ctx context.Context, post *Post, media []MediaAttachment, idempotencyKey, requestFingerprint string) error {
	if err := r.enforceAuthorPublishingPolicy(ctx, post.UserID); err != nil {
		return err
	}

	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	idempotencyKey = strings.TrimSpace(idempotencyKey)
	requestFingerprint = strings.TrimSpace(requestFingerprint)
	if idempotencyKey != "" {
		res, err := tx.ExecContext(ctx, `
			INSERT INTO post_idempotency_keys (user_id, idempotency_key, request_fingerprint, created_at)
			VALUES ($1, $2, $3, NOW())
			ON CONFLICT (user_id, idempotency_key) DO NOTHING
		`, post.UserID, idempotencyKey, requestFingerprint)
		if err != nil {
			return err
		}
		rows, err := res.RowsAffected()
		if err != nil {
			return err
		}
		if rows == 0 {
			var existingPostID sql.NullString
			var existingFingerprint sql.NullString
			err := tx.QueryRowContext(ctx, `
				SELECT COALESCE(post_id::text, ''), COALESCE(request_fingerprint, '')
				FROM post_idempotency_keys
				WHERE user_id = $1 AND idempotency_key = $2
				FOR UPDATE
			`, post.UserID, idempotencyKey).Scan(&existingPostID, &existingFingerprint)
			if err != nil {
				return err
			}
			if existingFingerprint.Valid && strings.TrimSpace(existingFingerprint.String) != "" && requestFingerprint != "" &&
				strings.TrimSpace(existingFingerprint.String) != requestFingerprint {
				return ErrPostIdempotencyConflict
			}
			if existingPostID.Valid && strings.TrimSpace(existingPostID.String) != "" {
				return ErrPostIdempotencyInProgress
			}
			return ErrPostIdempotencyInProgress
		}
	}

	queryPost := `
		INSERT INTO posts (
			id, user_id, caption, visibility, comment_permission, hide_likes_count, is_public,
			location_city, location_country, location_lat, location_lon,
			created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW(), NOW())
	`
	_, err = tx.ExecContext(
		ctx,
		queryPost,
		post.ID,
		post.UserID,
		post.Caption,
		post.Visibility,
		post.CommentPermission,
		post.HideLikesCount,
		post.IsPublic,
		post.LocationCity,
		post.LocationCountry,
		post.LocationLat,
		post.LocationLon,
	)
	if err != nil {
		return err
	}

	for i, m := range media {
		mediaID := m.ID
		if mediaID == uuid.Nil {
			mediaID = uuid.New()
		}

		mediaQuery := `
			INSERT INTO post_media (
				id, post_id, media_type, video_1080p_url, video_480p_url, 
				thumbnail_url, processing_status, original_path, 
				media_order, created_at
			)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
		`
		_, err = tx.ExecContext(
			ctx, mediaQuery,
			mediaID, post.ID, m.Type, m.URL_1080p, m.URL_480p,
			m.ThumbnailURL, m.ProcessingStatus, m.OriginalPath,
			i,
		)
		if err != nil {
			return err
		}
	}
	if idempotencyKey != "" {
		_, err = tx.ExecContext(ctx, `
			UPDATE post_idempotency_keys
			SET post_id = $3
			WHERE user_id = $1 AND idempotency_key = $2
		`, post.UserID, idempotencyKey, post.ID)
		if err != nil {
			return err
		}
	}

	return tx.Commit()
}

func (r *repository) enforceAuthorPublishingPolicy(ctx context.Context, authorID uuid.UUID) error {
	const query = `
		SELECT
			COUNT(1) FILTER (
				WHERE aps.strike_type IN ('post_removed', 'comment_removed', 'content_violation')
				  AND aps.created_at >= NOW() - INTERVAL '30 days'
			) AS post_removed_30d,
			MAX(aps.created_at) FILTER (
				WHERE aps.strike_type IN ('post_removed', 'comment_removed', 'content_violation')
				  AND aps.created_at >= NOW() - INTERVAL '30 days'
			) AS last_actioned_at
		FROM author_policy_strikes aps
		WHERE aps.author_id = $1
		  AND (aps.expires_at IS NULL OR aps.expires_at >= NOW())
	`

	var postRemoved30d int
	var lastStrikeAt sql.NullTime
	if err := r.db.QueryRowContext(ctx, query, authorID).Scan(&postRemoved30d, &lastStrikeAt); err != nil {
		return err
	}

	if !lastStrikeAt.Valid {
		return nil
	}

	if shouldRestrictPublishing(postRemoved30d, lastStrikeAt.Time, time.Now()) {
		return ErrPublishingRestricted
	}

	return nil
}

func shouldRestrictPublishing(postRemoved30d int, lastStrikeAt time.Time, now time.Time) bool {
	switch {
	case postRemoved30d >= 9:
		return lastStrikeAt.Add(7 * 24 * time.Hour).After(now)
	case postRemoved30d >= 6:
		return lastStrikeAt.Add(3 * 24 * time.Hour).After(now)
	case postRemoved30d >= 3:
		return lastStrikeAt.Add(24 * time.Hour).After(now)
	default:
		return false
	}
}

func (r *repository) UpdatePost(ctx context.Context, postID, userID uuid.UUID, req *UpdatePostRequest) error {
	if req == nil || (req.CommentPermission == nil && req.HideLikesCount == nil) {
		return ErrInvalidPostUpdate
	}

	assignments := make([]string, 0, 3)
	args := make([]interface{}, 0, 4)
	idx := 1

	if req.CommentPermission != nil {
		assignments = append(assignments, fmt.Sprintf("comment_permission = $%d", idx))
		args = append(args, *req.CommentPermission)
		idx++
	}

	if req.HideLikesCount != nil {
		assignments = append(assignments, fmt.Sprintf("hide_likes_count = $%d", idx))
		args = append(args, *req.HideLikesCount)
		idx++
	}

	assignments = append(assignments, "updated_at = NOW()")
	args = append(args, postID, userID)

	query := fmt.Sprintf(`
		UPDATE posts
		SET %s
		WHERE id = $%d AND user_id = $%d AND is_archived = false AND is_deleted = false
	`, strings.Join(assignments, ", "), idx, idx+1)

	res, err := r.db.ExecContext(ctx, query, args...)
	if err != nil {
		return err
	}

	rows, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if rows > 0 {
		return nil
	}

	var authorID uuid.UUID
	var isArchived bool
	var isDeleted bool
	err = r.db.QueryRowContext(ctx, `SELECT user_id, is_archived, is_deleted FROM posts WHERE id = $1`, postID).Scan(&authorID, &isArchived, &isDeleted)
	if err == sql.ErrNoRows {
		return ErrPostNotFound
	}
	if err != nil {
		return err
	}
	if authorID != userID {
		return ErrNotPostAuthor
	}
	if isArchived || isDeleted {
		return ErrPostAlreadyDeleted
	}

	return ErrPostNotFound
}

func (r *repository) DeletePost(ctx context.Context, postID, userID uuid.UUID, isModerator bool) error {
	res, err := r.db.ExecContext(ctx, `
		UPDATE posts
		SET is_deleted = true,
		    updated_at = NOW()
		WHERE id = $1
		  AND (user_id = $2 OR $3 = true)
		  AND is_archived = false AND is_deleted = false
	`, postID, userID, isModerator)
	if err != nil {
		return err
	}

	rows, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if rows > 0 {
		return nil
	}

	var authorID uuid.UUID
	var isArchived bool
	var isDeleted bool
	err = r.db.QueryRowContext(ctx, `SELECT user_id, is_archived, is_deleted FROM posts WHERE id = $1`, postID).Scan(&authorID, &isArchived, &isDeleted)
	if err == sql.ErrNoRows {
		return ErrPostNotFound
	}
	if err != nil {
		return err
	}
	if authorID != userID && !isModerator {
		return ErrNotPostAuthor
	}
	if isArchived || isDeleted {
		return ErrPostAlreadyDeleted
	}

	return ErrPostNotFound
}

func (r *repository) GetPost(ctx context.Context, postID uuid.UUID, viewerID uuid.UUID) (*PostResponse, error) {
	query := `
		SELECT p.id as post_id, p.caption, p.visibility, p.comment_permission,
		       CASE WHEN p.comment_permission = 'NO_ONE' THEN false ELSE true END as can_comment,
		       p.likes_count, p.comments_count, p.share_count, p.seals_count, p.hide_likes_count, p.created_at,
		       u.id as author_id, u.username, COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '') as full_name, COALESCE(prof.avatar_url, '') as avatar_url, prof.updated_at as avatar_updated_at,
		       COALESCE(prof.total_gold_seals_received, 0) * 100 as author_received_centinels,
		       COALESCE(
			       (SELECT json_agg(json_build_object(
				       'type', media_type,
				       'url', video_1080p_url,
				       'image_url', video_1080p_url,
				       'video_1080p_url', video_1080p_url,
				       'video_480p_url', video_480p_url,
				       'thumbnail_url', thumbnail_url,
				       'processing_status', processing_status
				   ) ORDER BY media_order)
			        FROM post_media pm WHERE pm.post_id = p.id), '[]'::json
		       ) as media_json,
		       EXISTS(SELECT 1 FROM post_interactions pi WHERE pi.post_id = p.id AND pi.user_id = $2 AND pi.interaction_type = 'like') as viewer_has_liked
		FROM posts p
		JOIN users u ON p.user_id = u.id
		LEFT JOIN profiles prof ON prof.user_id = u.id
		WHERE p.id = $1
		  AND p.is_archived = false
		  AND p.is_deleted = false
		  AND (u.id = $2 OR COALESCE(u.is_shadow_banned, false) = false)
		  AND COALESCE(p.is_hidden_by_reports, false) = false
	`
	var resp PostResponse
	var mediaJSON []byte
	var createdAt sql.NullTime
	var avatarURL sql.NullString
	var avatarUpdatedAt sql.NullTime
	var authorReceivedCentinels int64

	err := r.db.QueryRowContext(ctx, query, postID, viewerID).Scan(
		&resp.PostID, &resp.ContentText, &resp.Visibility, &resp.CommentPermission, &resp.Permissions.CanComment,
		&resp.Metrics.Likes, &resp.Metrics.Comments, &resp.Metrics.Shares, &resp.Metrics.Silvers, &resp.HideLikesCount, &createdAt,
		&resp.Author.ID, &resp.Author.Username, &resp.Author.FullName, &avatarURL, &avatarUpdatedAt,
		&authorReceivedCentinels,
		&mediaJSON, &resp.ViewerHasLiked,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrPostNotFound
		}
		return nil, err
	}

	if avatarURL.Valid {
		resp.Author.ProfilePicURL = r.buildAvatarURL(avatarURL.String, avatarUpdatedAt)
	}
	fillAuthorRank(&resp.Author, authorReceivedCentinels)

	_ = json.Unmarshal(mediaJSON, &resp.MediaAttachments)
	for i := range resp.MediaAttachments {
		resp.MediaAttachments[i].URL_1080p = r.buildURL(resp.MediaAttachments[i].URL_1080p)
		resp.MediaAttachments[i].URL = resp.MediaAttachments[i].URL_1080p
		resp.MediaAttachments[i].ImageURL = resp.MediaAttachments[i].URL_1080p
		resp.MediaAttachments[i].URL_480p = r.buildURL(resp.MediaAttachments[i].URL_480p)
		resp.MediaAttachments[i].ThumbnailURL = r.buildURL(resp.MediaAttachments[i].ThumbnailURL)
	}

	resp.TimeAgo = "just now"
	applyHiddenLikesForViewer(&resp, viewerID)

	return &resp, nil
}

func (r *repository) GetFeed(ctx context.Context, viewerID uuid.UUID, cursor string, limit int) ([]PostResponse, string, error) {
	// A basic implementation. In production, this would use the weighted algorithm and cursor pagination.
	query := `
		SELECT p.id as post_id, p.caption, p.visibility, p.comment_permission,
		       CASE WHEN p.comment_permission = 'NO_ONE' THEN false ELSE true END as can_comment,
		       p.likes_count, p.comments_count, p.share_count, p.seals_count, p.hide_likes_count, p.created_at,
		       u.id as author_id, u.username, COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '') as full_name, COALESCE(prof.avatar_url, '') as avatar_url,
		       COALESCE(prof.total_gold_seals_received, 0) * 100 as author_received_centinels,
		       COALESCE(
			       (SELECT json_agg(json_build_object(
				       'type', media_type,
				       'url', video_1080p_url,
				       'image_url', video_1080p_url,
				       'video_1080p_url', video_1080p_url,
				       'video_480p_url', video_480p_url,
				       'thumbnail_url', thumbnail_url,
				       'processing_status', processing_status
				   ) ORDER BY media_order)
			        FROM post_media pm WHERE pm.post_id = p.id), '[]'::json
		       ) as media_json
		FROM posts p
		JOIN users u ON p.user_id = u.id
		LEFT JOIN profiles prof ON prof.user_id = u.id
		WHERE p.is_archived = false AND p.is_deleted = false
		  AND COALESCE(u.is_shadow_banned, false) = false
		  AND COALESCE(p.is_hidden_by_reports, false) = false
		  AND p.user_id <> $2
		-- If cursor is provided: AND p.created_at < $cursor
		-- If ALLIES_ONLY: AND (p.visibility = 'ANYONE' OR EXISTS (SELECT 1 FROM user_relationships WHERE user_id=$viewer_id AND ally_id=p.user_id))
		ORDER BY p.created_at DESC, p.id DESC
		LIMIT $1
	`
	// Note: Fully fledged query elided for brevity. Assuming simple fetch for MVP blueprint
	rows, err := r.db.QueryContext(ctx, query, limit, viewerID)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()

	var feed []PostResponse
	var lastCreatedAt string

	for rows.Next() {
		var resp PostResponse
		var mediaJSON []byte
		var createdAt sql.NullTime
		var avatarURL sql.NullString
		var commentPerm string
		var authorReceivedCentinels int64

		// Added viewer_has_liked to the generic feed response if needed, but the original query does not select it.
		// We missed it in the GetFeed query. Let's fix the query first or omit it here. We'll update the query in a follow up call.
		err := rows.Scan(
			&resp.PostID, &resp.ContentText, &resp.Visibility, &commentPerm, &resp.Permissions.CanComment,
			&resp.Metrics.Likes, &resp.Metrics.Comments, &resp.Metrics.Shares, &resp.Metrics.Silvers, &resp.HideLikesCount, &createdAt,
			&resp.Author.ID, &resp.Author.Username, &resp.Author.FullName, &avatarURL,
			&authorReceivedCentinels,
			&mediaJSON,
		)
		if err != nil {
			return nil, "", err
		}

		if avatarURL.Valid {
			resp.Author.ProfilePicURL = r.buildURL(avatarURL.String)
		}
		fillAuthorRank(&resp.Author, authorReceivedCentinels)

		_ = json.Unmarshal(mediaJSON, &resp.MediaAttachments)
		for i := range resp.MediaAttachments {
			resp.MediaAttachments[i].URL_1080p = r.buildURL(resp.MediaAttachments[i].URL_1080p)
			resp.MediaAttachments[i].URL = resp.MediaAttachments[i].URL_1080p
			resp.MediaAttachments[i].ImageURL = resp.MediaAttachments[i].URL_1080p
			resp.MediaAttachments[i].URL_480p = r.buildURL(resp.MediaAttachments[i].URL_480p)
			resp.MediaAttachments[i].ThumbnailURL = r.buildURL(resp.MediaAttachments[i].ThumbnailURL)
		}

		resp.TimeAgo = "just now" // formatted by client or util later
		resp.CommentPermission = commentPerm
		applyHiddenLikesForViewer(&resp, viewerID)

		feed = append(feed, resp)
		if createdAt.Valid {
			lastCreatedAt = createdAt.Time.Format("2006-01-02T15:04:05.999999Z")
		}
	}

	nextCursor := ""
	if len(feed) == limit {
		nextCursor = lastCreatedAt
	}

	return feed, nextCursor, nil
}

// GetComment finds a single comment representation
func (r *repository) GetComment(ctx context.Context, commentID uuid.UUID, viewerID uuid.UUID) (*CommentResponse, error) {
	query := `
		SELECT c.id, c.parent_comment_id, c.root_comment_id, c.content,
		       COALESCE((
			           SELECT jsonb_agg(jsonb_build_object(
			               'type', m->>'type',
			               'url', COALESCE(m->>'url', m->>'video_1080p_url'),
			               'video_1080p_url', COALESCE(m->>'video_1080p_url', m->>'url'),
			               'video_480p_url', m->>'video_480p_url',
			               'thumbnail_url', m->>'thumbnail_url',
			               'processing_status', m->>'processing_status'
			           ))
			           FROM jsonb_array_elements(c.media_attachments) AS m
			       ), '[]'::jsonb) as media_json,
		       c.created_at,
		       c.likes_count,
		       u.id as author_id, u.username, COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '') as full_name, COALESCE(prof.avatar_url, '') as avatar_url, prof.updated_at as avatar_updated_at,
		       COALESCE(prof.total_gold_seals_received, 0) * 100 as author_received_centinels,
		       (SELECT COUNT(r.id) FROM post_comments r WHERE r.parent_comment_id = c.id AND r.is_deleted = false) as reply_count,
		       EXISTS(SELECT 1 FROM comment_interactions ci WHERE ci.comment_id = c.id AND ci.user_id = $2 AND ci.interaction_type = 'like') as viewer_has_liked
		FROM post_comments c
		JOIN users u ON c.user_id = u.id
		LEFT JOIN profiles prof ON prof.user_id = u.id
		WHERE c.id = $1
		  AND c.is_deleted = false
		  AND c.is_hidden_by_reports = false
		  AND (u.id = $2 OR COALESCE(u.is_shadow_banned, false) = false)
	`
	var resp CommentResponse
	var mediaJSON []byte
	var createdAt sql.NullTime
	var avatarURL sql.NullString
	var avatarUpdatedAt sql.NullTime
	var authorReceivedCentinels int64

	err := r.db.QueryRowContext(ctx, query, commentID, viewerID).Scan(
		&resp.CommentID, &resp.ParentCommentID, &resp.RootCommentID, &resp.ContentText, &mediaJSON, &createdAt,
		&resp.LikesCount,
		&resp.Author.ID, &resp.Author.Username, &resp.Author.FullName, &avatarURL, &avatarUpdatedAt,
		&authorReceivedCentinels,
		&resp.ReplyCount,
		&resp.ViewerHasLiked,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("comment not found")
		}
		return nil, err
	}

	if avatarURL.Valid {
		resp.Author.ProfilePicURL = r.buildAvatarURL(avatarURL.String, avatarUpdatedAt)
	}
	fillAuthorRank(&resp.Author, authorReceivedCentinels)

	if createdAt.Valid {
		resp.CreatedAt = createdAt.Time
	}

	if len(mediaJSON) > 0 {
		var list []MediaAttachment
		_ = json.Unmarshal(mediaJSON, &list)
		for i := range list {
			list[i].URL_1080p = r.buildURL(list[i].URL_1080p)
			list[i].URL = list[i].URL_1080p
			list[i].ImageURL = list[i].URL_1080p
			list[i].URL_480p = r.buildURL(list[i].URL_480p)
			list[i].ThumbnailURL = r.buildURL(list[i].ThumbnailURL)
		}
		resp.MediaAttachments = list
	}

	return &resp, nil
}

func (r *repository) GetCommentThreadParent(ctx context.Context, commentID uuid.UUID) (*CommentThreadParent, error) {
	query := `
		SELECT id, user_id, post_id, parent_comment_id, root_comment_id
		FROM post_comments
		WHERE id = $1 AND is_deleted = false
	`
	var info CommentThreadParent
	err := r.db.QueryRowContext(ctx, query, commentID).Scan(
		&info.CommentID,
		&info.UserID,
		&info.PostID,
		&info.ParentID,
		&info.RootCommentID,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrCommentNotFound
		}
		return nil, err
	}
	return &info, nil
}

// GetThreadedComments grabs top-level comments and replies
func (r *repository) GetThreadedComments(ctx context.Context, postID uuid.UUID, viewerID uuid.UUID, parentID *uuid.UUID, cursor string, limit int) ([]CommentResponse, string, error) {
	var query string
	var args []interface{}

	if parentID == nil {
		query = `
			SELECT c.id, c.parent_comment_id, c.root_comment_id, c.content,
			       COALESCE((
			           SELECT jsonb_agg(jsonb_build_object(
			               'type', m->>'type',
			               'url', COALESCE(m->>'url', m->>'video_1080p_url'),
			               'video_1080p_url', COALESCE(m->>'video_1080p_url', m->>'url'),
			               'video_480p_url', m->>'video_480p_url',
			               'thumbnail_url', m->>'thumbnail_url',
			               'processing_status', m->>'processing_status'
			           ))
			           FROM jsonb_array_elements(c.media_attachments) AS m
			       ), '[]'::jsonb) as media_json,
			       c.created_at,
			       c.likes_count,
			       u.id as author_id, u.username, COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '') as full_name, COALESCE(prof.avatar_url, '') as avatar_url, prof.updated_at as avatar_updated_at,
			       COALESCE(prof.total_gold_seals_received, 0) * 100 as author_received_centinels,
			       (SELECT COUNT(r.id) FROM post_comments r WHERE r.parent_comment_id = c.id AND r.is_deleted = false) as reply_count,
			       EXISTS(SELECT 1 FROM comment_interactions ci WHERE ci.comment_id = c.id AND ci.user_id = $2 AND ci.interaction_type = 'like') as viewer_has_liked
			FROM post_comments c
			JOIN users u ON c.user_id = u.id
			LEFT JOIN profiles prof ON prof.user_id = u.id
			WHERE c.post_id = $1
			  AND c.parent_comment_id IS NULL
			  AND c.is_deleted = false
			  AND c.is_hidden_by_reports = false
			  AND (u.id = $2 OR COALESCE(u.is_shadow_banned, false) = false)
			  AND (
				c.user_id = $2 OR
				random() <= (
					CASE
						WHEN (
							SELECT COUNT(1)
							FROM author_policy_strikes aps
							WHERE aps.author_id = c.user_id
							  AND aps.strike_type IN ('post_removed', 'comment_removed', 'content_violation')
							  AND aps.created_at >= NOW() - INTERVAL '30 days'
						) >= 5 THEN 0.4
						WHEN (
							SELECT COUNT(1)
							FROM author_policy_strikes aps
							WHERE aps.author_id = c.user_id
							  AND aps.strike_type IN ('post_removed', 'comment_removed', 'content_violation')
							  AND aps.created_at >= NOW() - INTERVAL '30 days'
						) >= 3 THEN 0.7
						ELSE 1.0
					END
				)
			  )
			ORDER BY c.created_at DESC, c.id DESC
			LIMIT $3
		`
		args = []interface{}{postID, viewerID, limit}
		if cursor != "" {
			query = `
				SELECT c.id, c.parent_comment_id, c.root_comment_id, c.content,
				       COALESCE((
				           SELECT jsonb_agg(jsonb_build_object(
				               'type', m->>'type',
				               'url', COALESCE(m->>'url', m->>'video_1080p_url'),
				               'video_1080p_url', COALESCE(m->>'video_1080p_url', m->>'url'),
				               'video_480p_url', m->>'video_480p_url',
				               'thumbnail_url', m->>'thumbnail_url',
				               'processing_status', m->>'processing_status'
				           ))
				           FROM jsonb_array_elements(c.media_attachments) AS m
				       ), '[]'::jsonb) as media_json,
				       c.created_at,
				       c.likes_count,
				       u.id as author_id, u.username, COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '') as full_name, COALESCE(prof.avatar_url, '') as avatar_url, prof.updated_at as avatar_updated_at,
				       COALESCE(prof.total_gold_seals_received, 0) * 100 as author_received_centinels,
				       (SELECT COUNT(r.id) FROM post_comments r WHERE r.parent_comment_id = c.id AND r.is_deleted = false) as reply_count,
				       EXISTS(SELECT 1 FROM comment_interactions ci WHERE ci.comment_id = c.id AND ci.user_id = $2 AND ci.interaction_type = 'like') as viewer_has_liked
				FROM post_comments c
				JOIN users u ON c.user_id = u.id
				LEFT JOIN profiles prof ON prof.user_id = u.id
				WHERE c.post_id = $1
				  AND c.parent_comment_id IS NULL
				  AND c.is_deleted = false
				  AND c.is_hidden_by_reports = false
				  AND (u.id = $2 OR COALESCE(u.is_shadow_banned, false) = false)
				  AND (
					c.user_id = $2 OR
					random() <= (
						CASE
							WHEN (
								SELECT COUNT(1)
								FROM author_policy_strikes aps
								WHERE aps.author_id = c.user_id
								  AND aps.strike_type IN ('post_removed', 'comment_removed', 'content_violation')
								  AND aps.created_at >= NOW() - INTERVAL '30 days'
							) >= 5 THEN 0.4
							WHEN (
								SELECT COUNT(1)
								FROM author_policy_strikes aps
								WHERE aps.author_id = c.user_id
								  AND aps.strike_type IN ('post_removed', 'comment_removed', 'content_violation')
								  AND aps.created_at >= NOW() - INTERVAL '30 days'
							) >= 3 THEN 0.7
							ELSE 1.0
						END
					)
				  )
				  AND c.created_at < $4
				ORDER BY c.created_at DESC, c.id DESC
				LIMIT $3
			`
			args = []interface{}{postID, viewerID, limit, cursor}
		}
	} else {
		// Reply fetch: direct parent lookup — NO shadow filter.
		// The user explicitly requested replies for a known comment; random suppression
		// breaks the UX contract (count is visible but list appears empty).
		query = `
			SELECT c.id, c.parent_comment_id, c.root_comment_id, c.content,
			       COALESCE((
			           SELECT jsonb_agg(jsonb_build_object(
			               'type', m->>'type',
			               'url', COALESCE(m->>'url', m->>'video_1080p_url'),
			               'video_1080p_url', COALESCE(m->>'video_1080p_url', m->>'url'),
			               'video_480p_url', m->>'video_480p_url',
			               'thumbnail_url', m->>'thumbnail_url',
			               'processing_status', m->>'processing_status'
			           ))
			           FROM jsonb_array_elements(c.media_attachments) AS m
			       ), '[]'::jsonb) as media_json,
			       c.created_at,
			       c.likes_count,
			       u.id as author_id, u.username, COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '') as full_name, COALESCE(prof.avatar_url, '') as avatar_url, prof.updated_at as avatar_updated_at,
			       COALESCE(prof.total_gold_seals_received, 0) * 100 as author_received_centinels,
			       (SELECT COUNT(r.id) FROM post_comments r WHERE r.parent_comment_id = c.id AND r.is_deleted = false) as reply_count,
			       EXISTS(SELECT 1 FROM comment_interactions ci WHERE ci.comment_id = c.id AND ci.user_id = $2 AND ci.interaction_type = 'like') as viewer_has_liked
			FROM post_comments c
			JOIN users u ON c.user_id = u.id
			LEFT JOIN profiles prof ON prof.user_id = u.id
			WHERE c.post_id = $1
			  AND c.parent_comment_id = $3
			  AND c.is_deleted = false
			  AND c.is_hidden_by_reports = false
			  AND (u.id = $2 OR COALESCE(u.is_shadow_banned, false) = false)
			ORDER BY c.created_at ASC, c.id ASC
			LIMIT $4
		`
		args = []interface{}{postID, viewerID, *parentID, limit}
		if cursor != "" {
			query = `
				SELECT c.id, c.parent_comment_id, c.root_comment_id, c.content,
				       COALESCE((
				           SELECT jsonb_agg(jsonb_build_object(
				               'type', m->>'type',
				               'url', COALESCE(m->>'url', m->>'video_1080p_url'),
				               'video_1080p_url', COALESCE(m->>'video_1080p_url', m->>'url'),
				               'video_480p_url', m->>'video_480p_url',
				               'thumbnail_url', m->>'thumbnail_url',
				               'processing_status', m->>'processing_status'
				           ))
				           FROM jsonb_array_elements(c.media_attachments) AS m
				       ), '[]'::jsonb) as media_json,
				       c.created_at,
				       c.likes_count,
				       u.id as author_id, u.username, COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '') as full_name, COALESCE(prof.avatar_url, '') as avatar_url, prof.updated_at as avatar_updated_at,
				       COALESCE(prof.total_gold_seals_received, 0) * 100 as author_received_centinels,
				       (SELECT COUNT(r.id) FROM post_comments r WHERE r.parent_comment_id = c.id AND r.is_deleted = false) as reply_count,
				       EXISTS(SELECT 1 FROM comment_interactions ci WHERE ci.comment_id = c.id AND ci.user_id = $2 AND ci.interaction_type = 'like') as viewer_has_liked
				FROM post_comments c
				JOIN users u ON c.user_id = u.id
				LEFT JOIN profiles prof ON prof.user_id = u.id
				WHERE c.post_id = $1
				  AND c.parent_comment_id = $3
				  AND c.is_deleted = false
				  AND c.is_hidden_by_reports = false
				  AND (u.id = $2 OR COALESCE(u.is_shadow_banned, false) = false)
				  AND c.created_at > $5
				ORDER BY c.created_at ASC, c.id ASC
				LIMIT $4
			`
			args = []interface{}{postID, viewerID, *parentID, limit, cursor}
		}
	}

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()

	var comments []CommentResponse
	for rows.Next() {
		var resp CommentResponse
		var mediaJSON []byte
		var createdAt sql.NullTime
		var avatarURL sql.NullString
		var avatarUpdatedAt sql.NullTime
		var authorReceivedCentinels int64

		err := rows.Scan(
			&resp.CommentID, &resp.ParentCommentID, &resp.RootCommentID, &resp.ContentText, &mediaJSON, &createdAt,
			&resp.LikesCount,
			&resp.Author.ID, &resp.Author.Username, &resp.Author.FullName, &avatarURL, &avatarUpdatedAt,
			&authorReceivedCentinels,
			&resp.ReplyCount,
			&resp.ViewerHasLiked,
		)
		if err != nil {
			return nil, "", err
		}

		if avatarURL.Valid {
			resp.Author.ProfilePicURL = r.buildAvatarURL(avatarURL.String, avatarUpdatedAt)
		}
		fillAuthorRank(&resp.Author, authorReceivedCentinels)

		if createdAt.Valid {
			resp.CreatedAt = createdAt.Time
		}

		if len(mediaJSON) > 0 {
			var list []MediaAttachment
			_ = json.Unmarshal(mediaJSON, &list)
			for i := range list {
				list[i].URL_1080p = r.buildURL(list[i].URL_1080p)
				list[i].URL = list[i].URL_1080p
				list[i].ImageURL = list[i].URL_1080p
				list[i].URL_480p = r.buildURL(list[i].URL_480p)
				list[i].ThumbnailURL = r.buildURL(list[i].ThumbnailURL)
			}
			resp.MediaAttachments = list
		}

		comments = append(comments, resp)
	}

	// Emit nextCursor only when a full page was returned, indicating there may be more.
	nextCursor := ""
	if len(comments) == limit && len(comments) > 0 {
		last := comments[len(comments)-1]
		nextCursor = last.CreatedAt.Format(time.RFC3339Nano)
	}

	return comments, nextCursor, nil
}

func (r *repository) ToggleCommentLike(ctx context.Context, commentID uuid.UUID, userID uuid.UUID) error {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var exists bool
	queryCheck := `SELECT EXISTS(SELECT 1 FROM comment_interactions WHERE comment_id=$1 AND user_id=$2 AND interaction_type='like')`
	err = tx.QueryRowContext(ctx, queryCheck, commentID, userID).Scan(&exists)
	if err != nil {
		return err
	}

	if exists {
		_, err = tx.ExecContext(ctx, `DELETE FROM comment_interactions WHERE comment_id=$1 AND user_id=$2 AND interaction_type='like'`, commentID, userID)
		if err != nil {
			return err
		}
		_, err = tx.ExecContext(ctx, `UPDATE post_comments SET likes_count = likes_count - 1 WHERE id=$1`, commentID)
		if err != nil {
			return err
		}
	} else {
		_, err = tx.ExecContext(ctx, `INSERT INTO comment_interactions (comment_id, user_id, interaction_type, created_at) VALUES ($1, $2, 'like', NOW())`, commentID, userID)
		if err != nil {
			return err
		}
		_, err = tx.ExecContext(ctx, `UPDATE post_comments SET likes_count = likes_count + 1 WHERE id=$1`, commentID)
		if err != nil {
			return err
		}
	}

	return tx.Commit()
}

func (r *repository) IsAlly(ctx context.Context, userID, targetUserID uuid.UUID) (bool, error) {
	const query = `
		SELECT EXISTS(
			SELECT 1
			FROM user_relationships
			WHERE user_id = $1
			  AND target_user_id = $2
			  AND relationship_type = 'ally'
		)
	`
	var exists bool
	if err := r.db.QueryRowContext(ctx, query, userID, targetUserID).Scan(&exists); err != nil {
		return false, err
	}
	return exists, nil
}

func (r *repository) IsUserAdmin(ctx context.Context, userID uuid.UUID) (bool, error) {
	var isAdmin bool
	if err := r.db.QueryRowContext(ctx, `SELECT is_admin FROM users WHERE id = $1`, userID).Scan(&isAdmin); err != nil {
		if err == sql.ErrNoRows {
			return false, ErrCommentNotFound
		}
		return false, err
	}
	return isAdmin, nil
}

func (r *repository) DeleteComment(ctx context.Context, commentID, actorID uuid.UUID, isModerator bool) error {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var postID uuid.UUID
	const query = `
		UPDATE post_comments
		SET is_deleted = true,
		    content = '[deleted]',
		    media_attachments = '[]'::jsonb,
		    updated_at = NOW()
		WHERE id = $1
		  AND is_deleted = false
		  AND (user_id = $2 OR $3 = true)
		RETURNING post_id
	`
	if err := tx.QueryRowContext(ctx, query, commentID, actorID, isModerator).Scan(&postID); err != nil {
		if err == sql.ErrNoRows {
			return ErrNotCommentAuthor
		}
		return err
	}

	if _, err := tx.ExecContext(ctx, `UPDATE posts SET comments_count = GREATEST(comments_count - 1, 0) WHERE id = $1`, postID); err != nil {
		return err
	}

	return tx.Commit()
}

func (r *repository) CreateReport(ctx context.Context, reporterID uuid.UUID, targetType string, targetID uuid.UUID, reason, description string) error {
	const query = `
		INSERT INTO reports (id, reporter_id, target_type, target_id, reason, moderation_status, description, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
	`
	_, err := r.db.ExecContext(ctx, query, uuid.New(), reporterID, targetType, targetID, reason, ReportStatusPending, description)
	return err
}

func (r *repository) HidePostForReporter(ctx context.Context, reporterID, postID uuid.UUID) error {
	const query = `
		INSERT INTO reported_post_hides (reporter_id, post_id, created_at)
		VALUES ($1, $2, NOW())
		ON CONFLICT (reporter_id, post_id) DO NOTHING
	`
	_, err := r.db.ExecContext(ctx, query, reporterID, postID)
	return err
}

func (r *repository) CountRecentReportsByUser(ctx context.Context, reporterID uuid.UUID, since time.Time) (int, error) {
	var count int
	const query = `SELECT COUNT(1) FROM reports WHERE reporter_id = $1 AND created_at >= $2`
	if err := r.db.QueryRowContext(ctx, query, reporterID, since).Scan(&count); err != nil {
		return 0, err
	}
	return count, nil
}

func (r *repository) CountReportsForTarget(ctx context.Context, targetType string, targetID uuid.UUID) (int, error) {
	var count int
	const query = `SELECT COUNT(1) FROM reports WHERE target_type = $1 AND target_id = $2`
	if err := r.db.QueryRowContext(ctx, query, targetType, targetID).Scan(&count); err != nil {
		return 0, err
	}
	return count, nil
}

func (r *repository) GetWeightedReportsForPost(ctx context.Context, postID uuid.UUID) (float64, error) {
	var weighted float64
	const query = `
		SELECT COALESCE(SUM(
			(CASE
				WHEN u.created_at > NOW() - INTERVAL '7 days' THEN 0.3
				ELSE 1.0
			 END)
			*
			(CASE
				WHEN COALESCE(pf.total_gold_seals_received, 0) >= 300 THEN 2.0
				WHEN COALESCE(pf.total_gold_seals_received, 0) >= 30 THEN 1.5
				ELSE 1.0
			 END)
			*
			COALESCE(rr.reputation_multiplier, 1.0)
		), 0)
		FROM reports r
		JOIN users u ON u.id = r.reporter_id
		LEFT JOIN profiles pf ON pf.user_id = r.reporter_id
		LEFT JOIN reporter_reputation rr ON rr.reporter_id = r.reporter_id
		WHERE r.target_type = $1 AND r.target_id = $2
	`
	if err := r.db.QueryRowContext(ctx, query, ReportTargetPost, postID).Scan(&weighted); err != nil {
		return 0, err
	}
	return weighted, nil
}

func (r *repository) GetPostImpressions(ctx context.Context, postID uuid.UUID) (int, error) {
	var impressions int
	const query = `SELECT COALESCE(impressions_count, 0) FROM posts WHERE id = $1`
	if err := r.db.QueryRowContext(ctx, query, postID).Scan(&impressions); err != nil {
		return 0, err
	}
	return impressions, nil
}

func (r *repository) SetPostReportControl(ctx context.Context, postID uuid.UUID, level int, distributionMultiplier float64) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE posts
		SET report_control_level = $2,
		    distribution_multiplier = $3,
		    moderation_queue_at = CASE
		        WHEN $2 >= 4 AND moderation_queue_at IS NULL THEN NOW()
		        ELSE moderation_queue_at
		    END,
		    updated_at = NOW()
		WHERE id = $1
	`, postID, level, distributionMultiplier)
	return err
}

func (r *repository) IncrementPostImpressions(ctx context.Context, postIDs []uuid.UUID) error {
	if len(postIDs) == 0 {
		return nil
	}

	ids := make([]string, 0, len(postIDs))
	for _, id := range postIDs {
		ids = append(ids, id.String())
	}

	_, err := r.db.ExecContext(ctx, `
		UPDATE posts
		SET impressions_count = COALESCE(impressions_count, 0) + 1,
		    updated_at = NOW()
		WHERE id = ANY($1::uuid[])
	`, pq.Array(ids))
	return err
}

func (r *repository) MarkReportsReviewed(ctx context.Context, targetType string, targetID uuid.UUID, decision string) ([]uuid.UUID, error) {
	rows, err := r.db.QueryContext(ctx, `
		UPDATE reports
		SET moderation_status = $3,
		    review_decision = $4,
		    reviewed_at = NOW(),
		    reputation_applied = false
		WHERE target_type = $1
		  AND target_id = $2
		  AND moderation_status = $5
		RETURNING reporter_id
	`, targetType, targetID, ReportStatusReviewed, decision, ReportStatusPending)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	seen := make(map[uuid.UUID]struct{})
	ids := make([]uuid.UUID, 0)
	for rows.Next() {
		var reporterID uuid.UUID
		if err := rows.Scan(&reporterID); err != nil {
			return nil, err
		}
		if _, ok := seen[reporterID]; ok {
			continue
		}
		seen[reporterID] = struct{}{}
		ids = append(ids, reporterID)
	}

	return ids, nil
}

func (r *repository) ApplyReporterReputationDelta(ctx context.Context, reporterIDs []uuid.UUID, accepted bool) error {
	for _, reporterID := range reporterIDs {
		if accepted {
			_, err := r.db.ExecContext(ctx, `
				INSERT INTO reporter_reputation (reporter_id, accepted_reports_count, rejected_reports_count, consecutive_rejected_count, reputation_multiplier, updated_at)
				VALUES ($1, 1, 0, 0, 1.05, NOW())
				ON CONFLICT (reporter_id) DO UPDATE
				SET accepted_reports_count = reporter_reputation.accepted_reports_count + 1,
				    consecutive_rejected_count = 0,
				    reputation_multiplier = LEAST(2.5, GREATEST(0.3, reporter_reputation.reputation_multiplier + 0.05)),
				    updated_at = NOW()
			`, reporterID)
			if err != nil {
				return err
			}
			continue
		}

		_, err := r.db.ExecContext(ctx, `
			INSERT INTO reporter_reputation (reporter_id, accepted_reports_count, rejected_reports_count, consecutive_rejected_count, reputation_multiplier, updated_at)
			VALUES ($1, 0, 1, 1, 0.95, NOW())
			ON CONFLICT (reporter_id) DO UPDATE
			SET rejected_reports_count = reporter_reputation.rejected_reports_count + 1,
			    consecutive_rejected_count = reporter_reputation.consecutive_rejected_count + 1,
			    reputation_multiplier = LEAST(2.5, GREATEST(0.3, reporter_reputation.reputation_multiplier - 0.05)),
			    updated_at = NOW()
		`, reporterID)
		if err != nil {
			return err
		}
	}

	return nil
}

func (r *repository) MarkReportReputationApplied(ctx context.Context, targetType string, targetID uuid.UUID) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE reports
		SET reputation_applied = true
		WHERE target_type = $1
		  AND target_id = $2
		  AND moderation_status = $3
		  AND reputation_applied = false
	`, targetType, targetID, ReportStatusReviewed)
	return err
}

func (r *repository) CreateAuthorPolicyStrikeForTarget(ctx context.Context, targetType string, targetID uuid.UUID, expiresAt time.Time) error {
	var authorID uuid.UUID
	strikeType, err := strikeTypeForTarget(targetType)
	if err != nil {
		return err
	}

	switch targetType {
	case ReportTargetPost:
		if err := r.db.QueryRowContext(ctx, `SELECT user_id FROM posts WHERE id = $1`, targetID).Scan(&authorID); err != nil {
			return err
		}
	case ReportTargetComment:
		if err := r.db.QueryRowContext(ctx, `SELECT user_id FROM post_comments WHERE id = $1`, targetID).Scan(&authorID); err != nil {
			return err
		}
	}

	_, err = r.db.ExecContext(ctx, `
		INSERT INTO author_policy_strikes (author_id, report_id, strike_type, expires_at, created_at)
		VALUES ($1, NULL, $2, $3, NOW())
	`, authorID, strikeType, expiresAt)
	return err
}

func strikeTypeForTarget(targetType string) (string, error) {
	switch targetType {
	case ReportTargetPost:
		return "post_removed", nil
	case ReportTargetComment:
		return "comment_removed", nil
	default:
		return "", ErrInvalidReportReason
	}
}

func (r *repository) HideTargetByReports(ctx context.Context, targetType string, targetID uuid.UUID) error {
	switch targetType {
	case ReportTargetPost:
		_, err := r.db.ExecContext(ctx, `UPDATE posts SET is_hidden_by_reports = true, updated_at = NOW() WHERE id = $1`, targetID)
		return err
	case ReportTargetComment:
		_, err := r.db.ExecContext(ctx, `UPDATE post_comments SET is_hidden_by_reports = true, updated_at = NOW() WHERE id = $1`, targetID)
		return err
	default:
		return ErrInvalidReportReason
	}
}

func (r *repository) HardBlockAuthorByTarget(ctx context.Context, targetType string, targetID uuid.UUID) error {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	var authorID uuid.UUID
	switch targetType {
	case ReportTargetPost:
		err = tx.QueryRowContext(ctx, `SELECT user_id FROM posts WHERE id = $1`, targetID).Scan(&authorID)
	case ReportTargetComment:
		err = tx.QueryRowContext(ctx, `SELECT user_id FROM post_comments WHERE id = $1`, targetID).Scan(&authorID)
	default:
		err = ErrInvalidReportReason
		return err
	}
	if err != nil {
		return err
	}

	// Hard moderation: fully shadow-ban the author and remove all their content from public feeds.
	if _, err = tx.ExecContext(ctx, `
		UPDATE users
		SET is_shadow_banned = true,
		    activation_status = 'blocked',
		    restrictions_until = NOW() + INTERVAL '365 days',
		    updated_at = NOW()
		WHERE id = $1
	`, authorID); err != nil {
		return err
	}

	// Immediately invalidate all active sessions so existing tokens stop working.
	if _, err = tx.ExecContext(ctx, `
		UPDATE sessions
		SET revoked_at = NOW()
		WHERE user_id = $1
		  AND revoked_at IS NULL
	`, authorID); err != nil {
		return err
	}

	if _, err = tx.ExecContext(ctx, `
		UPDATE posts
		SET is_hidden_by_reports = true,
		    report_control_level = GREATEST(COALESCE(report_control_level, 0), 4),
		    distribution_multiplier = 0.0,
		    updated_at = NOW()
		WHERE user_id = $1
	`, authorID); err != nil {
		return err
	}

	if _, err = tx.ExecContext(ctx, `
		UPDATE post_comments
		SET is_hidden_by_reports = true,
		    updated_at = NOW()
		WHERE user_id = $1
	`, authorID); err != nil {
		return err
	}

	err = tx.Commit()
	return err
}

func (r *repository) ListReports(ctx context.Context, status, targetType, reason string, limit, offset int) ([]ReportItem, int, error) {
	baseWhere := []string{"1=1"}
	args := make([]interface{}, 0, 6)
	argIdx := 1

	if status != "" {
		baseWhere = append(baseWhere, fmt.Sprintf("moderation_status = $%d", argIdx))
		args = append(args, status)
		argIdx++
	}
	if targetType != "" {
		baseWhere = append(baseWhere, fmt.Sprintf("target_type = $%d", argIdx))
		args = append(args, targetType)
		argIdx++
	}
	if reason != "" {
		baseWhere = append(baseWhere, fmt.Sprintf("reason = $%d", argIdx))
		args = append(args, reason)
		argIdx++
	}

	whereSQL := strings.Join(baseWhere, " AND ")

	countQuery := fmt.Sprintf("SELECT COUNT(1) FROM reports WHERE %s", whereSQL)
	var total int
	if err := r.db.QueryRowContext(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, err
	}

	listArgs := append(args, limit, offset)
	listQuery := fmt.Sprintf(`
		SELECT id, reporter_id, target_type, target_id, reason, moderation_status, created_at
		FROM reports
		WHERE %s
		ORDER BY created_at DESC
		LIMIT $%d OFFSET $%d
	`, whereSQL, argIdx, argIdx+1)

	rows, err := r.db.QueryContext(ctx, listQuery, listArgs...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	items := make([]ReportItem, 0, limit)
	for rows.Next() {
		var item ReportItem
		if err := rows.Scan(&item.ID, &item.ReporterID, &item.TargetType, &item.TargetID, &item.Reason, &item.ModerationStatus, &item.CreatedAt); err != nil {
			return nil, 0, err
		}
		items = append(items, item)
	}

	return items, total, nil
}

func (r *repository) ReportComment(ctx context.Context, commentID, reporterID uuid.UUID, reason, description string) error {
	// Backward-compat wrapper (legacy calls).
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO reports (id, reporter_id, target_type, target_id, reason, moderation_status, description, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
	`, uuid.New(), reporterID, ReportTargetComment, commentID, reason, ReportStatusPending, description)
	return err
}

func (r *repository) CreateComment(ctx context.Context, comment *PostComment) error {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var mediaListVal interface{}
	if len(comment.MediaAttachments) > 0 {
		b, _ := json.Marshal(comment.MediaAttachments)
		mediaListVal = string(b)
	}

	query := `
		INSERT INTO post_comments (id, post_id, user_id, parent_comment_id, root_comment_id, content, media_attachments, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW())
	`
	rootID := comment.ParentCommentID
	if comment.RootCommentID != nil {
		rootID = comment.RootCommentID
	}

	_, err = tx.ExecContext(ctx, query, comment.ID, comment.PostID, comment.UserID, comment.ParentCommentID, rootID, comment.Content, mediaListVal)
	if err != nil {
		return err
	}

	_, err = tx.ExecContext(ctx, `UPDATE posts SET comments_count = comments_count + 1 WHERE id = $1`, comment.PostID)
	if err != nil {
		return err
	}

	return tx.Commit()
}

func (r *repository) GetPostPermissionsInfo(ctx context.Context, postID uuid.UUID) (string, uuid.UUID, error) {
	var perm string
	var authorID uuid.UUID

	query := `SELECT comment_permission, user_id FROM posts WHERE id = $1 AND is_archived = false AND is_deleted = false AND is_hidden_by_reports = false`
	err := r.db.QueryRowContext(ctx, query, postID).Scan(&perm, &authorID)
	if err == sql.ErrNoRows {
		return "", uuid.Nil, ErrPostNotFound
	}
	return perm, authorID, err
}

func (r *repository) IncrementShareCount(ctx context.Context, postID uuid.UUID) error {
	_, err := r.db.ExecContext(ctx, `UPDATE posts SET share_count = share_count + 1 WHERE id = $1`, postID)
	return err
}

func (r *repository) ToggleLike(ctx context.Context, postID uuid.UUID, userID uuid.UUID) error {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var exists bool
	queryCheck := `SELECT EXISTS(SELECT 1 FROM post_interactions WHERE post_id=$1 AND user_id=$2 AND interaction_type='like')`
	err = tx.QueryRowContext(ctx, queryCheck, postID, userID).Scan(&exists)
	if err != nil {
		return err
	}

	if exists {
		_, err = tx.ExecContext(ctx, `DELETE FROM post_interactions WHERE post_id=$1 AND user_id=$2 AND interaction_type='like'`, postID, userID)
		if err != nil {
			return err
		}
		_, err = tx.ExecContext(ctx, `UPDATE posts SET likes_count = likes_count - 1 WHERE id=$1`, postID)
		if err != nil {
			return err
		}
	} else {
		_, err = tx.ExecContext(ctx, `INSERT INTO post_interactions (post_id, user_id, interaction_type, created_at) VALUES ($1, $2, 'like', NOW())`, postID, userID)
		if err != nil {
			return err
		}
		_, err = tx.ExecContext(ctx, `UPDATE posts SET likes_count = likes_count + 1 WHERE id=$1`, postID)
		if err != nil {
			return err
		}
	}

	return tx.Commit()
}

func (r *repository) GetInteractions(ctx context.Context, postID uuid.UUID, interactionType string, cursor string, limit int) ([]InteractionResponse, string, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	cursorTime := time.Now()
	if cursor != "" {
		if t, err := time.Parse(time.RFC3339Nano, cursor); err == nil {
			cursorTime = t
		}
	}

	query := `
		SELECT
			u.id,
			COALESCE(u.username, '') AS username,
			COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '') AS full_name,
			COALESCE(p.avatar_url, '') AS profile_pic_url,
			COALESCE(w.total_received_amount, 0) AS author_received_centinels,
			pi.created_at
		FROM post_interactions pi
		JOIN users u ON u.id = pi.user_id
		LEFT JOIN profiles p ON p.user_id = u.id
		LEFT JOIN wallets w ON w.user_id = u.id AND w.currency = 'GOLD_SEAL'
		WHERE pi.post_id = $1
		  AND pi.interaction_type = $2
		  AND pi.created_at < $3
		ORDER BY pi.created_at DESC
		LIMIT $4
	`

	rows, err := r.db.QueryContext(ctx, query, postID, interactionType, cursorTime, limit)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()

	items := make([]InteractionResponse, 0, limit)
	var lastCreatedAt time.Time
	for rows.Next() {
		var item InteractionResponse
		var createdAt time.Time
		var avatarURL sql.NullString
		var authorReceivedCentinels int64

		if err := rows.Scan(
			&item.User.ID,
			&item.User.Username,
			&item.User.FullName,
			&avatarURL,
			&authorReceivedCentinels,
			&createdAt,
		); err != nil {
			return nil, "", err
		}

		if avatarURL.Valid {
			item.User.ProfilePicURL = r.buildURL(avatarURL.String)
		}
		fillAuthorRank(&item.User, authorReceivedCentinels)

		item.CreatedAt = createdAt
		items = append(items, item)
		lastCreatedAt = createdAt
	}

	nextCursor := ""
	if len(items) == limit && !lastCreatedAt.IsZero() {
		nextCursor = lastCreatedAt.Format(time.RFC3339Nano)
	}

	return items, nextCursor, nil
}

func (r *repository) GetSeals(ctx context.Context, postID uuid.UUID, cursor string, limit int) ([]SealResponse, string, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	cursorTime := time.Now()
	if cursor != "" {
		if t, err := time.Parse(time.RFC3339Nano, cursor); err == nil {
			cursorTime = t
		}
	}

	query := `
		SELECT
			le.amount,
			COALESCE(le.metadata->>'comment', '') AS comment,
			le.created_at,
			u.id,
			COALESCE(u.username, '') AS username,
			COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '') AS full_name,
			COALESCE(p.avatar_url, '') AS profile_pic_url,
			COALESCE(gw.total_received_amount, 0) AS author_received_centinels
		FROM ledger_entries le
		JOIN wallets sw ON sw.id = le.sender_wallet_id
		JOIN users u ON u.id = sw.user_id
		LEFT JOIN profiles p ON p.user_id = u.id
		LEFT JOIN wallets gw ON gw.user_id = u.id AND gw.currency = 'GOLD_SEAL'
		WHERE le.category = $1
		  AND le.currency IN ($2, $3)
		  AND le.metadata->>'post_id' = $4
		  AND le.created_at < $5
		ORDER BY le.created_at DESC
		LIMIT $6
	`

	rows, err := r.db.QueryContext(ctx, query,
		economy.CategoryPostSeal,
		economy.CurrencySilverSeal,
		economy.CurrencyGoldSeal,
		postID.String(),
		cursorTime,
		limit,
	)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()

	items := make([]SealResponse, 0, limit)
	var lastCreatedAt time.Time
	for rows.Next() {
		var resp SealResponse
		var amount int64
		var comment string
		var createdAt time.Time
		var avatarURL sql.NullString
		var authorReceivedCentinels int64

		if err := rows.Scan(
			&amount,
			&comment,
			&createdAt,
			&resp.User.ID,
			&resp.User.Username,
			&resp.User.FullName,
			&avatarURL,
			&authorReceivedCentinels,
		); err != nil {
			return nil, "", err
		}
		resp.Amount = amount / economy.CentinelsPerSeal
		trimmed := strings.TrimSpace(comment)
		resp.Reason = trimmed
		resp.Comment = trimmed
		resp.CreatedAt = createdAt
		if avatarURL.Valid {
			resp.User.ProfilePicURL = r.buildURL(avatarURL.String)
		}
		fillAuthorRank(&resp.User, authorReceivedCentinels)

		items = append(items, resp)
		lastCreatedAt = createdAt
	}

	nextCursor := ""
	if len(items) == limit && !lastCreatedAt.IsZero() {
		nextCursor = lastCreatedAt.Format(time.RFC3339Nano)
	}

	return items, nextCursor, nil
}

func (r *repository) UpdateMediaProcessingResult(ctx context.Context, mediaID uuid.UUID, url1080p, url480p, thumbURL, status string) error {
	const query = `
		UPDATE post_media
		SET video_1080p_url = $2,
		    video_480p_url = $3,
		    thumbnail_url = $4,
		    processing_status = $5
		WHERE id = $1
	`
	_, err := r.db.ExecContext(ctx, query, mediaID, url1080p, url480p, thumbURL, status)
	return err
}

func (r *repository) LogMediaAbuse(ctx context.Context, userID uuid.UUID, violationType, detectionDetails string, metadata interface{}) error {
	query := `
		INSERT INTO media_abuse_logs (id, user_id, violation_type, media_metadata, detection_details)
		VALUES ($1, $2, $3, $4, $5)
	`
	metaJSON, _ := json.Marshal(metadata)
	_, err := r.db.ExecContext(ctx, query, uuid.New(), userID, violationType, metaJSON, detectionDetails)
	return err
}

func (r *repository) GetPostAuthorID(ctx context.Context, postID uuid.UUID) (uuid.UUID, error) {
	var authorID uuid.UUID
	err := r.db.GetContext(ctx, &authorID, "SELECT user_id FROM posts WHERE id = $1", postID)
	return authorID, err
}

func (r *repository) GetCommentAuthorID(ctx context.Context, commentID uuid.UUID) (uuid.UUID, error) {
	var authorID uuid.UUID
	err := r.db.GetContext(ctx, &authorID, "SELECT user_id FROM post_comments WHERE id = $1", commentID)
	return authorID, err
}

func (r *repository) GetOrCreateReportCooldown(ctx context.Context, reporterID, targetUserID uuid.UUID) (*ReportCooldown, error) {
	var cooldown ReportCooldown
	err := r.db.GetContext(ctx, &cooldown, "SELECT * FROM report_cooldowns WHERE reporter_id = $1 AND target_user_id = $2", reporterID, targetUserID)
	if err == sql.ErrNoRows {
		return &ReportCooldown{
			ReporterID:           reporterID,
			TargetUserID:         targetUserID,
			CooldownUntil:        time.Now().Add(-1 * time.Hour), // Already expired
			CurrentCooldownHours: 24,
			LastReportAt:         time.Time{},
		}, nil
	}
	return &cooldown, err
}

func (r *repository) UpdateReportCooldown(ctx context.Context, cooldown *ReportCooldown) error {
	query := `
		INSERT INTO report_cooldowns (reporter_id, target_user_id, cooldown_until, current_cooldown_hours, last_report_at)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (reporter_id, target_user_id) DO UPDATE SET
			cooldown_until = EXCLUDED.cooldown_until,
			current_cooldown_hours = EXCLUDED.current_cooldown_hours,
			last_report_at = EXCLUDED.last_report_at
	`
	_, err := r.db.ExecContext(ctx, query, cooldown.ReporterID, cooldown.TargetUserID, cooldown.CooldownUntil, cooldown.CurrentCooldownHours, cooldown.LastReportAt)
	return err
}
