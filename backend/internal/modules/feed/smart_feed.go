package feed

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"math/rand"
	"time"

	"github.com/google/uuid"
	"github.com/lib/pq"
)

// Add new dependencies to Repository interface in feed/repository.go logically
// GetSmartFeed(ctx context.Context, viewerID uuid.UUID, lat, lon float64, cursor string, limit int) ([]PostResponse, string, error)
// RecordLike(ctx context.Context, postID, userID uuid.UUID) error
// GetInteractions(ctx context.Context, postID uuid.UUID, interactionType string, limit int) ([]InteractionResponse, error)
// BatchFlushLikes(ctx context.Context, postID uuid.UUID, userIDs []uuid.UUID) error

// GetSmartFeed implements the Allies (80%) + Local (Geo) + World (10%) weighted blending.
func (r *repository) GetSmartFeed(ctx context.Context, viewerID uuid.UUID, lat, lon float64, hasLocation bool, cursor time.Time, limit int) ([]PostResponse, string, error) {
	// 1. Fetch Candidates (Limit 100 to sort and blend in memory)
	// CTEs:
	// - Allies: users we follow
	// - Local: posts within 50km
	// - World: fallback
	query := `
		WITH allies AS (
			SELECT target_user_id AS ally_id
			FROM user_relationships
			WHERE user_id = $1
			  AND relationship_type = 'ally'
		),
		base_posts AS (
			SELECT p.id, p.user_id, p.caption, p.visibility, p.comment_permission,
				p.likes_count, p.comments_count, p.share_count, p.seals_count,
				p.created_at, p.location_lat, p.location_lon,
				(p.user_id IN (SELECT ally_id FROM allies)) AS is_ally
			FROM posts p
			WHERE p.is_archived = false
			  AND COALESCE(p.is_hidden_by_reports, false) = false
			  AND p.created_at < $5
			  AND (p.visibility = 'ANYONE' OR p.user_id = $1 OR p.user_id IN (SELECT ally_id FROM allies))
			ORDER BY p.created_at DESC
			LIMIT 200
		)
		SELECT
			p.id, p.caption, p.visibility, p.comment_permission,
			p.likes_count, p.comments_count, p.share_count, p.seals_count,
			p.created_at, p.location_lat, p.location_lon,
			u.id as author_id,
			COALESCE(u.username, '') as username,
			COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '') as full_name,
			COALESCE(prof.avatar_url, '') as profile_picture_url,

			-- Media as JSON array via LATERAL
			COALESCE(media.media_json, '[]'::json) as media_json,

			-- Whether viewer already liked this post
			EXISTS (
			    SELECT 1 FROM post_interactions pi
			    WHERE pi.post_id = p.id
			      AND pi.user_id = $1
			      AND pi.interaction_type = 'like'
			) AS viewer_has_liked,

			p.is_ally,
			CASE
			    WHEN $4 THEN (
			        p.location_lat IS NOT NULL AND p.location_lon IS NOT NULL AND
			        ST_DWithin(
			            ST_SetSRID(ST_MakePoint(p.location_lon, p.location_lat), 4326)::geography,
			            ST_SetSRID(ST_MakePoint($3, $2), 4326)::geography,
			            50000
			        )
			    )
			    ELSE false
			END AS is_local
		FROM base_posts p
		JOIN users u ON p.user_id = u.id
		LEFT JOIN profiles prof ON prof.user_id = u.id
		LEFT JOIN LATERAL (
			SELECT json_agg(json_build_object(
				'type', pm.media_type,
				'url', pm.media_url,
				'thumbnail_url', pm.thumbnail_url
			) ORDER BY pm.media_order) as media_json
			FROM post_media pm 
			WHERE pm.post_id = p.id
		) media ON true
		ORDER BY p.created_at DESC
	`

	if cursor.IsZero() {
		cursor = time.Now()
	}

	rows, err := r.db.QueryContext(ctx, query, viewerID, lat, lon, hasLocation, cursor)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()

	var alliesLocal []PostResponse
	var world []PostResponse
	createdAtMap := make(map[uuid.UUID]time.Time)

	for rows.Next() {
		var resp PostResponse
		var mediaJSON []byte
		var createdAt sql.NullTime
		var isAlly, isLocal bool
		var pLat, pLon sql.NullFloat64
		var commentPerm string

		err := rows.Scan(
			&resp.PostID, &resp.ContentText, &resp.Visibility, &commentPerm,
			&resp.Metrics.Likes, &resp.Metrics.Comments, &resp.Metrics.Shares, &resp.Metrics.Silvers,
			&createdAt, &pLat, &pLon,
			&resp.Author.ID, &resp.Author.Username, &resp.Author.FullName, &resp.Author.ProfilePicURL,
			&mediaJSON,
			&resp.ViewerHasLiked,
			&isAlly, &isLocal,
		)
		if err != nil {
			return nil, "", err
		}

		_ = json.Unmarshal(mediaJSON, &resp.MediaAttachments)

		// Derive computed fields
		resp.Permissions.CanComment = commentPerm != CommentPermNoOne
		resp.IsOwnPost = resp.Author.ID == viewerID

		// time_ago is computed from createdAt
		if createdAt.Valid {
			createdAtMap[resp.PostID] = createdAt.Time
			elapsed := time.Since(createdAt.Time)
			switch {
			case elapsed < time.Hour:
				resp.TimeAgo = fmt.Sprintf("%dm", int(elapsed.Minutes()))
			case elapsed < 24*time.Hour:
				resp.TimeAgo = fmt.Sprintf("%dh", int(elapsed.Hours()))
			default:
				resp.TimeAgo = fmt.Sprintf("%dd", int(elapsed.Hours()/24))
			}
		}

		if isAlly || isLocal {
			alliesLocal = append(alliesLocal, resp)
		} else {
			world = append(world, resp)
		}
	}

	// 2. Blend the results (80% Allies/Local, 20% World)
	rand.Shuffle(len(world), func(i, j int) { world[i], world[j] = world[j], world[i] })

	blended := make([]PostResponse, 0, limit)
	aIdx, wIdx := 0, 0

	for len(blended) < limit && (aIdx < len(alliesLocal) || wIdx < len(world)) {
		// Take 8 from Allies/Local, 2 from World
		for i := 0; i < 8 && aIdx < len(alliesLocal) && len(blended) < limit; i++ {
			blended = append(blended, alliesLocal[aIdx])
			aIdx++
		}
		for i := 0; i < 2 && wIdx < len(world) && len(blended) < limit; i++ {
			blended = append(blended, world[wIdx])
			wIdx++
		}
	}

	// Next cursor is the oldest created_at from the returned set
	nextCursorStr := ""
	if len(blended) > 0 {
		var oldest time.Time
		for _, item := range blended {
			createdAt, ok := createdAtMap[item.PostID]
			if !ok {
				continue
			}
			if oldest.IsZero() || createdAt.Before(oldest) {
				oldest = createdAt
			}
		}
		if !oldest.IsZero() {
			nextCursorStr = oldest.Format(time.RFC3339Nano)
		}
	}

	return blended, nextCursorStr, nil
}

