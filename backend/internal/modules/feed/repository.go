package feed

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// Repository interface for PostgreSQL persistence operations.
type Repository interface {
	// Anti-Doomscroll State
	GetFatigueState(ctx context.Context, userID uuid.UUID) (*FeedFatigueState, error)
	UpsertFatigueState(ctx context.Context, state *FeedFatigueState) error

	// Posts
	CreatePost(ctx context.Context, post *Post, media []MediaAttachment) error
	UpdatePost(ctx context.Context, postID, userID uuid.UUID, req *UpdatePostRequest) error
	DeletePost(ctx context.Context, postID, userID uuid.UUID) error
	GetSmartFeed(ctx context.Context, viewerID uuid.UUID, lat, lon float64, hasLocation bool, cursor time.Time, limit int) ([]PostResponse, string, error)
	GetPost(ctx context.Context, postID uuid.UUID, viewerID uuid.UUID) (*PostResponse, error)

	// Profile Posts Grid / List
	GetUserPostsGrid(ctx context.Context, authorID, viewerID uuid.UUID, cursor time.Time, limit int) ([]PostGridItem, string, error)
	GetUserPostsList(ctx context.Context, authorID, viewerID uuid.UUID, cursor time.Time, limit int) ([]PostResponse, string, error)
	GetPostCreatedAt(ctx context.Context, postID uuid.UUID) (time.Time, error)

	// Comments
	CreateComment(ctx context.Context, comment *PostComment) error
	GetComment(ctx context.Context, commentID uuid.UUID, viewerID uuid.UUID) (*CommentResponse, error)
	GetCommentThreadParent(ctx context.Context, commentID uuid.UUID) (*CommentThreadParent, error)
	GetThreadedComments(ctx context.Context, postID uuid.UUID, viewerID uuid.UUID, parentID *uuid.UUID, cursor string, limit int) ([]CommentResponse, string, error)
	GetPostPermissionsInfo(ctx context.Context, postID uuid.UUID) (string, uuid.UUID, error) // Returns (CommentPermission, AuthorID)
	ToggleCommentLike(ctx context.Context, commentID uuid.UUID, userID uuid.UUID) error
	DeleteComment(ctx context.Context, commentID, actorID uuid.UUID, isModerator bool) error
	CreateReport(ctx context.Context, reporterID uuid.UUID, targetType string, targetID uuid.UUID, reason, description string) error
	HidePostForReporter(ctx context.Context, reporterID, postID uuid.UUID) error
	CountRecentReportsByUser(ctx context.Context, reporterID uuid.UUID, since time.Time) (int, error)
	CountReportsForTarget(ctx context.Context, targetType string, targetID uuid.UUID) (int, error)
	GetWeightedReportsForPost(ctx context.Context, postID uuid.UUID) (float64, error)
	GetPostImpressions(ctx context.Context, postID uuid.UUID) (int, error)
	SetPostReportControl(ctx context.Context, postID uuid.UUID, level int, distributionMultiplier float64) error
	IncrementPostImpressions(ctx context.Context, postIDs []uuid.UUID) error
	MarkReportsReviewed(ctx context.Context, targetType string, targetID uuid.UUID, decision string) ([]uuid.UUID, error)
	ApplyReporterReputationDelta(ctx context.Context, reporterIDs []uuid.UUID, accepted bool) error
	MarkReportReputationApplied(ctx context.Context, targetType string, targetID uuid.UUID) error
	CreateAuthorPolicyStrikeForTarget(ctx context.Context, targetType string, targetID uuid.UUID, expiresAt time.Time) error
	HideTargetByReports(ctx context.Context, targetType string, targetID uuid.UUID) error
	ListReports(ctx context.Context, status, targetType, reason string, limit, offset int) ([]ReportItem, int, error)
	IsAlly(ctx context.Context, userID, targetUserID uuid.UUID) (bool, error)
	IsUserAdmin(ctx context.Context, userID uuid.UUID) (bool, error)

	// Interactions
	GetInteractions(ctx context.Context, postID uuid.UUID, interactionType string, cursor string, limit int) ([]InteractionResponse, string, error)
	GetSeals(ctx context.Context, postID uuid.UUID, cursor string, limit int) ([]SealResponse, string, error)
	ToggleLike(ctx context.Context, postID uuid.UUID, userID uuid.UUID) error
	BatchFlushLikes(ctx context.Context, postID uuid.UUID, userIDs []uuid.UUID) error
	BatchFlushSeals(ctx context.Context, postID uuid.UUID, count int, totalAmount int64) error
}

// CacheRepository interface for Redis high-frequency syncs (Write-behind).
type CacheRepository interface {
	GetFatigueState(ctx context.Context, userID uuid.UUID) (*FeedFatigueState, error)
	SetFatigueState(ctx context.Context, state *FeedFatigueState) error
	MarkUserDirty(ctx context.Context, userID uuid.UUID) error
	MarkDeviceOnFeed(ctx context.Context, userID uuid.UUID, deviceID string, ttl time.Duration) error
	AnyDeviceOnFeed(ctx context.Context, userID uuid.UUID) (bool, error)
}
