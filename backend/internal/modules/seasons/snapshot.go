package seasons

import (
	"context"
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

// snapshotProvider implements seasons.SnapshotProvider. For a given
// season window it walks every user that received or sent Gold Seals
// during that window, computes their final rank/level from the
// seasonal received total, and produces an ArchiveItem per user.
//
// Final positions are assigned globally (1 = top by seasonal received),
// with ties broken by user_id for determinism. Users who received zero
// during the season get a NULL final_position — they are kept in the
// archive only because they sent seals, and "rank" is undefined for
// pure givers.
type snapshotProvider struct {
	db *sqlx.DB
}

// NewSnapshotProvider builds a SnapshotProvider backed by the given
// database. Pass it to seasons.Service.CloseDueSeasons.
func NewSnapshotProvider(db *sqlx.DB) SnapshotProvider {
	return &snapshotProvider{db: db}
}

type snapshotRow struct {
	UserID            uuid.UUID `db:"user_id"`
	ReceivedCentinels int64     `db:"received_centinels"`
	SentCentinels     int64     `db:"sent_centinels"`
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
		)
		SELECT
		    au.user_id,
		    COALESCE(r.amount, 0) AS received_centinels,
		    COALESCE(s.amount, 0) AS sent_centinels
		FROM all_users au
		LEFT JOIN season_recv r ON r.user_id = au.user_id
		LEFT JOIN season_sent s ON s.user_id = au.user_id
		ORDER BY received_centinels DESC, au.user_id ASC
	`

	var rows []snapshotRow
	if err := p.db.SelectContext(ctx, &rows, query, season.StartsAt, season.EndsAt); err != nil {
		return nil, fmt.Errorf("seasons snapshot: aggregate ledger: %w", err)
	}

	items := make([]ArchiveItem, 0, len(rows))
	position := 0
	for _, row := range rows {
		receivedSeals := row.ReceivedCentinels / centinelsPerSeal
		givenSeals := row.SentCentinels / centinelsPerSeal

		rank, level, _, _ := ranks.CalculateRankAndLevel(int(receivedSeals))

		var finalPos *int
		if receivedSeals > 0 {
			position++
			pos := position
			finalPos = &pos
		}

		payload, err := json.Marshal(map[string]any{
			"rank_id":            rank.ID,
			"rank_name":          rank.Name,
			"rank_quality":       rank.Quality,
			"rank_level":         level,
			"received_seals":     receivedSeals,
			"given_seals":        givenSeals,
			"received_centinels": row.ReceivedCentinels,
			"given_centinels":    row.SentCentinels,
		})
		if err != nil {
			return nil, fmt.Errorf("seasons snapshot: marshal payload: %w", err)
		}

		items = append(items, ArchiveItem{
			UserID:          row.UserID,
			FinalPosition:   finalPos,
			SealCount:       receivedSeals,
			Scope:           "global",
			SnapshotPayload: payload,
		})
	}

	return items, nil
}
