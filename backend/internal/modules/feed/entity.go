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
}

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
	IsPublic          bool      `json:"is_public" db:"is_public"` // Legacy flag
	IsArchived        bool      `json:"is_archived" db:"is_archived"`
	LikesCount        int       `json:"likes_count" db:"likes_count"`
	CommentsCount     int       `json:"comments_count" db:"comments_count"`
	SharesCount       int       `json:"shares_count" db:"share_count"`
	SealsCount        int       `json:"seals_count" db:"seals_count"`
	SealsAmount       int64     `json:"seals_amount" db:"seals_amount"`
	CreatedAt         time.Time `json:"created_at" db:"created_at"`
	UpdatedAt         time.Time `json:"updated_at" db:"updated_at"`
}

type PostComment struct {
	ID              uuid.UUID        `json:"id" db:"id"`
	PostID          uuid.UUID        `json:"post_id" db:"post_id"`
	UserID          uuid.UUID        `json:"user_id" db:"user_id"`
	ParentCommentID *uuid.UUID       `json:"parent_comment_id,omitempty" db:"parent_comment_id"`
	RootCommentID   *uuid.UUID       `json:"root_comment_id,omitempty" db:"root_comment_id"`
	Content         string           `json:"content" db:"content"`
	MediaAttachment *MediaAttachment `json:"media_attachment,omitempty" db:"media_attachment"`
	LikesCount      int              `json:"likes_count" db:"likes_count"`
	IsDeleted       bool             `json:"is_deleted" db:"is_deleted"`
	CreatedAt       time.Time        `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time        `json:"updated_at" db:"updated_at"`
}

// ---- API Request/Response Types ----

type CreatePostRequest struct {
	Caption           string            `json:"caption"`
	MediaAttachments  []MediaAttachment `json:"media_attachments"`
	Visibility        string            `json:"visibility"`
	CommentPermission string            `json:"comment_permission"`
}

type CreateCommentRequest struct {
	ParentID        *uuid.UUID       `json:"parent_id,omitempty"`
	ContentText     string           `json:"content_text"`
	MediaAttachment *MediaAttachment `json:"media_attachment,omitempty"`
}

type SyncFeedStateRequest struct {
	DeltaSeconds int `json:"delta_seconds"`
}

type FeedStateResponse struct {
	AccumulatedActiveSeconds int  `json:"accumulated_active_seconds"`
	IsInCooldown             bool `json:"is_in_cooldown"`
	BreakSecondsRemaining    int  `json:"break_seconds_remaining"` // 0-300; 0 = not in break
	// AccumulatedBreakSeconds exposes how many off-feed seconds have been served so far.
	// Client can use this to animate the break countdown even between sync calls.
	AccumulatedBreakSeconds int       `json:"accumulated_break_seconds"`
	MaxAllowedSeconds       int       `json:"max_allowed_seconds"`
	ServerTimestamp         time.Time `json:"server_timestamp"`
	ActionRequired          string    `json:"action_required,omitempty"` // "trigger_friction" or omitted
}

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
	Visibility       string            `json:"visibility"`
	ContentText      string            `json:"content_text"`
	MediaAttachments []MediaAttachment `json:"media_attachments"`
	Metrics          PostMetrics       `json:"metrics"`
	Permissions      Permissions       `json:"permissions"`
	// IsOwnPost lets the client show/hide the ··· edit/delete options menu
	IsOwnPost bool `json:"is_own_post"`
	// ViewerHasLiked lets the client render the ❤️ heart as filled immediately
	ViewerHasLiked bool `json:"viewer_has_liked"`
}

type FeedResponse struct {
	Items      []PostResponse `json:"items"`
	NextCursor string         `json:"next_cursor,omitempty"`
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
	CommentID       uuid.UUID        `json:"comment_id"`
	ParentCommentID *uuid.UUID       `json:"parent_comment_id"`
	RootCommentID   *uuid.UUID       `json:"root_comment_id"`
	Author          AuthorInfo       `json:"author"`
	TimeAgo         string           `json:"time_ago"`
	CreatedAt       time.Time        `json:"created_at"`
	ContentText     string           `json:"content_text"`
	MediaAttachment *MediaAttachment `json:"media_attachment,omitempty"`
	ReplyCount      int              `json:"reply_count"` // Only > 0 for root comments
	LikesCount      int              `json:"likes_count"`
	ViewerHasLiked  bool             `json:"viewer_has_liked"`
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

type SendSealRequest struct {
	Amount  int64  `json:"amount"`
	Comment string `json:"comment,omitempty"`
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
