package observability

import "testing"

func TestSnapshotAggregatesMetrics(t *testing.T) {
	ResetForTests()

	IncRegistrationAttempt("email")
	IncRegistrationSuccess("email")
	IncRegistrationFailure("email", "weak_password")
	IncPostPublishAttempt()
	ObservePostPublishLatency(1000000, true)
	IncMediaPersistFailure("create_post_repo")

	s := Snapshot()
	if s.PostPublishAttempts != 1 {
		t.Fatalf("expected 1 publish attempt, got %d", s.PostPublishAttempts)
	}
	if s.PostPublishSuccesses != 1 || s.PostPublishFailures != 0 {
		t.Fatalf("unexpected publish success/failure: %d/%d", s.PostPublishSuccesses, s.PostPublishFailures)
	}
	if len(s.RegistrationAttempts) != 1 || s.RegistrationAttempts[0].Key != "email" || s.RegistrationAttempts[0].Count != 1 {
		t.Fatalf("unexpected registration attempts snapshot: %+v", s.RegistrationAttempts)
	}
	if len(s.RegistrationFailures) != 1 || s.RegistrationFailures[0].Key != "email:weak_password" {
		t.Fatalf("unexpected registration failures snapshot: %+v", s.RegistrationFailures)
	}
	if len(s.MediaPersistFailures) != 1 || s.MediaPersistFailures[0].Key != "create_post_repo" {
		t.Fatalf("unexpected media persist failures snapshot: %+v", s.MediaPersistFailures)
	}
}
