package feed

import (
	"bytes"
	"context"
	"errors"
	"io"
	"mime/multipart"
	"net/http/httptest"
	"net/textproto"
	"testing"

	"github.com/gofiber/fiber/v2"
)

type mockUploadStorage struct {
	uploadFn func(ctx context.Context, objectName string, reader io.Reader, size int64, contentType string) (string, error)
}

func (m *mockUploadStorage) Upload(ctx context.Context, objectName string, reader io.Reader, size int64, contentType string) (string, error) {
	if m.uploadFn != nil {
		return m.uploadFn(ctx, objectName, reader, size, contentType)
	}
	return "https://cdn.example.com/" + objectName, nil
}

func buildMultipartRequest(t *testing.T, fieldName, fileName, contentType string, payload []byte) (*bytes.Buffer, string) {
	t.Helper()

	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)

	partHeader := make(textproto.MIMEHeader)
	partHeader.Set("Content-Disposition", `form-data; name="`+fieldName+`"; filename="`+fileName+`"`)
	partHeader.Set("Content-Type", contentType)
	part, err := writer.CreatePart(partHeader)
	if err != nil {
		t.Fatalf("create part: %v", err)
	}
	if _, err := part.Write(payload); err != nil {
		t.Fatalf("write payload: %v", err)
	}

	if err := writer.Close(); err != nil {
		t.Fatalf("close writer: %v", err)
	}
	return body, writer.FormDataContentType()
}

func newUploadTestApp(storage ObjectStorage) *fiber.App {
	app := fiber.New(fiber.Config{
		BodyLimit: int(maxVideoSizeBytes) + 1024,
	})
	h := NewHandler(nil, nil, nil, storage, "")

	app.Post("/upload", func(c *fiber.Ctx) error {
		c.Locals("user_id", "11111111-1111-1111-1111-111111111111")
		return h.UploadMedia(c)
	})
	return app
}

func TestUploadMedia_RejectsUnsupportedType(t *testing.T) {
	app := newUploadTestApp(&mockUploadStorage{})
	body, ctype := buildMultipartRequest(t, "file", "payload.bin", "application/octet-stream", []byte("abc"))

	req := httptest.NewRequest("POST", "/upload", body)
	req.Header.Set("Content-Type", ctype)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	if resp.StatusCode != fiber.StatusBadRequest {
		t.Fatalf("expected 400, got %d", resp.StatusCode)
	}
}

func TestUploadMedia_RejectsOversizedImage(t *testing.T) {
	app := newUploadTestApp(&mockUploadStorage{})
	oversized := bytes.Repeat([]byte("a"), maxImageSizeBytes+1)
	body, ctype := buildMultipartRequest(t, "file", "image.jpg", "image/jpeg", oversized)

	req := httptest.NewRequest("POST", "/upload", body)
	req.Header.Set("Content-Type", ctype)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	if resp.StatusCode != fiber.StatusRequestEntityTooLarge {
		t.Fatalf("expected 413, got %d", resp.StatusCode)
	}
}

func TestUploadMedia_ReturnsStorageFailure(t *testing.T) {
	app := newUploadTestApp(&mockUploadStorage{
		uploadFn: func(ctx context.Context, objectName string, reader io.Reader, size int64, contentType string) (string, error) {
			return "", errors.New("storage unreachable")
		},
	})
	body, ctype := buildMultipartRequest(t, "file", "image.png", "image/png", []byte("abc"))

	req := httptest.NewRequest("POST", "/upload", body)
	req.Header.Set("Content-Type", ctype)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	if resp.StatusCode != fiber.StatusInternalServerError {
		t.Fatalf("expected 500, got %d", resp.StatusCode)
	}
}

func TestUploadMedia_Success(t *testing.T) {
	app := newUploadTestApp(&mockUploadStorage{
		uploadFn: func(ctx context.Context, objectName string, reader io.Reader, size int64, contentType string) (string, error) {
			return "https://cdn.example.com/" + objectName, nil
		},
	})
	body, ctype := buildMultipartRequest(t, "file", "image.webp", "image/webp", []byte("abc"))

	req := httptest.NewRequest("POST", "/upload", body)
	req.Header.Set("Content-Type", ctype)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	if resp.StatusCode != fiber.StatusCreated {
		t.Fatalf("expected 201, got %d", resp.StatusCode)
	}
}
