package observability

import (
	"strings"
	"testing"
)

func TestPrometheusTextContainsCoreMetrics(t *testing.T) {
	ResetForTests()
	IncRegistrationAttempt("email")
	IncRegistrationSuccess("email")
	IncRegistrationFailure("email", "captcha_invalid")
	IncPostPublishAttempt()
	ObservePostPublishLatency(1000000, true)

	out := PrometheusText()
	for _, needle := range []string{
		"brightbund_registration_attempts_total",
		"brightbund_registration_successes_total",
		"brightbund_registration_failures_total",
		"brightbund_post_publish_attempts_total",
		"brightbund_post_publish_latency_avg_ms",
	} {
		if !strings.Contains(out, needle) {
			t.Fatalf("expected %q in prometheus output", needle)
		}
	}
}
