package feed

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"math"
	"math/rand"
	"time"

	"github.com/google/uuid"
	"github.com/lib/pq"
)

type localActivityStats struct {
	posts   int
	authors int
}

type smartFeedCandidate struct {
	post      PostResponse
	createdAt time.Time
	isAlly    bool
	hasPoint  bool
	lat       float64
	lon       float64
}

// Add new dependencies to Repository interface in feed/repository.go logically
// GetSmartFeed(ctx context.Context, viewerID uuid.UUID, lat, lon float64, cursor string, limit int) ([]PostResponse, string, error)
// RecordLike(ctx context.Context, postID, userID uuid.UUID) error
// GetInteractions(ctx context.Context, postID uuid.UUID, interactionType string, limit int) ([]InteractionResponse, error)
// BatchFlushLikes(ctx context.Context, postID uuid.UUID, userIDs []uuid.UUID) error

// GetSmartFeed implements the Allies/Local (80%) + World (20%) target weighted blending.
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
			SELECT p.id, p.user_id, p.caption, p.visibility, p.comment_permission, p.hide_likes_count,
				p.likes_count, p.comments_count, p.share_count, p.seals_count,
				p.created_at, p.location_lat, p.location_lon,
				COALESCE(p.report_control_level, 0) AS report_control_level,
				COALESCE(p.distribution_multiplier, 1.0) AS distribution_multiplier,
				COALESCE(aps.post_removed_30d, 0) AS author_post_removed_30d,
				(p.user_id IN (SELECT ally_id FROM allies)) AS is_ally
			FROM posts p
			LEFT JOIN LATERAL (
				SELECT COUNT(1) AS post_removed_30d
				FROM author_policy_strikes aps
				WHERE aps.author_id = p.user_id
				  AND aps.strike_type IN ('post_removed', 'comment_removed', 'content_violation')
				  AND aps.created_at >= NOW() - INTERVAL '30 days'
			) aps ON true
			WHERE p.is_archived = false
			  AND p.is_deleted = false
			  AND COALESCE(p.is_hidden_by_reports, false) = false
			  AND COALESCE(p.report_control_level, 0) < 3
			  AND (
				COALESCE(p.report_control_level, 0) = 0
				OR random() <= (
					COALESCE(p.distribution_multiplier, 1.0) *
					CASE
						WHEN COALESCE(aps.post_removed_30d, 0) >= 5 THEN 0.4
						WHEN COALESCE(aps.post_removed_30d, 0) >= 3 THEN 0.7
						ELSE 1.0
					END
				)
			  )
			  AND p.user_id <> $1
			  AND NOT EXISTS (
				SELECT 1
				FROM reported_post_hides rph
				WHERE rph.post_id = p.id
				  AND rph.reporter_id = $1
			  )
			  AND p.created_at < $5
			  AND (p.visibility = 'ANYONE' OR p.user_id IN (SELECT ally_id FROM allies))
			ORDER BY p.created_at DESC, p.id DESC
			LIMIT 200
		)
		SELECT
			p.id, p.caption, p.visibility, p.comment_permission, p.hide_likes_count,
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
		ORDER BY p.created_at DESC, p.id DESC
	`

	if cursor.IsZero() {
		cursor = time.Now()
	}

	rows, err := r.db.QueryContext(ctx, query, viewerID, lat, lon, hasLocation, cursor)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()

	candidates := make([]smartFeedCandidate, 0, limit)
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
			&resp.PostID, &resp.ContentText, &resp.Visibility, &commentPerm, &resp.HideLikesCount,
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
		resp.CommentPermission = commentPerm
		resp.Permissions.CanComment = commentPerm != CommentPermNoOne
		applyHiddenLikesForViewer(&resp, viewerID)

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

		candidate := smartFeedCandidate{
			post:      resp,
			createdAt: createdAt.Time,
			isAlly:    isAlly,
		}
		if hasLocation && pLat.Valid && pLon.Valid {
			candidate.lat = pLat.Float64
			candidate.lon = pLon.Float64
			candidate.hasPoint = true
		} else if isLocal {
			// Fallback path for pre-existing distance-based local calculation.
			candidate.hasPoint = false
		}

		if createdAt.Valid {
			candidates = append(candidates, candidate)
		}
	}

	geoCfg := r.adaptiveGeo.normalize()
	effectiveKRing := 1
	localShare := geoCfg.LocalShareLow
	ringRadii := ringRadiusKmMapWithConfig(geoCfg)

	if hasLocation && geoCfg.Enabled {
		statsByRing := countLocalActivityByRingWithMaxRing(candidates, lat, lon, ringRadii, time.Now(), geoCfg.MaxKRing)
		effectiveKRing = selectLocalKRingWithConfig(statsByRing, geoCfg)
		localShare = localShareForActivityWithConfig(statsByRing[effectiveKRing], geoCfg)
	}

	for _, candidate := range candidates {
		isLocalByRing := false
		if hasLocation && candidate.hasPoint {
			isLocalByRing = distanceKm(lat, lon, candidate.lat, candidate.lon) <= ringRadii[effectiveKRing]
		}

		if candidate.isAlly || isLocalByRing {
			alliesLocal = append(alliesLocal, candidate.post)
		} else {
			world = append(world, candidate.post)
		}
	}

	// 2. Blend the results (target 80% Allies/Local, 20% World with fallback)
	rand.Shuffle(len(world), func(i, j int) { world[i], world[j] = world[j], world[i] })
	blended := blendSmartFeedCandidatesWithShare(alliesLocal, world, limit, localShare)

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

func blendSmartFeedCandidates(alliesLocal, world []PostResponse, limit int) []PostResponse {
	return blendSmartFeedCandidatesWithShare(alliesLocal, world, limit, 0.8)
}

func blendSmartFeedCandidatesWithShare(alliesLocal, world []PostResponse, limit int, localShare float64) []PostResponse {
	if limit <= 0 {
		return []PostResponse{}
	}

	blended := make([]PostResponse, 0, limit)
	aIdx := 0
	wIdx := 0
	deferredAllies := make([]PostResponse, 0)
	deferredWorld := make([]PostResponse, 0)
	authorCounts := make(map[uuid.UUID]int)
	const maxPostsPerAuthorPreferred = 2

	appendWithCap := func(item PostResponse, enforceCap bool, deferred *[]PostResponse) {
		if enforceCap && authorCounts[item.Author.ID] >= maxPostsPerAuthorPreferred {
			*deferred = append(*deferred, item)
			return
		}
		blended = append(blended, item)
		authorCounts[item.Author.ID]++
	}

	if localShare < 0 {
		localShare = 0
	}
	if localShare > 1 {
		localShare = 1
	}

	alliesQuota := int(math.Round(float64(limit) * localShare))
	if alliesQuota < 0 {
		alliesQuota = 0
	}
	if alliesQuota > limit {
		alliesQuota = limit
	}
	worldQuota := limit - alliesQuota
	if len(world) > 0 && worldQuota == 0 && limit > 1 {
		worldQuota = 1
		alliesQuota = limit - worldQuota
	}

	for aIdx < len(alliesLocal) && len(blended) < alliesQuota {
		appendWithCap(alliesLocal[aIdx], true, &deferredAllies)
		aIdx++
	}

	for wIdx < len(world) && len(blended) < alliesQuota+worldQuota {
		appendWithCap(world[wIdx], true, &deferredWorld)
		wIdx++
	}

	for len(blended) < limit && aIdx < len(alliesLocal) {
		appendWithCap(alliesLocal[aIdx], true, &deferredAllies)
		aIdx++
	}
	for len(blended) < limit && wIdx < len(world) {
		appendWithCap(world[wIdx], true, &deferredWorld)
		wIdx++
	}

	for i := 0; i < len(deferredAllies) && len(blended) < limit; i++ {
		appendWithCap(deferredAllies[i], false, nil)
	}
	for i := 0; i < len(deferredWorld) && len(blended) < limit; i++ {
		appendWithCap(deferredWorld[i], false, nil)
	}

	return blended
}

func ringRadiusKmMap() map[int]float64 {
	return ringRadiusKmMapWithConfig(DefaultAdaptiveGeoConfig())
}

func ringRadiusKmMapWithConfig(cfg AdaptiveGeoConfig) map[int]float64 {
	return map[int]float64{
		1: cfg.Ring1RadiusKm,
		2: cfg.Ring2RadiusKm,
		3: cfg.Ring3RadiusKm,
	}
}

func countLocalActivityByRing(candidates []smartFeedCandidate, viewerLat, viewerLon float64, ringRadii map[int]float64, now time.Time) map[int]localActivityStats {
	return countLocalActivityByRingWithMaxRing(candidates, viewerLat, viewerLon, ringRadii, now, feedGeoMaxKRing)
}

func countLocalActivityByRingWithMaxRing(candidates []smartFeedCandidate, viewerLat, viewerLon float64, ringRadii map[int]float64, now time.Time, maxKRing int) map[int]localActivityStats {
	statsByRing := map[int]localActivityStats{}
	authorSets := map[int]map[uuid.UUID]struct{}{}
	for ring := 1; ring <= maxKRing; ring++ {
		authorSets[ring] = map[uuid.UUID]struct{}{}
	}

	windowStart := now.Add(-24 * time.Hour)
	for _, candidate := range candidates {
		if !candidate.hasPoint || candidate.createdAt.Before(windowStart) {
			continue
		}
		d := distanceKm(viewerLat, viewerLon, candidate.lat, candidate.lon)
		for ring := 1; ring <= maxKRing; ring++ {
			if d > ringRadii[ring] {
				continue
			}
			stat := statsByRing[ring]
			stat.posts++
			statsByRing[ring] = stat
			authorSets[ring][candidate.post.Author.ID] = struct{}{}
		}
	}

	for ring := 1; ring <= maxKRing; ring++ {
		stat := statsByRing[ring]
		stat.authors = len(authorSets[ring])
		statsByRing[ring] = stat
	}

	return statsByRing
}

func distanceKm(lat1, lon1, lat2, lon2 float64) float64 {
	const earthRadiusKm = 6371.0
	toRad := func(v float64) float64 { return v * math.Pi / 180.0 }
	dLat := toRad(lat2 - lat1)
	dLon := toRad(lon2 - lon1)
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(toRad(lat1))*math.Cos(toRad(lat2))*math.Sin(dLon/2)*math.Sin(dLon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return earthRadiusKm * c
}

func selectLocalKRing(statsByRing map[int]localActivityStats) int {
	return selectLocalKRingWithConfig(statsByRing, DefaultAdaptiveGeoConfig())
}

func selectLocalKRingWithConfig(statsByRing map[int]localActivityStats, cfg AdaptiveGeoConfig) int {
	for ring := 1; ring <= cfg.MaxKRing; ring++ {
		stat := statsByRing[ring]
		if stat.posts >= cfg.MinLocalPosts24h && stat.authors >= cfg.MinLocalAuthors24h {
			return ring
		}
	}
	return cfg.MaxKRing
}

func localShareForActivity(stats localActivityStats) float64 {
	return localShareForActivityWithConfig(stats, DefaultAdaptiveGeoConfig())
}

func localShareForActivityWithConfig(stats localActivityStats, cfg AdaptiveGeoConfig) float64 {
	if stats.posts >= cfg.MinLocalPosts24h && stats.authors >= cfg.MinLocalAuthors24h {
		return cfg.LocalShareHigh
	}
	if stats.posts >= cfg.MedLocalPosts24h && stats.authors >= cfg.MedLocalAuthors24h {
		return cfg.LocalShareMedium
	}
	return cfg.LocalShareLow
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
