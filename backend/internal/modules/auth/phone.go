package auth

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"log"
	"math/big"
	"strings"
	"time"
)

const phoneCodeTTL = 10 * time.Minute

// интерфейс для отправки, для удобства
type SMSSender interface {
	Send(ctx context.Context, to, message string) error
}

// заглушка логирует код
type NoopSMSSender struct{}

func NewNoopSMSSender() *NoopSMSSender {
	return &NoopSMSSender{}
}

// проверка статуса отправки
func (s *NoopSMSSender) Send(ctx context.Context, to, message string) error {
	// Placeholder: log instead of sending SMS.
	log.Printf("sms_placeholder to=%s msg=%s", to, message)
	return nil
}

// форамтриуер норм в удобном формате
func normalizePhone(countryCode, number string) (string, string) {
	cc := strings.TrimSpace(countryCode)
	n := strings.TrimSpace(number)
	// Strip the most common formatting noise users paste from contact lists.
	for _, ch := range []string{" ", "-", "(", ")", "."} {
		n = strings.ReplaceAll(n, ch, "")
	}
	cc = strings.TrimPrefix(cc, "+")
	if cc != "" && !strings.HasPrefix(cc, "+") {
		cc = "+" + cc
	}
	return cc, n
}

// validateE164 enforces the E.164 international phone format on the
// already-normalized country code and subscriber number:
//   - country code: leading "+", 1–3 ASCII digits
//   - subscriber number: ASCII digits only
//   - combined length excluding the leading "+" must fit in [8, 15] digits
//
// Reference: ITU-T E.164 (2010). Total length cap of 15 digits is the spec
// maximum; the lower bound of 8 prevents trivially short fake numbers.
func validateE164(countryCode, number string) error {
	if countryCode == "" || number == "" {
		return ErrInvalidPhone
	}
	if !strings.HasPrefix(countryCode, "+") {
		return ErrInvalidPhone
	}
	cc := countryCode[1:]
	if len(cc) < 1 || len(cc) > 3 || !isAllDigits(cc) {
		return ErrInvalidPhone
	}
	if !isAllDigits(number) {
		return ErrInvalidPhone
	}
	total := len(cc) + len(number)
	if total < 8 || total > 15 {
		return ErrInvalidPhone
	}
	return nil
}

func isAllDigits(s string) bool {
	if s == "" {
		return false
	}
	for _, r := range s {
		if r < '0' || r > '9' {
			return false
		}
	}
	return true
}

// отпередляет для country code-а
func phoneKey(countryCode, number string) string {
	cc, n := normalizePhone(countryCode, number)
	return fmt.Sprintf("%s%s", cc, n)
}

// нужен OTP генерироваться (4-digit code)
func generateOTP() (string, error) {
	max := big.NewInt(10000)
	n, err := rand.Int(rand.Reader, max)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%04d", n.Int64()), nil
}

// именно генерит sha256
func hashCode(code string) string {
	sum := sha256.Sum256([]byte(code))
	return hex.EncodeToString(sum[:])
}
