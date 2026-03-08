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
	GetSmartFeed(ctx context.Context, viewerID uuid.UUID, lat, lon float64, cursor time.Time, limit int) ([]PostResponse, string, error)

	// Profile Posts Grid / List
	GetUserPostsGrid(ctx context.Context, authorID, viewerID uuid.UUID, cursor time.Time, limit int) ([]PostGridItem, string, error)
	GetUserPostsList(ctx context.Context, authorID, viewerID uuid.UUID, cursor time.Time, limit int) ([]PostResponse, string, error)
	GetPostCreatedAt(ctx context.Context, postID uuid.UUID) (time.Time, error)

	// Comments
	CreateComment(ctx context.Context, comment *PostComment) error
	GetThreadedComments(ctx context.Context, postID uuid.UUID, viewerID uuid.UUID, parentID *uuid.UUID, cursor string, limit int) ([]CommentResponse, string, error)
	GetPostPermissionsInfo(ctx context.Context, postID uuid.UUID) (string, uuid.UUID, error) // Returns (CommentPermission, AuthorID)

	// Interactions
	GetInteractions(ctx context.Context, postID uuid.UUID, interactionType string, cursor string, limit int) ([]InteractionResponse, string, error)
	GetSeals(ctx context.Context, postID uuid.UUID, cursor string, limit int) ([]SealResponse, string, error)
	BatchFlushLikes(ctx context.Context, postID uuid.UUID, userIDs []uuid.UUID) error
	BatchFlushSeals(ctx context.Context, postID uuid.UUID, count int, totalAmount int64) error
}

// CacheRepository interface for Redis high-frequency syncs (Write-behind).
type CacheRepository interface {
	GetFatigueState(ctx context.Context, userID uuid.UUID) (*FeedFatigueState, error)
	SetFatigueState(ctx context.Context, state *FeedFatigueState) error
	MarkUserDirty(ctx context.Context, userID uuid.UUID) error
}
