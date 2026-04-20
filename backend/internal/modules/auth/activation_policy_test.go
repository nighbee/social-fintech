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
		{name: "private range", ip: "10.0.0.2", want: false},
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

func TestValidateDateOfBirth(t *testing.T) {
	now := time.Date(2026, time.April, 20, 0, 0, 0, 0, time.UTC)

	tests := []struct {
		name    string
		dob     string
		wantErr error
	}{
		{name: "valid", dob: "2000-01-01", wantErr: nil},
		{name: "too old", dob: "1949-12-31", wantErr: ErrDateOfBirthTooOld},
		{name: "too young", dob: "2022-06-01", wantErr: ErrDateOfBirthTooYoung},
		{name: "bad format", dob: "01-01-2000", wantErr: ErrInvalidDateOfBirth},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := validateDateOfBirth(tt.dob, now)
			if tt.wantErr == nil && err != nil {
				t.Fatalf("expected nil error, got %v", err)
			}
			if tt.wantErr != nil && err != tt.wantErr {
				t.Fatalf("expected %v, got %v", tt.wantErr, err)
			}
		})
	}
}

func TestTrimUsername(t *testing.T) {
	long := "abcdefghijklmnopqrstuvwxyz_very_long_tail"
	got := trimUsername(long)
	if len(got) != maxUsernameLength {
		t.Fatalf("expected trimmed username length %d, got %d", maxUsernameLength, len(got))
	}

	empty := trimUsername("   ")
	if empty == "" {
		t.Fatal("expected fallback username for empty input")
	}
}
