package feed

import (
	"testing"

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
