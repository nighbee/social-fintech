package auth

import "strings"

const MaxUsernameLength = 30

func CleanUsername(input string) string {
	var b strings.Builder
	b.Grow(len(input))
	for i := 0; i < len(input); i++ {
		ch := input[i]
		if (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') || ch == '_' {
			if ch >= 'A' && ch <= 'Z' {
				ch = ch + ('a' - 'A')
			}
			b.WriteByte(ch)
		}
	}
	return b.String()
}

// Deprecated: use CleanUsername instead.
func cleanUsername(input string) string {
	return CleanUsername(input)
}
