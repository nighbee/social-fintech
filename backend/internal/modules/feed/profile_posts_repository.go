package feed

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/lib/pq"
)

// GetPostCreatedAt returns the created_at timestamp of a post.
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

// batchFetchGridMedia returns first media item per post for grid display in one query.
func (r *repository) batchFetchGridMedia(ctx context.Context, postIDs []uuid.UUID) (map[uuid.UUID]*PostGridItem, error) {
	if len(postIDs) == 0 {
		return map[uuid.UUID]*PostGridItem{}, nil
	}

	query := `
		SELECT DISTINCT ON (post_id)
			post_id,
			COALESCE(thumbnail_url, video_1080p_url, '') AS thumbnail_url,
			COALESCE(media_type, '') AS media_type,
			COUNT(*) OVER (PARTITION BY post_id) > 1 AS has_multiple_media
		FROM post_media
		WHERE post_id = ANY($1::uuid[])
		ORDER BY post_id, media_order ASC
	`
	rows, err := r.db.QueryContext(ctx, query, pq.Array(postIDs))
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := make(map[uuid.UUID]*PostGridItem, len(postIDs))
	for rows.Next() {
		var postID uuid.UUID
		var item PostGridItem
		if err := rows.Scan(&postID, &item.ThumbnailURL, &item.MediaType, &item.HasMultipleMedia); err != nil {
			return nil, err
		}
		item.ThumbnailURL = r.buildURL(item.ThumbnailURL)
		result[postID] = &item
	}
	return result, nil
}

// GetUserPostsGrid returns lightweight thumbnail entries for the profile posts grid.
func (r *repository) GetUserPostsGrid(ctx context.Context, authorID, viewerID uuid.UUID, cursor time.Time, limit int) ([]PostGridItem, string, error) {
	const query = `
		SELECT
			p.id AS post_id,
			p.created_at
		FROM posts p
		JOIN users u ON u.id = p.user_id
		WHERE p.user_id    = $1
		  AND p.is_archived = false
		  AND p.is_deleted = false
		  AND (u.id = $2 OR COALESCE(u.is_shadow_banned, false) = false)
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

	type gridRow struct {
		PostID    uuid.UUID
		CreatedAt time.Time
	}
	var gridRows []gridRow
	var postIDs []uuid.UUID
	for rows.Next() {
		var gr gridRow
		if err := rows.Scan(&gr.PostID, &gr.CreatedAt); err != nil {
			return nil, "", err
		}
		gridRows = append(gridRows, gr)
		postIDs = append(postIDs, gr.PostID)
	}

	mediaMap, err := r.batchFetchGridMedia(ctx, postIDs)
	if err != nil {
		return nil, "", err
	}

	items := make([]PostGridItem, 0, len(gridRows))
	for _, gr := range gridRows {
		item := PostGridItem{PostID: gr.PostID, CreatedAt: gr.CreatedAt}
		if media, ok := mediaMap[gr.PostID]; ok {
			item.ThumbnailURL = media.ThumbnailURL
			item.MediaType = media.MediaType
			item.HasMultipleMedia = media.HasMultipleMedia
		}
		items = append(items, item)
	}

	nextCursor := ""
	if len(items) == limit {
		nextCursor = items[len(items)-1].CreatedAt.Format(time.RFC3339Nano)
	}

	return items, nextCursor, nil
}

// GetUserPostsList returns full PostResponse entries for the scrollable list view.
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
			COALESCE(prof.total_gold_seals_received, 0) * 100                   AS author_received_centinels,
			EXISTS (
				SELECT 1 FROM post_interactions pi
				WHERE pi.post_id = p.id
				  AND pi.user_id = $2
				  AND pi.interaction_type = 'like'
			) AS viewer_has_liked
		FROM posts p
		JOIN users    u    ON u.id    = p.user_id
		LEFT JOIN profiles prof ON prof.user_id = u.id
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
	var postIDs []uuid.UUID
	var lastCreatedAt sql.NullTime
	for rows.Next() {
		var resp PostResponse
		var createdAt sql.NullTime
		var commentPerm string
		var authorReceivedCentinels int64

		if err := rows.Scan(
			&resp.PostID, &resp.ContentText, &resp.Visibility, &commentPerm, &resp.HideLikesCount,
			&resp.Metrics.Likes, &resp.Metrics.Comments, &resp.Metrics.Shares, &resp.Metrics.Silvers,
			&createdAt,
			&resp.Author.ID, &resp.Author.Username, &resp.Author.FullName, &resp.Author.ProfilePicURL,
			&authorReceivedCentinels,
			&resp.ViewerHasLiked,
		); err != nil {
			return nil, "", err
		}
		fillAuthorRank(&resp.Author, authorReceivedCentinels)

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
		postIDs = append(postIDs, resp.PostID)
	}

	if len(postIDs) > 0 {
		mediaMap, err := r.batchFetchMedia(ctx, postIDs)
		if err != nil {
			return nil, "", err
		}
		r.hydratePostMedia(items, mediaMap)
	}

	nextCursor := ""
	if len(items) == limit && lastCreatedAt.Valid {
		nextCursor = lastCreatedAt.Time.Format(time.RFC3339Nano)
	}

	return items, nextCursor, nil
}
