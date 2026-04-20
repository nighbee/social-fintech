package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

const defaultCaptchaVerifyURL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"

type captchaVerifyResponse struct {
	Success bool `json:"success"`
}

func shouldEnforceCaptcha() bool {
	v := strings.TrimSpace(strings.ToLower(os.Getenv("CAPTCHA_ENABLED")))
	return v == "1" || v == "true" || v == "yes"
}

func captchaSecret() string {
	return strings.TrimSpace(os.Getenv("CAPTCHA_SECRET"))
}

func captchaVerifyURL() string {
	v := strings.TrimSpace(os.Getenv("CAPTCHA_VERIFY_URL"))
	if v == "" {
		return defaultCaptchaVerifyURL
	}
	return v
}

func verifyCaptchaToken(ctx context.Context, token, remoteIP string) error {
	if !shouldEnforceCaptcha() {
		return nil
	}
	if strings.TrimSpace(token) == "" {
		return ErrCaptchaRequired
	}
	secret := captchaSecret()
	if secret == "" {
		return ErrCaptchaInvalid
	}

	form := url.Values{}
	form.Set("secret", secret)
	form.Set("response", strings.TrimSpace(token))
	if strings.TrimSpace(remoteIP) != "" {
		form.Set("remoteip", strings.TrimSpace(remoteIP))
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, captchaVerifyURL(), strings.NewReader(form.Encode()))
	if err != nil {
		return ErrCaptchaInvalid
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return ErrCaptchaInvalid
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return ErrCaptchaInvalid
	}

	var payload captchaVerifyResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return fmt.Errorf("%w: decode failed", ErrCaptchaInvalid)
	}
	if !payload.Success {
		return ErrCaptchaInvalid
	}
	return nil
}
