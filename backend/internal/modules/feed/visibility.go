package feed

import "github.com/google/uuid"

func applyHiddenLikesForViewer(resp *PostResponse, viewerID uuid.UUID) {
	resp.IsOwnPost = resp.Author.ID == viewerID
	if resp.HideLikesCount && !resp.IsOwnPost {
		resp.Metrics.Likes = 0
	}
}
