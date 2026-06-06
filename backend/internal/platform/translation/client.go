package translation

import (
	"context"
	"fmt"

	"cloud.google.com/go/translate"
	"golang.org/x/text/language"
	"google.golang.org/api/option"
)

// Client defines the interface for text translation
type Client interface {
	TranslateText(ctx context.Context, text, targetLang string) (string, error)
	Close() error
}

type googleTranslationClient struct {
	client *translate.Client
}

// NewClient creates a new Google Translation API client
func NewClient(ctx context.Context, credentialsPath string) (Client, error) {
	var opts []option.ClientOption
	if credentialsPath != "" {
		opts = append(opts, option.WithCredentialsFile(credentialsPath))
	}

	c, err := translate.NewClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("translate.NewClient: %w", err)
	}

	return &googleTranslationClient{client: c}, nil
}

// TranslateText translates single string to the targetLang
func (g *googleTranslationClient) TranslateText(ctx context.Context, text, targetLang string) (string, error) {
	lang, err := language.Parse(targetLang)
	if err != nil {
		return "", fmt.Errorf("language.Parse targetLang %q: %w", targetLang, err)
	}

	resp, err := g.client.Translate(ctx, []string{text}, lang, nil)
	if err != nil {
		return "", fmt.Errorf("g.client.Translate: %w", err)
	}

	if len(resp) == 0 {
		return "", fmt.Errorf("empty translation response")
	}

	return resp[0].Text, nil
}

// Close releases resources of translation client
func (g *googleTranslationClient) Close() error {
	return g.client.Close()
}