// BatchFlushLikes executes the bulk insertion for background Redis syncing.
func (r *repository) BatchFlushLikes(ctx context.Context, postID uuid.UUID, userIDs []uuid.UUID) error {
	if len(userIDs) == 0 {
		return nil
	}

	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Using UNNEST for fast bulk inserts
	queryInsert := `
		INSERT INTO post_interactions (post_id, user_id, interaction_type, created_at)
		SELECT $1, unnest($2::uuid[]), 'like', NOW()
		ON CONFLICT (post_id, user_id, interaction_type) DO NOTHING
	`

	res, err := tx.ExecContext(ctx, queryInsert, postID, pq.Array(userIDs))
	if err != nil {
		return err
	}

	rowsAffected, _ := res.RowsAffected()

	if rowsAffected > 0 {
		// Batch increment likes_count on the post
		queryUpdate := `UPDATE posts SET likes_count = likes_count + $1 WHERE id = $2`
		if _, err := tx.ExecContext(ctx, queryUpdate, rowsAffected, postID); err != nil {
			return err
		}
	}

	return tx.Commit()
}

// BatchFlushSeals handles the post denormalization. The actual Economy Ledger happened previously inline.
func (r *repository) BatchFlushSeals(ctx context.Context, postID uuid.UUID, count int, totalAmount int64) error {
	if count == 0 {
		return nil
	}

	query := `UPDATE posts SET seals_count = seals_count + $1, seals_amount = seals_amount + $2 WHERE id = $3`
	_, err := r.db.ExecContext(ctx, query, count, totalAmount, postID)
	return err
}
