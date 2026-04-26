package vision

import (
	"context"
	"fmt"
	"io"

	vision "cloud.google.com/go/vision/apiv1"
	visionpb "google.golang.org/genproto/googleapis/cloud/vision/v1"
)

// Client defines the interface for media safety inspection
type Client interface {
	DetectInappropriateContent(ctx context.Context, reader io.Reader) (bool, string, error)
}

type googleVisionClient struct {
	client *vision.ImageAnnotatorClient
}

// NewClient creates a new Google Vision API client using Application Default Credentials (ADC)
func NewClient(ctx context.Context) (Client, error) {
	c, err := vision.NewImageAnnotatorClient(ctx)
	if err != nil {
		return nil, fmt.Errorf("vision.NewImageAnnotatorClient: %w", err)
	}
	return &googleVisionClient{client: c}, nil
}

// DetectInappropriateContent checks an image for adult, violence, or racy content
func (g *googleVisionClient) DetectInappropriateContent(ctx context.Context, reader io.Reader) (bool, string, error) {
	image, err := vision.NewImageFromReader(reader)
	if err != nil {
		return false, "", fmt.Errorf("vision.NewImageFromReader: %w", err)
	}

	props, err := g.client.DetectSafeSearch(ctx, image, nil)
	if err != nil {
		return false, "", fmt.Errorf("g.client.DetectSafeSearch: %w", err)
	}

	// Threshold: LIKELY or VERY_LIKELY are considered violations
	isViolating := props.Adult >= visionpb.Likelihood_LIKELY ||
		props.Violence >= visionpb.Likelihood_LIKELY ||
		props.Racy >= visionpb.Likelihood_LIKELY

	if isViolating {
		reason := fmt.Sprintf("adult:%s, violence:%s, racy:%s", props.Adult, props.Violence, props.Racy)
		return false, reason, nil
	}

	return true, "", nil
}

// Close closes the underlying client
func (g *googleVisionClient) Close() error {
	return g.client.Close()
}
