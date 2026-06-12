package feed

import (
	"context"
	"database/sql"
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
	post             PostResponse
	createdAt        time.Time
	isAlly           bool
	hasPoint         bool
	lat              float64
	lon              float64
	reportControl    int
	distributionMult float64
	strikeCount      int
}

type feedRow struct {
	PostID                 uuid.UUID      `db:"id"`
	Caption                string         `db:"caption"`
	Visibility             string         `db:"visibility"`
	CommentPermission      string         `db:"comment_permission"`
	HideLikesCount         bool           `db:"hide_likes_count"`
	LikesCount             int            `db:"likes_count"`
	CommentsCount          int            `db:"comments_count"`
	ShareCount             int            `db:"share_count"`
	SealsCount             int            `db:"seals_count"`
	CreatedAt              sql.NullTime   `db:"created_at"`
	LocationLat            sql.NullFloat64 `db:"location_lat"`
	LocationLon            sql.NullFloat64 `db:"location_lon"`
	AuthorID               uuid.UUID      `db:"author_id"`
	Username               string         `db:"username"`
	FullName               string         `db:"full_name"`
	ProfilePictureURL       string         `db:"profile_picture_url"`
	AuthorReceivedCentinels int64          `db:"author_received_centinels"`
	ViewerHasLiked         bool           `db:"viewer_has_liked"`
	IsAlly                 bool           `db:"is_ally"`
	IsLocal                bool           `db:"is_local"`
	ReportControlLevel     int            `db:"report_control_level"`
	DistributionMultiplier float64        `db:"distribution_multiplier"`
	StrikeCount            int            `db:"strike_count"`
}

// batchFetchMedia fetches media attachments for the given post IDs in one query.
func (r *repository) batchFetchMedia(ctx context.Context, postIDs []uuid.UUID) (map[uuid.UUID][]MediaAttachment, error) {
	if len(postIDs) == 0 {
		return map[uuid.UUID][]MediaAttachment{}, nil
	}

	query := `
		SELECT post_id, media_type, video_1080p_url, video_480p_url, thumbnail_url, media_order
		FROM post_media
		WHERE post_id = ANY($1::uuid[])
		ORDER BY post_id, media_order
	`
	rows, err := r.db.QueryContext(ctx, query, pq.Array(postIDs))
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := make(map[uuid.UUID][]MediaAttachment, len(postIDs))
	for rows.Next() {
		var postID uuid.UUID
		var m MediaAttachment
		var mediaOrder int
		if err := rows.Scan(&postID, &m.Type, &m.URL_1080p, &m.URL_480p, &m.ThumbnailURL, &mediaOrder); err != nil {
			return nil, err
		}
		m.URL = m.URL_1080p
		m.ImageURL = m.URL_1080p
		result[postID] = append(result[postID], m)
	}

	return result, nil
}

// hydratePostMedia applies buildURL to all media fields and assigns media to posts.
func (r *repository) hydratePostMedia(posts []PostResponse, mediaMap map[uuid.UUID][]MediaAttachment) {
	for i := range posts {
		media, ok := mediaMap[posts[i].PostID]
		if !ok {
			posts[i].MediaAttachments = []MediaAttachment{}
			continue
		}
		hydrated := make([]MediaAttachment, len(media))
		copy(hydrated, media)
		for j := range hydrated {
			hydrated[j].URL_1080p = r.buildURL(hydrated[j].URL_1080p)
			hydrated[j].URL = hydrated[j].URL_1080p
			hydrated[j].ImageURL = hydrated[j].URL_1080p
			hydrated[j].URL_480p = r.buildURL(hydrated[j].URL_480p)
			hydrated[j].ThumbnailURL = r.buildURL(hydrated[j].ThumbnailURL)
		}
		posts[i].MediaAttachments = hydrated
	}
}

// distributionPenalty returns a multiplier factor based on strike count.
func distributionPenalty(strikes int) float64 {
	switch {
	case strikes >= 5:
		return 0.4
	case strikes >= 3:
		return 0.7
	default:
		return 1.0
	}
}

