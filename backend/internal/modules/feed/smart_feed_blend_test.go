package feed

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func makePost(authorID uuid.UUID) PostResponse {
	return PostResponse{
		PostID: uuid.New(),
		Author: AuthorInfo{ID: authorID},
	}
}

func TestBlendSmartFeedCandidates_ZeroLimitReturnsEmpty(t *testing.T) {
	items := blendSmartFeedCandidates(nil, nil, 0)
	if len(items) != 0 {
		t.Fatalf("expected 0 items, got %d", len(items))
	}
}

func TestBlendSmartFeedCandidates_PrefersAuthorDiversityWhenPossible(t *testing.T) {
	authorA := uuid.New()
	authorB := uuid.New()

	allies := []PostResponse{
		makePost(authorA),
		makePost(authorA),
		makePost(authorA),
		makePost(authorA),
		makePost(authorB),
		makePost(authorB),
	}

	items := blendSmartFeedCandidates(allies, nil, 4)
	if len(items) != 4 {
		t.Fatalf("expected 4 items, got %d", len(items))
	}

	countA := 0
	for _, item := range items {
		if item.Author.ID == authorA {
			countA++
		}
	}

	if countA > 2 {
		t.Fatalf("expected at most 2 posts from author A in diversity phase, got %d", countA)
	}
}

func TestBlendSmartFeedCandidates_BackfillsDeferredWhenPoolIsSmall(t *testing.T) {
	authorA := uuid.New()
	allies := []PostResponse{
		makePost(authorA),
		makePost(authorA),
		makePost(authorA),
		makePost(authorA),
	}

	items := blendSmartFeedCandidates(allies, nil, 4)
	if len(items) != 4 {
		t.Fatalf("expected 4 items, got %d", len(items))
	}
}

func TestBlendSmartFeedCandidates_KeepsWorldQuotaWhenAvailable(t *testing.T) {
	authorA := uuid.New()
	authorB := uuid.New()
	authorWorld := uuid.New()

	allies := []PostResponse{
		makePost(authorA),
		makePost(authorB),
		makePost(authorA),
		makePost(authorB),
	}
	world := []PostResponse{
		makePost(authorWorld),
	}

	items := blendSmartFeedCandidates(allies, world, 5)
	if len(items) != 5 {
		t.Fatalf("expected 5 items, got %d", len(items))
	}

	foundWorld := false
	for _, item := range items {
		if item.Author.ID == authorWorld {
			foundWorld = true
			break
		}
	}
	if !foundWorld {
		t.Fatal("expected at least one world item in mixed feed")
	}
}

func TestSelectLocalKRing(t *testing.T) {
	stats := map[int]localActivityStats{
		1: {posts: 10, authors: 6},
		2: {posts: 22, authors: 10},
		3: {posts: 33, authors: 17},
	}

	if got := selectLocalKRing(stats); got != 3 {
		t.Fatalf("expected kRing=3, got %d", got)
	}

	stats[2] = localActivityStats{posts: 31, authors: 16}
	if got := selectLocalKRing(stats); got != 2 {
		t.Fatalf("expected earliest sufficient kRing=2, got %d", got)
	}
}

func TestLocalShareForActivity(t *testing.T) {
	if got := localShareForActivity(localActivityStats{posts: 9, authors: 4}); got != feedLocalShareLow {
		t.Fatalf("expected low share %v, got %v", feedLocalShareLow, got)
	}
	if got := localShareForActivity(localActivityStats{posts: 16, authors: 8}); got != feedLocalShareMedium {
		t.Fatalf("expected medium share %v, got %v", feedLocalShareMedium, got)
	}
	if got := localShareForActivity(localActivityStats{posts: 35, authors: 18}); got != feedLocalShareHigh {
		t.Fatalf("expected high share %v, got %v", feedLocalShareHigh, got)
	}
}

func TestBuildRingSetsAndCountLocalActivityByRing(t *testing.T) {
	centerLat := 37.7749
	centerLon := -122.4194
	now := time.Now()

	ringRadii := ringRadiusKmMap()
	if ringRadii[1] <= 0 || ringRadii[2] <= ringRadii[1] || ringRadii[3] <= ringRadii[2] {
		t.Fatal("expected ring radii to be positive and increasing")
	}

	centerCell := makePost(uuid.New())
	centerCellCandidate := smartFeedCandidate{
		post:      centerCell,
		createdAt: now,
		hasPoint:  true,
		lat:       centerLat,
		lon:       centerLon,
	}

	farCandidate := smartFeedCandidate{
		post:      makePost(uuid.New()),
		createdAt: now,
		hasPoint:  true,
		lat:       40.7128,
		lon:       -74.0060,
	}

	oldCandidate := smartFeedCandidate{
		post:      makePost(uuid.New()),
		createdAt: now.Add(-25 * time.Hour),
		hasPoint:  true,
		lat:       centerLat,
		lon:       centerLon,
	}

	stats := countLocalActivityByRing([]smartFeedCandidate{centerCellCandidate, farCandidate, oldCandidate}, centerLat, centerLon, ringRadii, now)
	if stats[1].posts != 1 {
		t.Fatalf("expected 1 local post in ring 1, got %d", stats[1].posts)
	}
	if stats[1].authors != 1 {
		t.Fatalf("expected 1 local author in ring 1, got %d", stats[1].authors)
	}
}
