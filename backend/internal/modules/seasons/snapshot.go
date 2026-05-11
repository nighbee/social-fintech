package seasons

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"

	"github.com/brightbund-backend/internal/modules/ranks"
	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
)

// centinelsPerSeal mirrors economy.CentinelsPerSeal. Duplicated here to
// avoid importing the economy module (which would create a circular
// dependency once economy starts importing seasons or ranks).
const centinelsPerSeal int64 = 100

// Per-user position scopes mirrored in the archive. We do NOT compute a
// world/global leaderboard — every standing is local to the user's
// city, region, or country. The typed columns store the user's tightest
// available scope; the JSONB payload carries all three.
const (
	scopeCity    = "city"
	scopeRegion  = "region"
	scopeCountry = "country"
)

// snapshotProvider implements seasons.SnapshotProvider. For a given
// season window it walks every user that received or sent Gold Seals
// during that window, computes their final rank/level from the
// seasonal received total, and produces an ArchiveItem per user.
//
// Positions are assigned WITHIN each user's geography: a position in
// the user's city, region, and country respectively (PARTITION BY each
// H3 resolution, ordered by seasonal received seals). Users with no
// region state are archived with NULL positions — they have a rank but
// no leaderboard standing. Users with received=0 are also archived
// (because they may have given seals) but with NULL positions, since
// "rank" is undefined for pure givers.
type snapshotProvider struct {
	db *sqlx.DB
}

// NewSnapshotProvider builds a SnapshotProvider backed by the given
// database. Pass it to seasons.Service.CloseDueSeasons.
func NewSnapshotProvider(db *sqlx.DB) SnapshotProvider {
	return &snapshotProvider{db: db}
}

type snapshotRow struct {
	UserID            uuid.UUID      `db:"user_id"`
	ReceivedCentinels int64          `db:"received_centinels"`
	SentCentinels     int64          `db:"sent_centinels"`
	H3Res5            sql.NullString `db:"h3_res5"`
	H3Res4            sql.NullString `db:"h3_res4"`
	H3Res2            sql.NullString `db:"h3_res2"`
	CityPosition      sql.NullInt64  `db:"city_position"`
	RegionPosition    sql.NullInt64  `db:"region_position"`
	CountryPosition   sql.NullInt64  `db:"country_position"`
	CityName          sql.NullString `db:"city_name"`
	RegionName        sql.NullString `db:"region_name"`
	CountryName       sql.NullString `db:"country_name"`
}

// scopeEntry is one (h3, name, position) triple inside the JSONB
// payload, one per geographic level the user belongs to.
type scopeEntry struct {
	H3       string `json:"h3,omitempty"`
	Name     string `json:"name,omitempty"`
	Position *int   `json:"position,omitempty"`
}