// getAllyIDsForFeed fetches the viewer's ally user IDs for feed visibility filtering.
func (r *repository) getAllyIDsForFeed(ctx context.Context, viewerID uuid.UUID) ([]uuid.UUID, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT target_user_id
		FROM user_relationships
		WHERE user_id = $1 AND relationship_type = 'ally'
	`, viewerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var ids []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	if ids == nil {
		ids = []uuid.UUID{}
	}
	return ids, nil
}

// GetSmartFeed implements the Allies/Local + World target weighted blending.
func (r *repository) GetSmartFeed(ctx context.Context, viewerID uuid.UUID, lat, lon float64, hasLocation bool, cursor time.Time, limit int) ([]PostResponse, string, error) {
	allyIDs, err := r.getAllyIDsForFeed(ctx, viewerID)
	if err != nil {
		return nil, "", err
	}

	query := `
		WITH base_posts AS (
			SELECT p.id, p.user_id, p.caption, p.visibility, p.comment_permission, p.hide_likes_count,
				p.likes_count, p.comments_count, p.share_count, p.seals_count,
				p.created_at, p.location_lat, p.location_lon,
				COALESCE(p.report_control_level, 0) AS report_control_level,
				COALESCE(p.distribution_multiplier, 1.0) AS distribution_multiplier,
				COALESCE(p.current_strike_count, 0) AS strike_count,
				CASE WHEN $6::uuid[] IS NOT NULL AND array_length($6::uuid[], 1) > 0 AND p.user_id = ANY($6::uuid[]) THEN true ELSE false END AS is_ally
			FROM posts p
			WHERE
				p.is_archived = false
			  AND p.is_deleted = false
			  AND (
				p.user_id = $1
				OR NOT EXISTS (
					SELECT 1
					FROM users au
					WHERE au.id = p.user_id
					  AND au.is_shadow_banned = true
				)
			  )
			  AND COALESCE(p.is_hidden_by_reports, false) = false
			  AND COALESCE(p.report_control_level, 0) < 4
			  AND p.user_id <> $1
			  AND NOT EXISTS (
				SELECT 1
				FROM reported_post_hides rph
				WHERE rph.post_id = p.id
				  AND rph.reporter_id = $1
			  )
			  AND p.created_at < $5
			  AND (p.visibility = 'ANYONE' OR (array_length($6::uuid[], 1) > 0 AND p.user_id = ANY($6::uuid[])))
			ORDER BY p.created_at DESC, p.id DESC
			LIMIT 300
		) p.is_archived = false
			  AND p.is_deleted = false
			  AND (
				p.user_id = $1
				OR NOT EXISTS (
					SELECT 1
					FROM users au
					WHERE au.id = p.user_id
					  AND au.is_shadow_banned = true
				)
			  )
			  AND COALESCE(p.is_hidden_by_reports, false) = false
			  AND COALESCE(p.report_control_level, 0) < 4
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
			LIMIT 300
		)
		SELECT
			p.id, p.caption, p.visibility, p.comment_permission, p.hide_likes_count,
			p.likes_count, p.comments_count, p.share_count, p.seals_count,
			p.created_at, p.location_lat, p.location_lon,
			u.id as author_id,
			COALESCE(u.username, '') as username,
			COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '') as full_name,
			COALESCE(prof.avatar_url, '') as profile_picture_url,
			COALESCE(prof.total_gold_seals_received, 0) * 100 as author_received_centinels,
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
			        EXISTS (
			            SELECT 1 FROM posts geo_p
			            WHERE geo_p.id = p.id
			              AND ST_DWithin(
			                  ST_SetSRID(ST_MakePoint(geo_p.location_lon, geo_p.location_lat), 4326)::geography,
			                  ST_SetSRID(ST_MakePoint($3, $2), 4326)::geography,
			                  50000
			              )
			        )
			    )
			    ELSE false
			END AS is_local,
			p.report_control_level,
			p.distribution_multiplier,
			p.strike_count
		FROM base_posts p
		JOIN users u ON p.user_id = u.id
		LEFT JOIN profiles prof ON prof.user_id = u.id
		ORDER BY p.created_at DESC, p.id DESC
	`

	if cursor.IsZero() {
		cursor = time.Now()
	}

	rows, err := r.db.QueryContext(ctx, query, viewerID, lat, lon, hasLocation, cursor, pq.Array(allyIDs))
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()

	// Collect post IDs for batch media fetch
	postIDs := make([]uuid.UUID, 0, 300)
	var rawRows []feedRow

	for rows.Next() {
		var fr feedRow
		err := rows.Scan(
			&fr.PostID, &fr.Caption, &fr.Visibility, &fr.CommentPermission, &fr.HideLikesCount,
			&fr.LikesCount, &fr.CommentsCount, &fr.ShareCount, &fr.SealsCount,
			&fr.CreatedAt, &fr.LocationLat, &fr.LocationLon,
			&fr.AuthorID, &fr.Username, &fr.FullName, &fr.ProfilePictureURL,
			&fr.AuthorReceivedCentinels,
			&fr.ViewerHasLiked,
			&fr.IsAlly, &fr.IsLocal,
			&fr.ReportControlLevel, &fr.DistributionMultiplier, &fr.StrikeCount,
		)
		if err != nil {
			return nil, "", err
		}
		if fr.CreatedAt.Valid {
			postIDs = append(postIDs, fr.PostID)
			rawRows = append(rawRows, fr)
		}
	}

	// Batch fetch all media in one query
	mediaMap, err := r.batchFetchMedia(ctx, postIDs)
	if err != nil {
		return nil, "", err
	}

	// Build candidates with Go-side distribution filtering
	// Replace random() with deterministic single-seed sampling
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))
	candidates := make([]smartFeedCandidate, 0, limit)
	createdAtMap := make(map[uuid.UUID]time.Time)

	for _, fr := range rawRows {
		// Go-side shadow-ban distribution check (replaces SQL random())
		if fr.ReportControlLevel > 0 {
			threshold := fr.DistributionMultiplier * distributionPenalty(fr.StrikeCount)
			if rng.Float64() > threshold {
				continue
			}
		}

		resp := PostResponse{
			PostID:            fr.PostID,
			ContentText:       fr.Caption,
			Visibility:        fr.Visibility,
			CommentPermission: fr.CommentPermission,
			HideLikesCount:    fr.HideLikesCount,
			Author: AuthorInfo{
				ID:            fr.AuthorID,
				Username:      fr.Username,
				FullName:      fr.FullName,
				ProfilePicURL: r.buildURL(fr.ProfilePictureURL),
			},
			ViewerHasLiked: fr.ViewerHasLiked,
			Metrics: PostMetrics{
				Likes:    fr.LikesCount,
				Comments: fr.CommentsCount,
				Shares:   fr.ShareCount,
				Silvers:  int64(fr.SealsCount),
			},
			Permissions: Permissions{
				CanComment: fr.CommentPermission != CommentPermNoOne,
			},
		}

		fillAuthorRank(&resp.Author, fr.AuthorReceivedCentinels)
		applyHiddenLikesForViewer(&resp, viewerID)

		if fr.CreatedAt.Valid {
			createdAtMap[resp.PostID] = fr.CreatedAt.Time
			elapsed := time.Since(fr.CreatedAt.Time)
			switch {
			case elapsed < time.Hour:
				resp.TimeAgo = fmt.Sprintf("%dm", int(elapsed.Minutes()))
			case elapsed < 24*time.Hour:
				resp.TimeAgo = fmt.Sprintf("%dh", int(elapsed.Hours()))
			default:
				resp.TimeAgo = fmt.Sprintf("%dd", int(elapsed.Hours()/24))
			}
		}

		// Hydrate media from batch fetch
		if media, ok := mediaMap[resp.PostID]; ok {
			hydrated := make([]MediaAttachment, len(media))
			copy(hydrated, media)
			for j := range hydrated {
				hydrated[j].URL_1080p = r.buildURL(hydrated[j].URL_1080p)
				hydrated[j].URL = hydrated[j].URL_1080p
				hydrated[j].ImageURL = hydrated[j].URL_1080p
				hydrated[j].URL_480p = r.buildURL(hydrated[j].URL_480p)
				hydrated[j].ThumbnailURL = r.buildURL(hydrated[j].ThumbnailURL)
			}
			resp.MediaAttachments = hydrated
		}

		candidate := smartFeedCandidate{
			post:      resp,
			createdAt: fr.CreatedAt.Time,
			isAlly:    fr.IsAlly,
		}
		if hasLocation && fr.LocationLat.Valid && fr.LocationLon.Valid {
			candidate.lat = fr.LocationLat.Float64
			candidate.lon = fr.LocationLon.Float64
			candidate.hasPoint = true
		} else if fr.IsLocal {
			candidate.hasPoint = false
		}

		candidates = append(candidates, candidate)
	}

	// Cap at 200 for blending (matching old behavior after distribution filter)
	if len(candidates) > 200 {
		candidates = candidates[:200]
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

	var alliesLocal []PostResponse
	var world []PostResponse

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

	rand.Shuffle(len(world), func(i, j int) { world[i], world[j] = world[j], world[i] })
	blended := blendSmartFeedCandidatesWithShare(alliesLocal, world, limit, localShare)

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
	authorCounts := make(map[uuid.UUID]int)
	seenPostIDs := make(map[uuid.UUID]bool)
	const maxPostsPerAuthor = 2

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

	tryAppend := func(item PostResponse) bool {
		if seenPostIDs[item.PostID] {
			return false
		}
		if authorCounts[item.Author.ID] >= maxPostsPerAuthor {
			return false
		}
		blended = append(blended, item)
		seenPostIDs[item.PostID] = true
		authorCounts[item.Author.ID]++
		return true
	}

	aIdx := 0
	wIdx := 0
	alliesAdded := 0
	worldAdded := 0

	for alliesAdded < alliesQuota && aIdx < len(alliesLocal) {
		if tryAppend(alliesLocal[aIdx]) {
			alliesAdded++
		}
		aIdx++
	}

	for worldAdded < worldQuota && wIdx < len(world) {
		if tryAppend(world[wIdx]) {
			worldAdded++
		}
		wIdx++
	}

	for len(blended) < limit && (aIdx < len(alliesLocal) || wIdx < len(world)) {
		addedInLoop := false

		if aIdx < len(alliesLocal) {
			if tryAppend(alliesLocal[aIdx]) {
				addedInLoop = true
			}
			aIdx++
		}

		if len(blended) < limit && wIdx < len(world) {
			if tryAppend(world[wIdx]) {
				addedInLoop = true
			}
			wIdx++
		}

		if !addedInLoop && aIdx >= len(alliesLocal) && wIdx >= len(world) {
			break
		}
	}

	if len(blended) < limit {
		appendWithoutAuthorCap := func(items []PostResponse) {
			for _, item := range items {
				if len(blended) >= limit {
					return
				}
				if seenPostIDs[item.PostID] {
					continue
				}
				blended = append(blended, item)
				seenPostIDs[item.PostID] = true
			}
		}

		appendWithoutAuthorCap(alliesLocal)
		appendWithoutAuthorCap(world)
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
		queryUpdate := `UPDATE posts SET likes_count = likes_count + $1 WHERE id = $2`
		if _, err := tx.ExecContext(ctx, queryUpdate, rowsAffected, postID); err != nil {
			return err
		}
	}

	return tx.Commit()
}

// BatchFlushSeals handles the post denormalization. Combined subquery for single ledger scan.
func (r *repository) BatchFlushSeals(ctx context.Context, postID uuid.UUID, count int, totalAmount int64) error {
	query := `
		UPDATE posts
		SET (seals_count, seals_amount) = (
			SELECT COALESCE(COUNT(1), 0), COALESCE(SUM(amount), 0)
			FROM ledger_entries
			WHERE category = 'POST_SEAL'
			  AND metadata->>'post_id' = $1
			  AND receiver_wallet_id IS NOT NULL
		)
		WHERE id = $2
	`
	_, err := r.db.ExecContext(ctx, query, postID.String(), postID)
	return err
}
