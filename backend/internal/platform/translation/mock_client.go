package translation

import (
	"context"
)

type MockClient struct {
	TranslateFn func(ctx context.Context, text, targetLang string) (string, error)
}

func (m *MockClient) TranslateText(ctx context.Context, text, targetLang string) (string, error) {
	if m.TranslateFn != nil {
		return m.TranslateFn(ctx, text, targetLang)
	}
	return text + " [mock translated to " + targetLang + "]", nil
}

func (m *MockClient) Close() error {
	return nil
}
