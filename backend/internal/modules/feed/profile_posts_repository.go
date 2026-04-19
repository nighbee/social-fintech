package feed

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
)

// GetPostCreatedAt returns the created_at timestamp of a post.
// Used by the service layer to resolve an anchor post ID into a cursor.
func (r *repository) GetPostCreatedAt(ctx context.Context, postID uuid.UUID) (time.Time, error) {
	var createdAt time.Time
	err := r.db.QueryRowContext(ctx,
		`SELECT created_at FROM posts WHERE id = $1 AND is_archived = false AND is_deleted = false`,
		postID,
	).Scan(&createdAt)
	if err != nil {
		return time.Time{}, err
	}
	return createdAt, nil
}

// GetUserPostsGrid returns lightweight thumbnail entries for the profile posts grid.
//
// Visibility rules:
//   - viewer == author  → all non-archived posts
//   - otherwise         → only 'ANYONE' posts OR posts where viewer is an ally of author
//
// Cursor is exclusive (created_at < cursor), consistent with GetSmartFeed.
func (r *repository) GetUserPostsGrid(ctx context.Context, authorID, viewerID uuid.UUID, cursor time.Time, limit int) ([]PostGridItem, string, error) {
	const query = `
		SELECT
			p.id AS post_id,
			COALESCE(
				(SELECT COALESCE(pm.thumbnail_url, pm.video_1080p_url) FROM post_media pm WHERE pm.post_id = p.id ORDER BY pm.media_order ASC LIMIT 1),
				''
			) AS thumbnail_url,
			COALESCE(
				(SELECT pm.media_type FROM post_media pm WHERE pm.post_id = p.id ORDER BY pm.media_order ASC LIMIT 1),
				''
			) AS media_type,
			(SELECT COUNT(*) FROM post_media pm WHERE pm.post_id = p.id) > 1 AS has_multiple_media,
			p.created_at
		FROM posts p
		JOIN users u ON u.id = p.user_id
		WHERE p.user_id    = $1
		  AND p.is_archived = false
		  AND p.is_deleted = false
		  AND (u.id = $2 OR COALESCE(u.is_shadow_banned, false) = false)
		  AND EXISTS (
		        SELECT 1 FROM post_media pm WHERE pm.post_id = p.id
		      )
		  AND p.created_at  < $3
		  AND (
		        $1 = $2
		        OR p.visibility = 'ANYONE'
		        OR EXISTS (
		            SELECT 1
		            FROM user_relationships ur
		            WHERE ur.user_id = $2
		              AND ur.target_user_id = $1
		              AND ur.relationship_type = 'ally'
		          )
		      )
		ORDER BY p.created_at DESC
		LIMIT $4
	`

	rows, err := r.db.QueryContext(ctx, query, authorID, viewerID, cursor, limit)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()

	items := make([]PostGridItem, 0, limit)
	for rows.Next() {
		var item PostGridItem
		var createdAt sql.NullTime
		if err := rows.Scan(
			&item.PostID, &item.ThumbnailURL, &item.MediaType, &item.HasMultipleMedia, &createdAt,
		); err != nil {
			return nil, "", err
		}
		if createdAt.Valid {
			item.CreatedAt = createdAt.Time
		}
		item.ThumbnailURL = r.buildURL(item.ThumbnailURL)
		items = append(items, item)
	}

	nextCursor := ""
	if len(items) == limit {
		nextCursor = items[len(items)-1].CreatedAt.Format(time.RFC3339Nano)
	}

	return items, nextCursor, nil
}

