package chat

import "github.com/brightbund-backend/internal/modules/ranks"

// fillOtherRankTier derives OtherRankTier from the per-conversation
// OtherReputationScore. The reputation score itself comes from the SQL
// JOIN on the partner's wallets row (lifetime received Gold Seals).
// Computing the tier in Go means clients don't need a follow-up
// /me/rank request per conversation, and the tier never goes stale
// when rank thresholds change.
func fillOtherRankTier(c *Conversation) {
	if c == nil || c.OtherReputationScore == nil {
		return
	}
	tier := ranks.GetRankTierString(*c.OtherReputationScore)
	c.OtherRankTier = &tier
}
