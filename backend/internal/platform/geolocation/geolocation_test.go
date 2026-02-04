package geolocation

import (
	"context"
	"testing"
)

func TestIPAPIClient_GetLocationByIP(t *testing.T) {
	client := NewIPAPIClient()
	ctx := context.Background()

	tests := []struct {
		name    string
		ip      string
		wantErr bool
	}{
		{
			name:    "Valid public IP (Google DNS)",
			ip:      "8.8.8.8",
			wantErr: false,
		},
		{
			name:    "Localhost should fail",
			ip:      "127.0.0.1",
			wantErr: true,
		},
		{
			name:    "Empty IP should fail",
			ip:      "",
			wantErr: true,
		},
		{
			name:    "IPv6 localhost should fail",
			ip:      "::1",
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			loc, err := client.GetLocationByIP(ctx, tt.ip)

			if (err != nil) != tt.wantErr {
				t.Errorf("GetLocationByIP() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			if !tt.wantErr {
				if loc == nil {
					t.Error("Expected location but got nil")
					return
				}
				if loc.Country == "" {
					t.Error("Expected country to be populated")
				}
				t.Logf("Location: %s, %s, %s (%.2f, %.2f)",
					loc.City, loc.Region, loc.Country, loc.Latitude, loc.Longitude)
			}
		})
	}
}
