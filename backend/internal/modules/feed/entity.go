package feed

import (
	"time"

	"github.com/google/uuid"
)

// Constants for Enums
const (
	VisibilityAnyone     = "ANYONE"
	VisibilityAlliesOnly = "ALLIES_ONLY"

	CommentPermAnyone     = "ANYONE"
	CommentPermAlliesOnly = "ALLIES_ONLY"
	CommentPermNoOne      = "NO_ONE"
)

const (
	ReportTargetPost    = "post"
	ReportTargetComment = "comment"

	ReportStatusPending  = "pending"
	ReportStatusReviewed = "reviewed"

	ReportDecisionAccepted = "accepted"
	ReportDecisionRejected = "rejected"
	ReportDecisionActioned = "actioned"

	ReportReasonSpam         = "spam"
	ReportReasonHate         = "hate"
	ReportReasonNudity       = "nudity"
	ReportReasonViolence     = "violence"
	ReportReasonIllegal      = "illegal"
	ReportReasonGambling     = "gambling"
	ReportReasonCopyright    = "copyright"
	ReportReasonFakeAccount  = "fake_account"
	ReportReasonManipulation = "manipulation"
)

type FeedFatigueState struct {
	UserID                   uuid.UUID `json:"user_id" db:"user_id"`
	AccumulatedActiveSeconds int       `json:"accumulated_active_seconds" db:"accumulated_active_seconds"`
	// AccumulatedBreakSeconds tracks how many seconds the user has spent OFF the feed
	// during the current break phase. Break resolves only when this reaches BreakDurationSeconds.
	AccumulatedBreakSeconds int        `json:"accumulated_break_seconds" db:"accumulated_break_seconds"`
	LastSyncTimestamp       time.Time  `json:"last_sync_timestamp" db:"last_sync_timestamp"`
	IsInCooldown            bool       `json:"is_in_cooldown" db:"is_in_cooldown"`
	BreakStartedAt          *time.Time `json:"break_start_at,omitempty" db:"break_start_at"` // informational reference timestamp
	MaxAllowedSeconds       int        `json:"max_allowed_seconds"`                          // Cached locally to avoid profile DB hits
}

type MediaAttachment struct {
	Type         string `json:"type"` // "image" or "video"
	URL          string `json:"url"`
	ThumbnailURL string `json:"thumbnail_url,omitempty"`
	// DurationSeconds is required for video attachments. Feed rejects videos longer than MaxVideoDurationSeconds.
	DurationSeconds int `json:"duration_seconds,omitempty"`
}

// MaxVideoDurationSeconds caps feed video length at 2 minutes (basic phase-2 enforcement).
const MaxVideoDurationSeconds = 120

type Post struct {
	ID                uuid.UUID `json:"id" db:"id"`
	UserID            uuid.UUID `json:"user_id" db:"user_id"`
	Caption           string    `json:"caption" db:"caption"`
	LocationCity      *string   `json:"location_city,omitempty" db:"location_city"`
	LocationCountry   *string   `json:"location_country,omitempty" db:"location_country"`
	LocationLat       *float64  `json:"location_lat,omitempty" db:"location_lat"`
	LocationLon       *float64  `json:"location_lon,omitempty" db:"location_lon"`
	Visibility        string    `json:"visibility" db:"visibility"`
	CommentPermission string    `json:"comment_permission" db:"comment_permission"`
	HideLikesCount    bool      `json:"hide_likes_count" db:"hide_likes_count"`
	IsPublic          bool      `json:"is_public" db:"is_public"` // Legacy flag
	IsArchived        bool      `json:"is_archived" db:"is_archived"`
	IsDeleted         bool      `json:"is_deleted" db:"is_deleted"`
	LikesCount        int       `json:"likes_count" db:"likes_count"`
	CommentsCount     int       `json:"comments_count" db:"comments_count"`
	SharesCount       int       `json:"shares_count" db:"share_count"`
	SealsCount        int       `json:"seals_count" db:"seals_count"`
	SealsAmount       int64     `json:"seals_amount" db:"seals_amount"`
	CreatedAt         time.Time `json:"created_at" db:"created_at"`
	UpdatedAt         time.Time `json:"updated_at" db:"updated_at"`
}

