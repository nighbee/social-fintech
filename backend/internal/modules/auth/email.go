package auth

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"log"
	"math/big"
	"regexp"
	"strings"
	"time"
)

const emailCodeTTL = 10 * time.Minute

// EmailSender abstracts the SMTP / 3rd-party transport used to deliver
// 6-digit confirmation codes during the email verification flow. The
// production binary wires up a real SMTP sender; tests and local runs
// fall back to NoopEmailSender which logs the code instead of sending it.
type EmailSender interface {
	Send(ctx context.Context, to, subject, body string) error
}

// NoopEmailSender is the default fallback when no SMTP transport is
// configured. It prints the destination + body to the application log,
// matching the behaviour of NoopSMSSender for SMS codes.
type NoopEmailSender struct{}

func NewNoopEmailSender() *NoopEmailSender {
	return &NoopEmailSender{}
}

func (s *NoopEmailSender) Send(ctx context.Context, to, subject, body string) error {
	log.Printf("email_placeholder to=%s subject=%q body=%q", to, subject, body)
	return nil
}

// emailRegex is intentionally simple: the SMTP server is the source of
// truth for deliverability; we only reject obvious garbage so we don't
// generate verification rows for inputs that can't possibly succeed.
var emailRegex = regexp.MustCompile(`^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$`)

// normalizeEmail lower-cases and trims, since email local-parts are
// technically case-sensitive but virtually all providers treat them as
// case-insensitive — matching DB lookup behaviour elsewhere in auth.
func normalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}

func validateEmail(email string) error {
	if !emailRegex.MatchString(email) {
		return ErrInvalidEmail
	}
	return nil
}

// generate6DigitOTP returns a uniformly-random 6-digit numeric code.
// 6 digits matches industry convention for email codes and gives 1 in
// 1,000,000 collision resistance — significantly stronger than the
// 4-digit SMS code used by the phone flow.
func generate6DigitOTP() (string, error) {
	max := big.NewInt(1000000)
	n, err := rand.Int(rand.Reader, max)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

func hashEmailCode(code string) string {
	sum := sha256.Sum256([]byte(code))
	return hex.EncodeToString(sum[:])
}
