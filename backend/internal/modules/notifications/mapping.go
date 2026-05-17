package notifications

import "fmt"

type TopicMapping struct {
	UITab       UITab
	IsImportant bool
	BadgeStatus *string
	DeepLinkFn  func(payload map[string]any) string
	GroupKeyFn  func(payload map[string]any) *string // nil = не группировать
}

func strPtr(s string) *string { return &s }

func strVal(m map[string]any, key string) string {
	if v, ok := m[key].(string); ok {
		return v
	}
	return ""
}

// TopicMappings resolves every Kafka topic to its UI metadata.
// If a topic is missing, the handler falls back to UITabSystem.
var TopicMappings = map[string]TopicMapping{
	// RECOGNITION
	"economy.silver_received": {
		UITab:       UITabRecognition,
		IsImportant: false,
		BadgeStatus: nil,
		DeepLinkFn:  func(p map[string]any) string { return "app://post/" + strVal(p, "post_id") },
		GroupKeyFn:  nil,
	},
	"economy.seal_received": {
		UITab:       UITabRecognition,
		IsImportant: false,
		BadgeStatus: nil,
		DeepLinkFn:  func(p map[string]any) string { return "app://post/" + strVal(p, "post_id") },
		GroupKeyFn:  nil,
	},
	"achievement.medal_issued": {
		UITab:       UITabRecognition,
		IsImportant: true,
		BadgeStatus: strPtr("MEDAL_UNLOCKED"),
		DeepLinkFn:  func(p map[string]any) string { return "app://profile/medals" },
		GroupKeyFn:  nil,
	},

	// RANK
	"leaderboard.rank_advanced": {
		UITab:       UITabRank,
		IsImportant: false,
		BadgeStatus: strPtr("MEDAL_UNLOCKED"),
		DeepLinkFn:  func(p map[string]any) string { return "app://leaderboard/" + strVal(p, "season_id") },
		GroupKeyFn:  nil,
	},
	"leaderboard.district_leader": {
		UITab:       UITabRank,
		IsImportant: true,
		BadgeStatus: strPtr("AREA_LEADER"),
		DeepLinkFn:  func(p map[string]any) string { return "app://leaderboard/" + strVal(p, "season_id") },
		GroupKeyFn:  nil,
	},
	"leaderboard.top_50": {
		UITab:       UITabRank,
		IsImportant: true,
		BadgeStatus: nil,
		DeepLinkFn:  func(p map[string]any) string { return "app://leaderboard/" + strVal(p, "season_id") },
		GroupKeyFn:  nil,
	},
	"leaderboard.season_warning": {
		UITab:       UITabRank,
		IsImportant: false,
		BadgeStatus: nil,
		DeepLinkFn:  func(p map[string]any) string { return "app://leaderboard/" + strVal(p, "season_id") },
		GroupKeyFn:  nil,
	},
	"leaderboard.season_result": {
		UITab:       UITabRank,
		IsImportant: false,
		BadgeStatus: nil,
		DeepLinkFn:  func(p map[string]any) string { return "app://leaderboard/" + strVal(p, "season_id") },
		GroupKeyFn:  nil,
	},

	// TASKS
	"task.accepted": {
		UITab:       UITabTasks,
		IsImportant: false,
		BadgeStatus: strPtr("ACCEPTED"),
		DeepLinkFn:  func(p map[string]any) string { return "app://tasks/" + strVal(p, "task_id") },
		GroupKeyFn:  nil,
	},
	"task.proof_submitted": {
		UITab:       UITabTasks,
		IsImportant: false,
		BadgeStatus: strPtr("UNDER_REVIEW"),
		DeepLinkFn:  func(p map[string]any) string { return "app://tasks/" + strVal(p, "task_id") },
		GroupKeyFn:  nil,
	},
	"task.verification_required": {
		UITab:       UITabTasks,
		IsImportant: false,
		BadgeStatus: nil,
		DeepLinkFn:  func(p map[string]any) string { return "app://tasks/" + strVal(p, "task_id") },
		GroupKeyFn:  nil,
	},
	"task.reward_delivered": {
		UITab:       UITabTasks,
		IsImportant: false,
		BadgeStatus: strPtr("ACCEPTED"),
		DeepLinkFn:  func(p map[string]any) string { return "app://tasks/" + strVal(p, "task_id") },
		GroupKeyFn:  nil,
	},
	"task.completed": {
		UITab:       UITabTasks,
		IsImportant: false,
		BadgeStatus: strPtr("ACCEPTED"),
		DeepLinkFn:  func(p map[string]any) string { return "app://tasks/" + strVal(p, "task_id") },
		GroupKeyFn:  nil,
	},
	"task.expired": {
		UITab:       UITabTasks,
		IsImportant: false,
		BadgeStatus: strPtr("EXPIRED"),
		DeepLinkFn:  func(p map[string]any) string { return "app://tasks/" + strVal(p, "task_id") },
		GroupKeyFn:  nil,
	},

	// SYSTEM
	"moderation.post_rejected": {
		UITab:       UITabSystem,
		IsImportant: false,
		BadgeStatus: strPtr("REJECTED"),
		DeepLinkFn:  func(p map[string]any) string { return "app://post/" + strVal(p, "post_id") + "/moderation" },
		GroupKeyFn:  nil,
	},
	"system.security_signin": {
		UITab:       UITabSystem,
		IsImportant: true,
		BadgeStatus: strPtr("ALERT"),
		DeepLinkFn:  func(p map[string]any) string { return "app://settings/security" },
		GroupKeyFn:  nil,
	},
	"system.payment_confirmed": {
		UITab:       UITabSystem,
		IsImportant: false,
		BadgeStatus: strPtr("COMPLETED"),
		DeepLinkFn:  func(p map[string]any) string { return "app://wallet/transactions" },
		GroupKeyFn:  nil,
	},
	"system.profile_verified": {
		UITab:       UITabSystem,
		IsImportant: false,
		BadgeStatus: strPtr("VERIFIED"),
		DeepLinkFn:  func(p map[string]any) string { return "app://profile/verification" },
		GroupKeyFn:  nil,
	},

	// ACTIVITY
	"social.post_replied": {
		UITab:       UITabActivity,
		IsImportant: false,
		BadgeStatus: nil,
		DeepLinkFn:  func(p map[string]any) string { return "app://post/" + strVal(p, "post_id") },
		GroupKeyFn:  nil,
	},
	"social.post_commented": {
		UITab:       UITabActivity,
		IsImportant: false,
		BadgeStatus: nil,
		DeepLinkFn:  func(p map[string]any) string { return "app://post/" + strVal(p, "post_id") },
		GroupKeyFn:  nil,
	},
	"social.post_liked": {
		UITab:       UITabActivity,
		IsImportant: false,
		BadgeStatus: nil,
		DeepLinkFn:  func(p map[string]any) string { return "app://post/" + strVal(p, "post_id") },
		GroupKeyFn: func(p map[string]any) *string {
			postID := strVal(p, "post_id")
			if postID == "" {
				return nil
			}
			key := fmt.Sprintf("post_liked:%s", postID)
			return &key
		},
	},
}

// applyMapping fills UITab, IsImportant, BadgeStatus, DeepLink, GroupKey
// on an Enqueue from the topic map. Falls back to UITabSystem if unknown.
func applyMapping(topic string, enq *Enqueue, payload map[string]any) {
	m, ok := TopicMappings[topic]
	if !ok {
		enq.UITab = UITabSystem
		return
	}
	enq.UITab = m.UITab
	enq.IsImportant = m.IsImportant
	enq.BadgeStatus = m.BadgeStatus
	if m.DeepLinkFn != nil {
		enq.DeepLink = m.DeepLinkFn(payload)
	}
	if m.GroupKeyFn != nil {
		enq.GroupKey = m.GroupKeyFn(payload)
	}
}