// GetUserPostsList returns full PostResponse entries for the scrollable list view.
//
// The caller is responsible for passing cursor = anchorPost.CreatedAt + 1ns when
// an anchor post should be the first item returned.
func (r *repository) GetUserPostsList(ctx context.Context, authorID, viewerID uuid.UUID, cursor time.Time, limit int) ([]PostResponse, string, error) {
	const query = `
		SELECT
			p.id,
			p.caption,
			p.visibility,
			p.comment_permission,
			p.hide_likes_count,
			p.likes_count,
			p.comments_count,
			p.share_count,
			p.seals_count,
			p.created_at,
			u.id    AS author_id,
			COALESCE(u.username,    '')                                         AS username,
			COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '')     AS full_name,
			COALESCE(prof.avatar_url, '')                                       AS profile_pic_url,
			COALESCE(media.media_json, '[]'::json)                              AS media_json,
			EXISTS (
				SELECT 1 FROM post_interactions pi
				WHERE pi.post_id = p.id
				  AND pi.user_id = $2
				  AND pi.interaction_type = 'like'
			) AS viewer_has_liked
		FROM posts p
		JOIN users    u    ON u.id    = p.user_id
		LEFT JOIN profiles prof ON prof.user_id = u.id
		LEFT JOIN LATERAL (
			SELECT json_agg(json_build_object(
				'type',              pm.media_type,
				'url',               pm.video_1080p_url,
				'image_url',         pm.video_1080p_url,
				'video_1080p_url',   pm.video_1080p_url,
				'video_480p_url',    pm.video_480p_url,
				'thumbnail_url',     pm.thumbnail_url,
				'processing_status', pm.processing_status
			) ORDER BY pm.media_order) AS media_json
			FROM post_media pm
			WHERE pm.post_id = p.id
		) media ON true
		WHERE p.user_id     = $1
		  AND p.is_archived  = false
		  AND p.is_deleted   = false
		  AND (u.id = $2 OR COALESCE(u.is_shadow_banned, false) = false)
		  AND p.created_at   < $3
		  AND (
		        $1 = $2
		        OR p.visibility = 'ANYONE'
		        OR EXISTS (
		            SELECT 1
		            FROM user_relationships ur
		            WHERE ur.user_id = $2
		              AND ur.target_user_id = $1
		              AND ur.relationship_type = 'ally'
		          )
		      )
		ORDER BY p.created_at DESC
		LIMIT $4
	`

	rows, err := r.db.QueryContext(ctx, query, authorID, viewerID, cursor, limit)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()

	items := make([]PostResponse, 0, limit)
	var lastCreatedAt sql.NullTime
	for rows.Next() {
		var resp PostResponse
		var mediaJSON []byte
		var createdAt sql.NullTime
		var commentPerm string

		if err := rows.Scan(
			&resp.PostID, &resp.ContentText, &resp.Visibility, &commentPerm, &resp.HideLikesCount,
			&resp.Metrics.Likes, &resp.Metrics.Comments, &resp.Metrics.Shares, &resp.Metrics.Silvers,
			&createdAt,
			&resp.Author.ID, &resp.Author.Username, &resp.Author.FullName, &resp.Author.ProfilePicURL,
			&mediaJSON,
			&resp.ViewerHasLiked,
		); err != nil {
			return nil, "", err
		}

		_ = json.Unmarshal(mediaJSON, &resp.MediaAttachments)
		for i := range resp.MediaAttachments {
			resp.MediaAttachments[i].URL_1080p = r.buildURL(resp.MediaAttachments[i].URL_1080p)
			resp.MediaAttachments[i].URL = resp.MediaAttachments[i].URL_1080p
			resp.MediaAttachments[i].ImageURL = resp.MediaAttachments[i].URL_1080p
			resp.MediaAttachments[i].URL_480p = r.buildURL(resp.MediaAttachments[i].URL_480p)
			resp.MediaAttachments[i].ThumbnailURL = r.buildURL(resp.MediaAttachments[i].ThumbnailURL)
		}
		resp.CommentPermission = commentPerm
		resp.Permissions.CanComment = commentPerm != CommentPermNoOne
		applyHiddenLikesForViewer(&resp, viewerID)

		if createdAt.Valid {
			elapsed := time.Since(createdAt.Time)
			switch {
			case elapsed < time.Hour:
				resp.TimeAgo = fmt.Sprintf("%dm", int(elapsed.Minutes()))
			case elapsed < 24*time.Hour:
				resp.TimeAgo = fmt.Sprintf("%dh", int(elapsed.Hours()))
			default:
				resp.TimeAgo = fmt.Sprintf("%dd", int(elapsed.Hours()/24))
			}
			lastCreatedAt = createdAt
		}

		items = append(items, resp)
	}

	nextCursor := ""
	if len(items) == limit && lastCreatedAt.Valid {
		nextCursor = lastCreatedAt.Time.Format(time.RFC3339Nano)
	}

	return items, nextCursor, nil
}
