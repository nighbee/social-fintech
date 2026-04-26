package vision

import (
	"context"
	"io"
)

type MockClient struct {
	DetectFunc func(ctx context.Context, reader io.Reader) (bool, string, error)
}

func (m *MockClient) DetectInappropriateContent(ctx context.Context, reader io.Reader) (bool, string, error) {
	if m.DetectFunc != nil {
		return m.DetectFunc(ctx, reader)
	}
	return true, "", nil
}
