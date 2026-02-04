package geolocation

import (
	"net"
	"strings"

	"github.com/gofiber/fiber/v2"
)

// ExtractIPFromRequest extracts the real client IP address from Fiber request
// It checks X-Forwarded-For, X-Real-IP headers and falls back to RemoteAddr
func ExtractIPFromRequest(req *fiber.Request) string {
	// Check X-Forwarded-For header (set by proxies/load balancers)
	if forwarded := string(req.Header.Peek("X-Forwarded-For")); forwarded != "" {
		// X-Forwarded-For can contain multiple IPs (client, proxy1, proxy2)
		// The first one is typically the real client IP
		ips := strings.Split(forwarded, ",")
		if len(ips) > 0 {
			ip := strings.TrimSpace(ips[0])
			if isValidIP(ip) {
				return ip
			}
		}
	}

	// Check X-Real-IP header (set by some proxies)
	if realIP := string(req.Header.Peek("X-Real-IP")); realIP != "" {
		if isValidIP(realIP) {
			return realIP
		}
	}

	// Check CF-Connecting-IP (set by Cloudflare)
	if cfIP := string(req.Header.Peek("CF-Connecting-IP")); cfIP != "" {
		if isValidIP(cfIP) {
			return cfIP
		}
	}

	// Fall back to RemoteAddr
	remoteAddr := req.Header.Peek("RemoteAddr")
	if remoteAddr == nil {
		return ""
	}

	ip, _, err := net.SplitHostPort(string(remoteAddr))
	if err != nil {
		// If RemoteAddr is just an IP without port
		ip = string(remoteAddr)
	}

	if isValidIP(ip) {
		return ip
	}

	return ""
}

// isValidIP checks if a string is a valid IP address
func isValidIP(ip string) bool {
	return net.ParseIP(ip) != nil
}
