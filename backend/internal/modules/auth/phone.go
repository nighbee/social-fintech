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

//форамтриуер норм в удобном формате
func normalizePhone(countryCode, number string) (string, string) {
	cc := strings.TrimSpace(countryCode)
	n := strings.TrimSpace(number)
	n = strings.ReplaceAll(n, " ", "")
	n = strings.ReplaceAll(n, "-", "")
	return cc, n
}

//отпередляет для country code-а
func phoneKey(countryCode, number string) string {
	cc, n := normalizePhone(countryCode, number)
	return fmt.Sprintf("%s%s", cc, n)
}

//нужен OTP генерироваться
func generateOTP() (string, error) {
	max := big.NewInt(1000000)
	n, err := rand.Int(rand.Reader, max)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

//именно генерит sha256
func hashCode(code string) string {
	sum := sha256.Sum256([]byte(code))
	return hex.EncodeToString(sum[:])
}
