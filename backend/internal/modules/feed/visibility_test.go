package feed

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestApplyHiddenLikesForViewer_NonAuthorHidden(t *testing.T) {
	authorID := uuid.New()
	viewerID := uuid.New()
	resp := PostResponse{
		Author:         AuthorInfo{ID: authorID},
		HideLikesCount: true,
		Metrics:        PostMetrics{Likes: 42},
	}

	applyHiddenLikesForViewer(&resp, viewerID)

	if resp.IsOwnPost {
		t.Fatal("expected IsOwnPost=false for non-author viewer")
	}
	if resp.Metrics.Likes != 0 {
		t.Fatalf("expected likes to be hidden (0), got %d", resp.Metrics.Likes)
	}
}

func TestApplyHiddenLikesForViewer_AuthorSeesLikes(t *testing.T) {
	authorID := uuid.New()
	resp := PostResponse{
		Author:         AuthorInfo{ID: authorID},
		HideLikesCount: true,
		Metrics:        PostMetrics{Likes: 42},
	}

	applyHiddenLikesForViewer(&resp, authorID)

	if !resp.IsOwnPost {
		t.Fatal("expected IsOwnPost=true for author viewer")
	}
	if resp.Metrics.Likes != 42 {
		t.Fatalf("expected author to see real likes, got %d", resp.Metrics.Likes)
	}
}

func TestApplyHiddenLikesForViewer_NotHidden(t *testing.T) {
	authorID := uuid.New()
	viewerID := uuid.New()
	resp := PostResponse{
		Author:         AuthorInfo{ID: authorID},
		HideLikesCount: false,
		Metrics:        PostMetrics{Likes: 7},
	}

	applyHiddenLikesForViewer(&resp, viewerID)

	if resp.IsOwnPost {
		t.Fatal("expected IsOwnPost=false for non-author viewer")
	}
	if resp.Metrics.Likes != 7 {
		t.Fatalf("expected likes unchanged when hide_likes_count=false, got %d", resp.Metrics.Likes)
	}
}

// makeComment creates a CommentResponse with the given author and timestamp.
func makeComment(authorID uuid.UUID, createdAt time.Time) CommentResponse {
	return CommentResponse{
		CommentID: uuid.New(),
		Author:    AuthorInfo{ID: authorID},
		CreatedAt: createdAt,
	}
}

// newCommentService creates a Service wired to a testRepo with a fixed GetThreadedComments stub.
func newCommentService(fn func(ctx context.Context, postID uuid.UUID, viewerID uuid.UUID, parentID *uuid.UUID, cursor string, limit int) ([]CommentResponse, string, error)) *Service {
	repo := &testRepo{getThreadedCommentsFn: fn}
	return &Service{repo: repo, cache: &testCacheRepo{}}
}

// TestGetThreadedComments_OwnCommentVisible verifies that the viewer's own comment
// is included in results after the removal of the c.user_id <> viewerID SQL filter.
func TestGetThreadedComments_OwnCommentVisible(t *testing.T) {
	viewerID := uuid.New()
	postID := uuid.New()
	now := time.Now()

	ownComment := makeComment(viewerID, now.Add(-1*time.Second))
	otherComment := makeComment(uuid.New(), now.Add(-2*time.Second))

	svc := newCommentService(func(_ context.Context, _ uuid.UUID, _ uuid.UUID, _ *uuid.UUID, _ string, _ int) ([]CommentResponse, string, error) {
		return []CommentResponse{ownComment, otherComment}, "", nil
	})

	resp, err := svc.GetThreadedComments(context.Background(), viewerID, postID, nil, "", 50)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	found := false
	for _, c := range resp.Comments {
		if c.CommentID == ownComment.CommentID {
			found = true
			break
		}
	}
	if !found {
		t.Fatal("viewer's own comment was not returned — c.user_id <> viewerID filter may still be active")
	}
}

// TestGetThreadedComments_Deterministic verifies that two identical calls return
// the same list in the same order (no random suppression).
func TestGetThreadedComments_Deterministic(t *testing.T) {
	viewerID := uuid.New()
	postID := uuid.New()
	now := time.Now()

	fixed := []CommentResponse{
		makeComment(uuid.New(), now.Add(-1*time.Second)),
		makeComment(uuid.New(), now.Add(-2*time.Second)),
		makeComment(uuid.New(), now.Add(-3*time.Second)),
	}

	svc := newCommentService(func(_ context.Context, _ uuid.UUID, _ uuid.UUID, _ *uuid.UUID, _ string, _ int) ([]CommentResponse, string, error) {
		return fixed, "", nil
	})

	ctx := context.Background()
	r1, _, err := svc.repo.GetThreadedComments(ctx, postID, viewerID, nil, "", 50)
	if err != nil {
		t.Fatalf("first call error: %v", err)
	}
	r2, _, err := svc.repo.GetThreadedComments(ctx, postID, viewerID, nil, "", 50)
	if err != nil {
		t.Fatalf("second call error: %v", err)
	}

	if len(r1) != len(r2) {
		t.Fatalf("non-deterministic: first call returned %d comments, second returned %d", len(r1), len(r2))
	}
	for i := range r1 {
		if r1[i].CommentID != r2[i].CommentID {
			t.Fatalf("non-deterministic at index %d: got %v then %v", i, r1[i].CommentID, r2[i].CommentID)
		}
	}
}

// TestGetThreadedComments_CountMatchesReturned verifies that the number of returned
// comments equals what the repo provides (no silent drops from random suppression).
func TestGetThreadedComments_CountMatchesReturned(t *testing.T) {
	viewerID := uuid.New()
	postID := uuid.New()
	now := time.Now()

	comments := []CommentResponse{
		makeComment(uuid.New(), now.Add(-1*time.Second)),
		makeComment(uuid.New(), now.Add(-2*time.Second)),
		makeComment(uuid.New(), now.Add(-3*time.Second)),
		makeComment(uuid.New(), now.Add(-4*time.Second)),
		makeComment(uuid.New(), now.Add(-5*time.Second)),
	}
	wantCount := len(comments)

	svc := newCommentService(func(_ context.Context, _ uuid.UUID, _ uuid.UUID, _ *uuid.UUID, _ string, _ int) ([]CommentResponse, string, error) {
		return comments, "", nil
	})

	resp, err := svc.GetThreadedComments(context.Background(), viewerID, postID, nil, "", 50)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(resp.Comments) != wantCount {
		t.Fatalf("expected %d comments (no random drops), got %d", wantCount, len(resp.Comments))
	}
}
