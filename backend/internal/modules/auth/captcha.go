package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
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
		log.Printf("captcha: validation failed: empty captcha token")
		return ErrCaptchaRequired
	}
	secret := captchaSecret()
	if secret == "" {
		log.Printf("captcha: validation failed: CAPTCHA_SECRET is not configured")
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
		log.Printf("captcha: failed to create siteverify request: %v", err)
		return ErrCaptchaInvalid
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("captcha: siteverify request failed: %v", err)
		return ErrCaptchaInvalid
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		log.Printf("captcha: siteverify status code error: %d", resp.StatusCode)
		return ErrCaptchaInvalid
	}

	var payload captchaVerifyResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		log.Printf("captcha: decode payload failed: %v", err)
		return fmt.Errorf("%w: decode failed", ErrCaptchaInvalid)
	}
	if !payload.Success {
		log.Printf("captcha: token is invalid or expired (success=false)")
		return ErrCaptchaInvalid
	}
	return nil
}
