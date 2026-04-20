package observability

import (
	"fmt"
	"strings"
)

func PrometheusText() string {
	s := Snapshot()
	var b strings.Builder

	b.WriteString("# TYPE brightbund_registration_attempts_total counter\n")
	for _, rec := range s.RegistrationAttempts {
		b.WriteString(fmt.Sprintf("brightbund_registration_attempts_total{flow=%q} %d\n", rec.Key, rec.Count))
	}
	b.WriteString("# TYPE brightbund_registration_successes_total counter\n")
	for _, rec := range s.RegistrationSuccesses {
		b.WriteString(fmt.Sprintf("brightbund_registration_successes_total{flow=%q} %d\n", rec.Key, rec.Count))
	}
	b.WriteString("# TYPE brightbund_registration_failures_total counter\n")
	for _, rec := range s.RegistrationFailures {
		b.WriteString(fmt.Sprintf("brightbund_registration_failures_total{reason=%q} %d\n", rec.Key, rec.Count))
	}
	b.WriteString("# TYPE brightbund_post_publish_attempts_total counter\n")
	b.WriteString(fmt.Sprintf("brightbund_post_publish_attempts_total %d\n", s.PostPublishAttempts))
	b.WriteString("# TYPE brightbund_post_publish_successes_total counter\n")
	b.WriteString(fmt.Sprintf("brightbund_post_publish_successes_total %d\n", s.PostPublishSuccesses))
	b.WriteString("# TYPE brightbund_post_publish_failures_total counter\n")
	b.WriteString(fmt.Sprintf("brightbund_post_publish_failures_total %d\n", s.PostPublishFailures))
	b.WriteString("# TYPE brightbund_post_publish_latency_avg_ms gauge\n")
	b.WriteString(fmt.Sprintf("brightbund_post_publish_latency_avg_ms %.2f\n", s.PostPublishLatencyAvgMs))
	b.WriteString("# TYPE brightbund_media_persist_failures_total counter\n")
	for _, rec := range s.MediaPersistFailures {
		b.WriteString(fmt.Sprintf("brightbund_media_persist_failures_total{stage=%q} %d\n", rec.Key, rec.Count))
	}

	return b.String()
}
