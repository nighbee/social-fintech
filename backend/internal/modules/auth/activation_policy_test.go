package auth

import (
	"testing"
	"time"
)

func TestClassifyInitialActivation_Active(t *testing.T) {
	now := time.Now().UTC()
	status, until := classifyInitialActivation(1, 1, now)
	if status != "active" {
		t.Fatalf("expected active, got %q", status)
	}
	if until == nil || !until.Equal(now) {
		t.Fatalf("expected unlocked_at equal now, got %v", until)
	}
}

func TestClassifyInitialActivation_Restricted(t *testing.T) {
	now := time.Now().UTC()
	status, until := classifyInitialActivation(activationDeviceRegistrationsLimit+1, 1, now)
	if status != "restricted" {
		t.Fatalf("expected restricted, got %q", status)
	}
	if until == nil {
		t.Fatal("expected restrictions_until")
	}
	want := now.Add(72 * time.Hour)
	if until.Sub(want) > time.Second || want.Sub(*until) > time.Second {
		t.Fatalf("expected ~72h restriction, got %v", until)
	}
}

func TestClassifyInitialActivation_Suspicious(t *testing.T) {
	now := time.Now().UTC()
	status, until := classifyInitialActivation(activationDeviceSuspiciousLimit+1, 1, now)
	if status != "suspicious" {
		t.Fatalf("expected suspicious, got %q", status)
	}
	if until == nil {
		t.Fatal("expected restrictions_until")
	}
	want := now.Add(120 * time.Hour)
	if until.Sub(want) > time.Second || want.Sub(*until) > time.Second {
		t.Fatalf("expected ~120h restriction, got %v", until)
	}
}

func TestIsTrustedRegistrationIP(t *testing.T) {
	tests := []struct {
		name string
		ip   string
		want bool
	}{
		{name: "loopback", ip: "127.0.0.1", want: true},
		{name: "private range", ip: "10.0.0.2", want: true},
		{name: "public ip", ip: "8.8.8.8", want: false},
		{name: "invalid", ip: "nope", want: false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := isTrustedRegistrationIP(tt.ip); got != tt.want {
				t.Fatalf("isTrustedRegistrationIP(%q) = %v, want %v", tt.ip, got, tt.want)
			}
		})
	}
}