type PostComment struct {
	ID               uuid.UUID         `json:"id" db:"id"`
	PostID           uuid.UUID         `json:"post_id" db:"post_id"`
	UserID           uuid.UUID         `json:"user_id" db:"user_id"`
	ParentCommentID  *uuid.UUID        `json:"parent_comment_id,omitempty" db:"parent_comment_id"`
	RootCommentID    *uuid.UUID        `json:"root_comment_id,omitempty" db:"root_comment_id"`
	Content          string            `json:"content" db:"content"`
	MediaAttachments []MediaAttachment `json:"media_attachments,omitempty" db:"media_attachments"`
	LikesCount       int               `json:"likes_count" db:"likes_count"`
	IsDeleted        bool              `json:"is_deleted" db:"is_deleted"`
	CreatedAt        time.Time         `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time         `json:"updated_at" db:"updated_at"`
}

// ---- API Request/Response Types ----

type CreatePostRequest struct {
	Caption           string            `json:"caption"`
	MediaAttachments  []MediaAttachment `json:"media_attachments"`
	Visibility        string            `json:"visibility"`
	CommentPermission string            `json:"comment_permission"`
	HideLikesCount    bool              `json:"hide_likes_count"`
	LocationCity      *string           `json:"location_city,omitempty"`
	LocationCountry   *string           `json:"location_country,omitempty"`
	LocationLat       *float64          `json:"location_lat,omitempty"`
	LocationLon       *float64          `json:"location_lon,omitempty"`
}

type UpdatePostRequest struct {
	CommentPermission *string `json:"comment_permission,omitempty"`
	HideLikesCount    *bool   `json:"hide_likes_count,omitempty"`
}

type CreateCommentRequest struct {
	ParentID         *uuid.UUID        `json:"parent_id,omitempty"`
	ContentText      string            `json:"content_text"`
	MediaAttachments []MediaAttachment `json:"media_attachments,omitempty"`
}

type ReportCommentRequest struct {
	Reason      string `json:"reason"`
	Description string `json:"description,omitempty"`
}

type ReportPostRequest struct {
	Reason      string `json:"reason"`
	Description string `json:"description,omitempty"`
}

type ReviewReportsRequest struct {
	TargetType string `json:"target_type"`
	TargetID   string `json:"target_id"`
	Decision   string `json:"decision"`
}

type SyncFeedStateRequest struct {
	DeltaSeconds int    `json:"delta_seconds"`
	DeviceID     string `json:"device_id"`
	// Context: either is_feed_active or app_section must be provided.
	IsFeedActive *bool  `json:"is_feed_active,omitempty"`
	AppSection   string `json:"app_section,omitempty"`
}

type FeedStateResponse struct {
	AccumulatedActiveSeconds int  `json:"accumulated_active_seconds"`
	IsInCooldown             bool `json:"is_in_cooldown"`
	BreakSecondsRemaining    int  `json:"break_seconds_remaining"` // 0-300; 0 = not in break
	BreakMode                string `json:"break_mode"`            // "paused" | "counting"
	// AccumulatedBreakSeconds exposes how many off-feed seconds have been served so far.
	// Client can use this to animate the break countdown even between sync calls.
	AccumulatedBreakSeconds int       `json:"accumulated_break_seconds"`
	MaxAllowedSeconds       int       `json:"max_allowed_seconds"`
	ServerTimestamp         time.Time `json:"server_timestamp"`
	ActionRequired          string    `json:"action_required,omitempty"` // "trigger_friction", "enforce_cooldown", or omitted
}

const (
	AppSectionFeed       = "feed"
	AppSectionMap        = "map"
	AppSectionProfile    = "profile"
	AppSectionChats      = "chats"
	AppSectionBackground = "background"
)

type AuthorInfo struct {
	ID            uuid.UUID `json:"id"`
	Username      string    `json:"username"`
	FullName      string    `json:"full_name"`
	ProfilePicURL string    `json:"profile_pic_url"`
	Rank          string    `json:"rank"`
	// RankSubLevel is the sub-level label within the rank tier (e.g. "Intention")
	RankSubLevel string `json:"rank_sub_level,omitempty"`
}

type PostMetrics struct {
	Likes    int   `json:"likes"`
	Comments int   `json:"comments"`
	Shares   int   `json:"shares"`
	Silvers  int64 `json:"silvers"`
}

type Permissions struct {
	CanComment bool `json:"can_comment"`
}

type PostResponse struct {
	PostID  uuid.UUID  `json:"post_id"`
	Author  AuthorInfo `json:"author"`
	TimeAgo string     `json:"time_ago"`
	// Visibility is returned so the client can show the globe 🌐 or allies 👥 icon
	Visibility        string            `json:"visibility"`
	CommentPermission string            `json:"comment_permission"`
	ContentText       string            `json:"content_text"`
	MediaAttachments  []MediaAttachment `json:"media_attachments"`
	Metrics           PostMetrics       `json:"metrics"`
	Permissions       Permissions       `json:"permissions"`
	// IsOwnPost lets the client show/hide the ··· edit/delete options menu
	IsOwnPost bool `json:"is_own_post"`
	// ViewerHasLiked lets the client render the ❤️ heart as filled immediately
	ViewerHasLiked bool `json:"viewer_has_liked"`
	HideLikesCount bool `json:"hide_likes_count"`
}

type FeedResponse struct {
	Items        []PostResponse `json:"items"`
	NextCursor   string         `json:"next_cursor,omitempty"`
	FeedDegraded bool           `json:"feed_degraded"`
}

// PostGridItem is a lightweight thumbnail entry for the 3×3 profile grid.
type PostGridItem struct {
	PostID           uuid.UUID `json:"post_id"`
	ThumbnailURL     string    `json:"thumbnail_url,omitempty"`
	MediaType        string    `json:"media_type,omitempty"` // "image" | "video" | ""
	HasMultipleMedia bool      `json:"has_multiple_media"`
	CreatedAt        time.Time `json:"created_at"`
}

// UserPostsGridResponse is the paginated response for the profile posts grid.
type UserPostsGridResponse struct {
	Items      []PostGridItem `json:"items"`
	NextCursor string         `json:"next_cursor,omitempty"`
}

type CommentResponse struct {
	CommentID        uuid.UUID         `json:"comment_id"`
	ParentCommentID  *uuid.UUID        `json:"parent_comment_id"`
	RootCommentID    *uuid.UUID        `json:"root_comment_id"`
	Author           AuthorInfo        `json:"author"`
	TimeAgo          string            `json:"time_ago"`
	CreatedAt        time.Time         `json:"created_at"`
	ContentText      string            `json:"content_text"`
	MediaAttachments []MediaAttachment `json:"media_attachments,omitempty"`
	ReplyCount       int               `json:"reply_count"` // Number of direct child replies
	LikesCount       int               `json:"likes_count"`
	ViewerHasLiked   bool              `json:"viewer_has_liked"`
}

type CommentThreadParent struct {
	CommentID     uuid.UUID
	PostID        uuid.UUID
	ParentID      *uuid.UUID
	RootCommentID *uuid.UUID
}

type ThreadedCommentsResponse struct {
	Comments   []CommentResponse `json:"comments"`
	NextCursor string            `json:"next_cursor,omitempty"`
}

type InteractionResponse struct {
	User      AuthorInfo `json:"user"`
	CreatedAt time.Time  `json:"created_at"`
}

type InteractionListResponse struct {
	Items      []InteractionResponse `json:"items"`
	NextCursor string                `json:"next_cursor,omitempty"`
}

type ReportItem struct {
	ID               uuid.UUID `json:"id"`
	ReporterID       uuid.UUID `json:"reporter_id"`
	TargetType       string    `json:"target_type"`
	TargetID         uuid.UUID `json:"target_id"`
	Reason           string    `json:"reason"`
	ModerationStatus string    `json:"moderation_status"`
	CreatedAt        time.Time `json:"created_at"`
}

type ReportsListResponse struct {
	Items  []ReportItem `json:"items"`
	Total  int          `json:"total"`
	Limit  int          `json:"limit"`
	Offset int          `json:"offset"`
}

type SendSealRequest struct {
	Amount         int64  `json:"amount"`
	Comment        string `json:"comment,omitempty"`
	IdempotencyKey string `json:"idempotency_key,omitempty"`
}

type SealResponse struct {
	User      AuthorInfo `json:"user"`
	Amount    int64      `json:"amount"`
	Comment   string     `json:"comment,omitempty"`
	CreatedAt time.Time  `json:"created_at"`
}

type SealListResponse struct {
	Items      []SealResponse `json:"items"`
	NextCursor string         `json:"next_cursor,omitempty"`
}
