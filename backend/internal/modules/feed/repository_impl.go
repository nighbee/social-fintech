package feed

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

type repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) Repository {
	return &repository{db: db}
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

func (r *repository) CreatePost(ctx context.Context, post *Post, media []MediaAttachment) error {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	queryPost := `
		INSERT INTO posts (id, user_id, caption, visibility, comment_permission, is_public, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
	`
	_, err = tx.ExecContext(ctx, queryPost, post.ID, post.UserID, post.Caption, post.Visibility, post.CommentPermission, post.IsPublic)
	if err != nil {
		return err
	}

	for i, m := range media {
		mediaQuery := `
			INSERT INTO post_media (post_id, media_type, media_url, thumbnail_url, media_order, created_at)
			VALUES ($1, $2, $3, $4, $5, NOW())
		`
		_, err = tx.ExecContext(ctx, mediaQuery, post.ID, m.Type, m.URL, m.ThumbnailURL, i)
		if err != nil {
			return err
		}
	}

	return tx.Commit()
}

func (r *repository) GetFeed(ctx context.Context, viewerID uuid.UUID, cursor string, limit int) ([]PostResponse, string, error) {
	// A basic implementation. In production, this would use the weighted algorithm and cursor pagination.
	query := `
		SELECT p.id as post_id, p.caption, p.visibility, p.comment_permission, p.likes_count, p.comments_count, p.share_count, p.seals_count, p.created_at,
		       u.id as author_id, u.username, COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '') as full_name, u.avatar_url,
		       COALESCE(
			       (SELECT json_agg(json_build_object('type', media_type, 'url', media_url, 'thumbnail_url', thumbnail_url) ORDER BY media_order) 
			        FROM post_media pm WHERE pm.post_id = p.id), '[]'::json
		       ) as media_json
		FROM posts p
		JOIN users u ON p.user_id = u.id
		WHERE p.is_archived = false
		-- If cursor is provided: AND p.created_at < $cursor
		-- If ALLIES_ONLY: AND (p.visibility = 'ANYONE' OR p.user_id = $viewer_id OR EXISTS (SELECT 1 FROM user_relationships WHERE user_id=$viewer_id AND ally_id=p.user_id))
		ORDER BY p.created_at DESC
		LIMIT $1
	`
	// Note: Fully fledged query elided for brevity. Assuming simple fetch for MVP blueprint
	rows, err := r.db.QueryContext(ctx, query, limit)
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

		err := rows.Scan(
			&resp.PostID, &resp.ContentText, &resp.Permissions.CanComment, &resp.Permissions.CanComment, // placeholders for visibility/perms logic
			&resp.Metrics.Likes, &resp.Metrics.Comments, &resp.Metrics.Shares, &resp.Metrics.Silvers, &createdAt,
			&resp.Author.ID, &resp.Author.Username, &resp.Author.FullName, &resp.Author.ProfilePicURL,
			&mediaJSON,
		)
		if err != nil {
			return nil, "", err
		}

		_ = json.Unmarshal(mediaJSON, &resp.MediaAttachments)

		// Set basic permissions placeholder
		resp.Permissions.CanComment = true
		resp.TimeAgo = "just now" // formatted by client or util later

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

// GetThreadedComments grabs top-level comments and replies
func (r *repository) GetThreadedComments(ctx context.Context, postID uuid.UUID, viewerID uuid.UUID, parentID *uuid.UUID, cursor string, limit int) ([]CommentResponse, string, error) {
	var query string
	var args []interface{}

	if parentID == nil {
		query = `
			SELECT c.id, c.content, c.media_attachment, c.created_at,
			       u.id as author_id, u.username, COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '') as full_name, u.avatar_url,
			       (SELECT COUNT(r.id) FROM post_comments r WHERE r.parent_comment_id = c.id AND r.is_deleted = false) as reply_count
			FROM post_comments c
			JOIN users u ON c.user_id = u.id
			WHERE c.post_id = $1 AND c.parent_comment_id IS NULL AND c.is_deleted = false
			ORDER BY c.created_at DESC
			LIMIT $2
		`
		args = []interface{}{postID, limit}
	} else {
		query = `
			SELECT c.id, c.content, c.media_attachment, c.created_at,
			       u.id as author_id, u.username, COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '') as full_name, u.avatar_url,
			       0 as reply_count
			FROM post_comments c
			JOIN users u ON c.user_id = u.id
			WHERE c.post_id = $1 AND c.parent_comment_id = $2 AND c.is_deleted = false
			ORDER BY c.created_at ASC
			LIMIT $3
		`
		args = []interface{}{postID, *parentID, limit}
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

		err := rows.Scan(
			&resp.CommentID, &resp.ContentText, &mediaJSON, &createdAt,
			&resp.Author.ID, &resp.Author.Username, &resp.Author.FullName, &resp.Author.ProfilePicURL,
			&resp.ReplyCount,
		)
		if err != nil {
			return nil, "", err
		}

		if len(mediaJSON) > 0 {
			var m MediaAttachment
			_ = json.Unmarshal(mediaJSON, &m)
			resp.MediaAttachment = &m
		}

		comments = append(comments, resp)
	}

	return comments, "", nil
}

func (r *repository) CreateComment(ctx context.Context, comment *PostComment) error {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var mediaVal interface{}
	if comment.MediaAttachment != nil {
		b, _ := json.Marshal(comment.MediaAttachment)
		mediaVal = string(b)
	}

	query := `
		INSERT INTO post_comments (id, post_id, user_id, parent_comment_id, content, media_attachment, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
	`
	_, err = tx.ExecContext(ctx, query, comment.ID, comment.PostID, comment.UserID, comment.ParentCommentID, comment.Content, mediaVal)
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

	query := `SELECT comment_permission, user_id FROM posts WHERE id = $1 AND is_archived = false`
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

func (r *repository) GetInteractions(ctx context.Context, postID uuid.UUID, interactionType string, cursor string, limit int) ([]InteractionResponse, string, error) {
	// Query post_interactions joined with users table. Placeholder for MVP.
	return []InteractionResponse{}, "", nil
}

func (r *repository) GetSeals(ctx context.Context, postID uuid.UUID, cursor string, limit int) ([]SealResponse, string, error) {
	// Query seals connected via economy module joins or interaction metadata. Placeholder.
	return []SealResponse{}, "", nil
}
