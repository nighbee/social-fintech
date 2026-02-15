package geolocation

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

// Location represents geographic location data
type Location struct {
	Country     string
	Region      string
	City        string
	CountryCode string
	RegionCode  string
	Latitude    float64
	Longitude   float64
}

// Service defines the interface for geolocation services
type Service interface {
	GetLocationByIP(ctx context.Context, ip string) (*Location, error)
}

// IPAPIClient implements geolocation using ip-api.com (free tier)
type IPAPIClient struct {
	httpClient *http.Client
	baseURL    string
}

type ipAPIResponse struct {
	Status      string  `json:"status"`
	Message     string  `json:"message"`
	Country     string  `json:"country"`
	CountryCode string  `json:"countryCode"`
	Region      string  `json:"regionName"`
	RegionCode  string  `json:"region"`
	City        string  `json:"city"`
	Lat         float64 `json:"lat"`
	Lon         float64 `json:"lon"`
}

func NewIPAPIClient() *IPAPIClient {
	return &IPAPIClient{
		httpClient: &http.Client{
			Timeout: 5 * time.Second,
		},
		baseURL: "http://ip-api.com/json",
	}
}

func (c *IPAPIClient) GetLocationByIP(ctx context.Context, ip string) (*Location, error) {
	if ip == "" || ip == "127.0.0.1" || ip == "::1" {
		return nil, fmt.Errorf("invalid or localhost IP address")
	}

	url := fmt.Sprintf("%s/%s?fields=status,message,country,countryCode,region,regionName,city,lat,lon", c.baseURL, ip)

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("http request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	var apiResp ipAPIResponse
	if err := json.NewDecoder(resp.Body).Decode(&apiResp); err != nil {
		return nil, fmt.Errorf("decode response: %w", err)
	}

	if apiResp.Status != "success" {
		return nil, fmt.Errorf("geolocation failed: %s", apiResp.Message)
	}

	return &Location{
		Country:     apiResp.Country,
		CountryCode: apiResp.CountryCode,
		Region:      apiResp.Region,
		RegionCode:  apiResp.RegionCode,
		City:        apiResp.City,
		Latitude:    apiResp.Lat,
		Longitude:   apiResp.Lon,
	}, nil
}
