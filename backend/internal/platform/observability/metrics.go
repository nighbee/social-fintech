package observability

import (
	"sort"
	"sync"
	"time"
)

type SnapshotData struct {
	GeneratedAtUTC          time.Time      `json:"generated_at_utc"`
	RegistrationAttempts    []MetricRecord `json:"registration_attempts"`
	RegistrationSuccesses   []MetricRecord `json:"registration_successes"`
	RegistrationFailures    []MetricRecord `json:"registration_failures"`
	PostPublishAttempts     int64          `json:"post_publish_attempts"`
	PostPublishSuccesses    int64          `json:"post_publish_successes"`
	PostPublishFailures     int64          `json:"post_publish_failures"`
	PostPublishLatencyAvgMs float64        `json:"post_publish_latency_avg_ms"`
	MediaPersistFailures    []MetricRecord `json:"media_persist_failures"`
}

type MetricRecord struct {
	Key   string `json:"key"`
	Count int64  `json:"count"`
}

type inMemoryMetrics struct {
	mu                    sync.RWMutex
	registrationAttempts  map[string]int64
	registrationSuccesses map[string]int64
	registrationFailures  map[string]int64
	mediaPersistFailures  map[string]int64
	postPublishAttempts   int64
	postPublishSuccesses  int64
	postPublishFailures   int64
	postPublishLatencySum time.Duration
	postPublishLatencyCnt int64
}

var metrics = &inMemoryMetrics{
	registrationAttempts:  map[string]int64{},
	registrationSuccesses: map[string]int64{},
	registrationFailures:  map[string]int64{},
	mediaPersistFailures:  map[string]int64{},
}

func IncRegistrationAttempt(flow string) {
	metrics.mu.Lock()
	defer metrics.mu.Unlock()
	metrics.registrationAttempts[flow]++
}

func IncRegistrationSuccess(flow string) {
	metrics.mu.Lock()
	defer metrics.mu.Unlock()
	metrics.registrationSuccesses[flow]++
}

func IncRegistrationFailure(flow, reason string) {
	metrics.mu.Lock()
	defer metrics.mu.Unlock()
	metrics.registrationFailures[flow+":"+reason]++
}

func IncPostPublishAttempt() {
	metrics.mu.Lock()
	defer metrics.mu.Unlock()
	metrics.postPublishAttempts++
}

func ObservePostPublishLatency(d time.Duration, ok bool) {
	metrics.mu.Lock()
	defer metrics.mu.Unlock()
	metrics.postPublishLatencySum += d
	metrics.postPublishLatencyCnt++
	if ok {
		metrics.postPublishSuccesses++
		return
	}
	metrics.postPublishFailures++
}

func IncMediaPersistFailure(stage string) {
	metrics.mu.Lock()
	defer metrics.mu.Unlock()
	metrics.mediaPersistFailures[stage]++
}

func Snapshot() SnapshotData {
	metrics.mu.RLock()
	defer metrics.mu.RUnlock()

	avgMs := 0.0
	if metrics.postPublishLatencyCnt > 0 {
		avgMs = float64(metrics.postPublishLatencySum.Milliseconds()) / float64(metrics.postPublishLatencyCnt)
	}

	return SnapshotData{
		GeneratedAtUTC:          time.Now().UTC(),
		RegistrationAttempts:    sortedRecords(metrics.registrationAttempts),
		RegistrationSuccesses:   sortedRecords(metrics.registrationSuccesses),
		RegistrationFailures:    sortedRecords(metrics.registrationFailures),
		PostPublishAttempts:     metrics.postPublishAttempts,
		PostPublishSuccesses:    metrics.postPublishSuccesses,
		PostPublishFailures:     metrics.postPublishFailures,
		PostPublishLatencyAvgMs: avgMs,
		MediaPersistFailures:    sortedRecords(metrics.mediaPersistFailures),
	}
}

func ResetForTests() {
	metrics.mu.Lock()
	defer metrics.mu.Unlock()
	metrics.registrationAttempts = map[string]int64{}
	metrics.registrationSuccesses = map[string]int64{}
	metrics.registrationFailures = map[string]int64{}
	metrics.mediaPersistFailures = map[string]int64{}
	metrics.postPublishAttempts = 0
	metrics.postPublishSuccesses = 0
	metrics.postPublishFailures = 0
	metrics.postPublishLatencySum = 0
	metrics.postPublishLatencyCnt = 0
}

func sortedRecords(src map[string]int64) []MetricRecord {
	keys := make([]string, 0, len(src))
	for k := range src {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	out := make([]MetricRecord, 0, len(keys))
	for _, k := range keys {
		out = append(out, MetricRecord{Key: k, Count: src[k]})
	}
	return out
}
