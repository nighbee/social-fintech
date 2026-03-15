package settings

import (
	"bytes"
	"context"
	"encoding/json"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/gofiber/fiber/v2"
	"golang.org/x/crypto/bcrypt"
)

func newSettingsTestApp(handler *Handler, withAuth bool, sessionID string) *fiber.App {
	app := fiber.New()
	if withAuth {
		app.Use(func(c *fiber.Ctx) error {
			c.Locals("user_id", "user-1")
			if sessionID != "" {
				c.Locals("session_id", sessionID)
			}
			return c.Next()
		})
	}
	return app
}

func TestGetSecurity_UnauthorizedReturns401(t *testing.T) {
	handler := NewHandler(NewService(&testRepo{}, nil))
	app := newSettingsTestApp(handler, false, "")
	app.Get("/settings/security", handler.GetSecurity)

	req := httptest.NewRequest(http.MethodGet, "/settings/security", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app test failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", resp.StatusCode)
	}
}

func TestDeleteSession_CurrentSessionReturns400(t *testing.T) {
	handler := NewHandler(NewService(&testRepo{}, nil))
	app := newSettingsTestApp(handler, true, "session-1")
	app.Delete("/settings/security/sessions/:id", handler.DeleteSession)

	req := httptest.NewRequest(http.MethodDelete, "/settings/security/sessions/session-1", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app test failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", resp.StatusCode)
	}

	var body map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if body["error"] != "cannot_delete_current_session" {
		t.Fatalf("unexpected error body: %#v", body)
	}
}

func TestDeleteAccountVerify_InvalidCredentialsReturns401(t *testing.T) {
	hash, err := bcrypt.GenerateFromPassword([]byte("Correct1!"), bcrypt.DefaultCost)
	if err != nil {
		t.Fatalf("generate hash: %v", err)
	}

	repo := &testRepo{
		getLatestDeleteReqFn: func(ctx context.Context, userID string) (*deleteAccountRequest, error) {
			return &deleteAccountRequest{ID: "req-1", UserID: userID, VerificationMethod: "password"}, nil
		},
		getUserPasswordHashFn: func(ctx context.Context, userID string) (string, error) {
			return string(hash), nil
		},
	}
	handler := NewHandler(NewService(repo, nil))
	app := newSettingsTestApp(handler, true, "session-1")
	app.Post("/settings/security/delete-account/verify", handler.DeleteAccountVerify)

	req := httptest.NewRequest(http.MethodPost, "/settings/security/delete-account/verify", strings.NewReader(`{"password":"Wrong1!"}`))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app test failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", resp.StatusCode)
	}

	var body map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if body["error"] != "invalid_credentials" {
		t.Fatalf("unexpected error body: %#v", body)
	}
}

func TestDeleteAccountFinalize_InvalidTokenReturns400(t *testing.T) {
	repo := &testRepo{
		getLatestDeleteReqFn: func(ctx context.Context, userID string) (*deleteAccountRequest, error) {
			token := "expected-token"
			expires := time.Now().Add(10 * time.Minute)
			return &deleteAccountRequest{
				ID:                  "req-1",
				UserID:              userID,
				VerificationToken:   &token,
				VerificationExpires: &expires,
			}, nil
		},
	}
	handler := NewHandler(NewService(repo, nil))
	app := newSettingsTestApp(handler, true, "session-1")
	app.Delete("/settings/security/delete-account", handler.DeleteAccountFinalize)

	req := httptest.NewRequest(http.MethodDelete, "/settings/security/delete-account", strings.NewReader(`{"verification_token":"wrong-token"}`))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app test failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", resp.StatusCode)
	}

	var body map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if body["error"] != "delete_verification_invalid" {
		t.Fatalf("unexpected error body: %#v", body)
	}
}

func TestDeleteAccountFinalize_ExpiredTokenReturns400(t *testing.T) {
	repo := &testRepo{
		getLatestDeleteReqFn: func(ctx context.Context, userID string) (*deleteAccountRequest, error) {
			token := "expected-token"
			expires := time.Now().Add(-1 * time.Minute)
			return &deleteAccountRequest{
				ID:                  "req-1",
				UserID:              userID,
				VerificationToken:   &token,
				VerificationExpires: &expires,
			}, nil
		},
	}
	handler := NewHandler(NewService(repo, nil))
	app := newSettingsTestApp(handler, true, "session-1")
	app.Delete("/settings/security/delete-account", handler.DeleteAccountFinalize)

	req := httptest.NewRequest(http.MethodDelete, "/settings/security/delete-account", strings.NewReader(`{"verification_token":"expected-token"}`))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app test failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", resp.StatusCode)
	}

	var body map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if body["error"] != "delete_verification_expired" {
		t.Fatalf("unexpected error body: %#v", body)
	}
}

func TestReportBug_DescriptionRequiredReturns400(t *testing.T) {
	handler := NewHandler(NewService(&testRepo{}, nil))
	app := newSettingsTestApp(handler, true, "session-1")
	app.Post("/settings/support/bugs", handler.ReportBug)

	req := httptest.NewRequest(http.MethodPost, "/settings/support/bugs", strings.NewReader(`{"description":"   "}`))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app test failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", resp.StatusCode)
	}
}

func TestReportBug_MultipartStoresScreenshotReferenceAndReturns201(t *testing.T) {
	var storedReq *BugReportRequest
	repo := &testRepo{
		createBugReportFn: func(ctx context.Context, userID string, req *BugReportRequest) error {
			copyReq := *req
			storedReq = &copyReq
			return nil
		},
	}
	handler := NewHandler(NewService(repo, nil))
	app := newSettingsTestApp(handler, true, "session-1")
	app.Post("/settings/support/bugs", handler.ReportBug)

	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	if err := writer.WriteField("description", "App freezes on settings page"); err != nil {
		t.Fatalf("write description: %v", err)
	}
	if err := writer.WriteField("app_version", "1.2.3"); err != nil {
		t.Fatalf("write app_version: %v", err)
	}
	if err := writer.WriteField("device_os", "ios"); err != nil {
		t.Fatalf("write device_os: %v", err)
	}
	part, err := writer.CreateFormFile("screenshot", "screen.png")
	if err != nil {
		t.Fatalf("create form file: %v", err)
	}
	if _, err := part.Write([]byte("fake image bytes")); err != nil {
		t.Fatalf("write form file: %v", err)
	}
	if err := writer.Close(); err != nil {
		t.Fatalf("close writer: %v", err)
	}

	req := httptest.NewRequest(http.MethodPost, "/settings/support/bugs", &body)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app test failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("expected 201, got %d", resp.StatusCode)
	}
	if storedReq == nil {
		t.Fatal("expected bug report request to be stored")
	}
	if storedReq.Screenshot == "" || !strings.HasPrefix(storedReq.Screenshot, "/uploads/bug-reports/") {
		t.Fatalf("unexpected screenshot path: %q", storedReq.Screenshot)
	}
	cleanupPath := filepath.Clean("." + filepath.FromSlash(storedReq.Screenshot))
	defer os.Remove(cleanupPath)
	defer os.Remove(filepath.Dir(cleanupPath))
	if _, err := os.Stat(cleanupPath); err != nil {
		t.Fatalf("expected screenshot file to exist at %q: %v", cleanupPath, err)
	}
	if storedReq.AppVersion != "1.2.3" || storedReq.DeviceOS != "ios" {
		t.Fatalf("unexpected metadata stored: %#v", storedReq)
	}
	if storedReq.Description != "App freezes on settings page" {
		t.Fatalf("unexpected description stored: %q", storedReq.Description)
	}
}