// SnapshotSeason aggregates Gold Seal flow for the season window and
// returns one ArchiveItem per participating user. The seasons service
// will fill in SeasonID/SeasonYear/SeasonHalf and persist them.
func (p *snapshotProvider) SnapshotSeason(ctx context.Context, season *Season) ([]ArchiveItem, error) {
	const query = `
		WITH gold_wallets AS (
		    SELECT id, user_id FROM wallets WHERE currency = 'GOLD_SEAL'
		),
		season_recv AS (
		    SELECT w.user_id, COALESCE(SUM(le.amount), 0) AS amount
		    FROM ledger_entries le
		    JOIN gold_wallets w ON w.id = le.receiver_wallet_id
		    WHERE le.currency = 'GOLD_SEAL'
		      AND le.created_at >= $1 AND le.created_at < $2
		    GROUP BY w.user_id
		),
		season_sent AS (
		    SELECT w.user_id, COALESCE(SUM(le.amount), 0) AS amount
		    FROM ledger_entries le
		    JOIN gold_wallets w ON w.id = le.sender_wallet_id
		    WHERE le.currency = 'GOLD_SEAL'
		      AND le.created_at >= $1 AND le.created_at < $2
		    GROUP BY w.user_id
		),
		all_users AS (
		    SELECT user_id FROM season_recv
		    UNION
		    SELECT user_id FROM season_sent
		),
		joined AS (
		    SELECT
		        au.user_id,
		        COALESCE(r.amount, 0) AS received_centinels,
		        COALESCE(s.amount, 0) AS sent_centinels,
		        urs.h3_res5,
		        urs.h3_res4,
		        urs.h3_res2
		    FROM all_users au
		    LEFT JOIN season_recv r ON r.user_id = au.user_id
		    LEFT JOIN season_sent s ON s.user_id = au.user_id
		    LEFT JOIN user_region_state urs ON urs.user_id = au.user_id
		),
		ranked AS (
		    SELECT
		        user_id,
		        received_centinels,
		        sent_centinels,
		        h3_res5, h3_res4, h3_res2,
		        CASE WHEN received_centinels > 0 AND h3_res5 IS NOT NULL
		             THEN ROW_NUMBER() OVER (
		                 PARTITION BY h3_res5
		                 ORDER BY received_centinels DESC, user_id
		             )
		        END AS city_position,
		        CASE WHEN received_centinels > 0 AND h3_res4 IS NOT NULL
		             THEN ROW_NUMBER() OVER (
		                 PARTITION BY h3_res4
		                 ORDER BY received_centinels DESC, user_id
		             )
		        END AS region_position,
		        CASE WHEN received_centinels > 0 AND h3_res2 IS NOT NULL
		             THEN ROW_NUMBER() OVER (
		                 PARTITION BY h3_res2
		                 ORDER BY received_centinels DESC, user_id
		             )
		        END AS country_position
		    FROM joined
		)
		SELECT
		    r.user_id,
		    r.received_centinels,
		    r.sent_centinels,
		    r.h3_res5,
		    r.h3_res4,
		    r.h3_res2,
		    r.city_position,
		    r.region_position,
		    r.country_position,
		    gm5.city_name    AS city_name,
		    gm4.region_name  AS region_name,
		    gm2.country_name AS country_name
		FROM ranked r
		LEFT JOIN h3_geo_metadata gm5 ON gm5.h3_index = r.h3_res5
		LEFT JOIN h3_geo_metadata gm4 ON gm4.h3_index = r.h3_res4
		LEFT JOIN h3_geo_metadata gm2 ON gm2.h3_index = r.h3_res2
		ORDER BY r.received_centinels DESC, r.user_id ASC
	`

	var rows []snapshotRow
	if err := p.db.SelectContext(ctx, &rows, query, season.StartsAt, season.EndsAt); err != nil {
		return nil, fmt.Errorf("seasons snapshot: aggregate ledger: %w", err)
	}

	items := make([]ArchiveItem, 0, len(rows))
	for _, row := range rows {
		receivedSeals := row.ReceivedCentinels / centinelsPerSeal
		givenSeals := row.SentCentinels / centinelsPerSeal

		rank, level, _, _ := ranks.CalculateRankAndLevel(int(receivedSeals))

		cityEntry := buildScopeEntry(row.H3Res5, row.CityName, row.CityPosition)
		regionEntry := buildScopeEntry(row.H3Res4, row.RegionName, row.RegionPosition)
		countryEntry := buildScopeEntry(row.H3Res2, row.CountryName, row.CountryPosition)

		primaryScope, primaryLabel, primaryPosition := pickPrimaryScope(cityEntry, regionEntry, countryEntry)

		payload, err := json.Marshal(map[string]any{
			"rank_id":            rank.ID,
			"rank_name":          rank.Name,
			"rank_quality":       rank.Quality,
			"rank_level":         level,
			"received_seals":     receivedSeals,
			"given_seals":        givenSeals,
			"received_centinels": row.ReceivedCentinels,
			"given_centinels":    row.SentCentinels,
			"scopes": map[string]scopeEntry{
				scopeCity:    cityEntry,
				scopeRegion:  regionEntry,
				scopeCountry: countryEntry,
			},
		})
		if err != nil {
			return nil, fmt.Errorf("seasons snapshot: marshal payload: %w", err)
		}

		items = append(items, ArchiveItem{
			UserID:          row.UserID,
			FinalPosition:   primaryPosition,
			SealCount:       receivedSeals,
			Scope:           primaryScope,
			Region:          primaryLabel,
			SnapshotPayload: payload,
		})
	}

	return items, nil
}

// buildScopeEntry packages one scope's H3 index, human-readable name,
// and position into a single payload-friendly struct. Empty / NULL
// values are zero-valued so they JSON-marshal away via omitempty.
func buildScopeEntry(h3 sql.NullString, name sql.NullString, position sql.NullInt64) scopeEntry {
	entry := scopeEntry{}
	if h3.Valid {
		entry.H3 = h3.String
	}
	if name.Valid {
		entry.Name = name.String
	}
	if position.Valid {
		pos := int(position.Int64)
		entry.Position = &pos
	}
	return entry
}

// pickPrimaryScope returns the tightest scope the user belongs to,
// using city > region > country. The returned label prefers the
// human-readable name and falls back to the H3 index if the geo
// metadata cache has not yet resolved the cell.
func pickPrimaryScope(city, region, country scopeEntry) (scope, label string, position *int) {
	switch {
	case city.H3 != "":
		return scopeCity, firstNonEmpty(city.Name, city.H3), city.Position
	case region.H3 != "":
		return scopeRegion, firstNonEmpty(region.Name, region.H3), region.Position
	case country.H3 != "":
		return scopeCountry, firstNonEmpty(country.Name, country.H3), country.Position
	}
	return "", "", nil
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}
