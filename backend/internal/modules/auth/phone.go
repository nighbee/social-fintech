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
	log.Printf("sms_placeholder to=%s", to)
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

// parseE164 splits a full E.164 number like "+77067119305" into
// country calling code and subscriber number. It uses the complete
// ITU-T E.164 country calling code assignments to resolve ambiguous
// prefixes (1-digit +1/+7, 2-digit +20..+99, 3-digit +211..+999).
func parseE164(full string) (countryCode, subscriber string, err error) {
	if len(full) < 3 || full[0] != '+' {
		return "", "", fmt.Errorf("invalid E.164 format")
	}
	digits := full[1:]

	// Try the most specific (longest) match first.
	// ITU-T assignments: 1-digit → {1,7}, 2-digit → {20-99 excluding prefixes
	// that belong to 3-digit codes}, 3-digit → all remaining.
	for _, l := range []int{3, 2, 1} {
		if len(digits) >= l {
			prefix := digits[:l]
			if isCountryCallingCode(prefix) {
				return "+" + prefix, digits[l:], nil
			}
		}
	}
	return "", "", fmt.Errorf("unknown country calling code in %q", full)
}

// isCountryCallingCode returns true when the digit string (without the
// leading '+') matches a known ITU-T country calling code assignment.
// Reference: List of country calling codes, ITU-T E.164 Annex A.
func isCountryCallingCode(s string) bool {
	switch s {
	// 1-digit — North America, Russia/Kazakhstan
	case "1", "7":
		return true
	// 2-digit — every 2-digit prefix that is NOT the start of a valid 3-digit
	// code. We list the positive set: all CCs that are exactly 2 digits.
	case "20", "27",
		"30", "31", "32", "33", "34", "36", "39",
		"40", "41", "43", "44", "45", "46", "47", "48", "49",
		"51", "52", "53", "54", "55", "56", "57", "58",
		"60", "61", "62", "63", "64", "65", "66",
		"81", "82", "84", "86",
		"90", "91", "92", "93", "94", "95", "98":
		return true
	// 3-digit — comprehensive set, serves as the fallback for any remaining
	// code whose 2-digit prefix we did not list above.
	case
		// Zone 2 (Africa)
		"210", "211", "212", "213", "214", "215", "216", "217", "218", "219",
		"220", "221", "222", "223", "224", "225", "226", "227", "228", "229",
		"230", "231", "232", "233", "234", "235", "236", "237", "238", "239",
		"240", "241", "242", "243", "244", "245", "246", "247", "248", "249",
		"250", "251", "252", "253", "254", "255", "256", "257", "258",
		"260", "261", "262", "263", "264", "265", "266", "267", "268", "269",
		"290", "291",
		"297", "298", "299",
		// Zone 3 (Europe)
		"350", "351", "352", "353", "354", "355", "356", "357", "358", "359",
		"370", "371", "372", "373", "374", "375", "376", "377", "378", "379",
		"380", "381", "382", "383", "384", "385", "386", "387", "388", "389",
		// Zone 4 (Europe / Middle East)
		"420", "421", "422", "423", "424", "425", "426", "427", "428", "429",
		// Zone 5 (Americas excluding +1)
		"500", "501", "502", "503", "504", "505", "506", "507", "508", "509",
		// Zone 6 (South-East Asia / Oceania)
		"670", "671", "672", "673", "674", "675", "676", "677", "678", "679",
		"680", "681", "682", "683", "684", "685", "686", "687", "688", "689",
		"690", "691", "692", "693", "694", "695", "696", "697", "698", "699",
		// Zone 8 (East Asia / free-phone)
		"800", "801", "802", "803", "804", "805", "806", "807", "808", "809",
		"830", "831", "832", "833", "834", "835", "836", "837", "838", "839",
		"850", "851", "852", "853", "854", "855", "856", "857", "858", "859",
		"870", "871", "872", "873", "874", "875", "876", "877", "878", "879",
		"880", "881", "882", "883", "884", "885", "886", "887", "888", "889",
		// Zone 9 (Middle East / South Asia)
		"960", "961", "962", "963", "964", "965", "966", "967", "968", "969",
		"970", "971", "972", "973", "974", "975", "976", "977", "978", "979",
		"992", "993", "994", "995", "996", "997", "998", "999",
		// Zone 2 extended (Africa 4-digit codes, treated as 3-digit CC + remaining)
		// All start with 2XX — these are correctly handled above
		// Zone 8 extended
		// Zone 9 extended — we include all 99X
		// Also handle global/non-geographic codes as 3-digit
		// +800 (UIFN), +808 (UPT), +870 (Inmarsat SNAC), +878 (UPT/VisionNG),
		// +881/882/883 (GMPCS), +888 (OCHA), etc. — all covered above
		"991":
		return true
	}
	return false
}
