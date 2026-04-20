package auth

import (
	"context"
	"os"
	"testing"
)

func TestVerifyCaptchaToken_Disabled(t *testing.T) {
	t.Setenv("CAPTCHA_ENABLED", "false")
	if err := verifyCaptchaToken(context.Background(), "", "127.0.0.1"); err != nil {
		t.Fatalf("expected nil when captcha disabled, got %v", err)
	}
}

func TestVerifyCaptchaToken_RequiresTokenWhenEnabled(t *testing.T) {
	t.Setenv("CAPTCHA_ENABLED", "true")
	t.Setenv("CAPTCHA_SECRET", "dummy")
	t.Setenv("CAPTCHA_VERIFY_URL", "http://127.0.0.1:0")
	if err := verifyCaptchaToken(context.Background(), "", "127.0.0.1"); err != ErrCaptchaRequired {
		t.Fatalf("expected ErrCaptchaRequired, got %v", err)
	}
}

func TestVerifyCaptchaToken_MissingSecretFails(t *testing.T) {
	t.Setenv("CAPTCHA_ENABLED", "true")
	_ = os.Unsetenv("CAPTCHA_SECRET")
	t.Setenv("CAPTCHA_VERIFY_URL", "http://127.0.0.1:0")
	if err := verifyCaptchaToken(context.Background(), "token", "127.0.0.1"); err != ErrCaptchaInvalid {
		t.Fatalf("expected ErrCaptchaInvalid, got %v", err)
	}
}
