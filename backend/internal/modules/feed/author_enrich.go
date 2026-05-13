package feed

import "github.com/brightbund-backend/internal/modules/ranks"

// fillAuthorRank populates the author's Rank tier string and
// ReputationScore from the user's lifetime received Gold Seal
// centinels. Per the ranks spec, rank is driven by received seals,
// not balance — purchases and transfers out must not affect rank.
//
// All author-bearing SQL queries follow the same convention:
//
//	LEFT JOIN wallets w ON w.user_id = u.id AND w.currency = 'GOLD_SEAL'
//	... COALESCE(w.total_received_amount, 0) AS author_received_centinels
//
// then call this helper after Scan. Computing on read means the rank
// tier never goes stale when thresholds change.
func fillAuthorRank(author *AuthorInfo, receivedCentinels int64) {
	seals := int(receivedCentinels / 100)
	author.ReputationScore = seals
	author.Rank = ranks.GetRankTierString(seals)
}
