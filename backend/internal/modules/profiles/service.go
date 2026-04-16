package profiles

import (
	"context"
	"fmt"
	"io"
	"path"
	"strings"
	"time"

	mapmodule "github.com/brightbund-backend/internal/modules/map"
	"github.com/brightbund-backend/internal/modules/ranks"
	"github.com/brightbund-backend/internal/platform/geolocation"
	"github.com/google/uuid"
)

type ObjectStorage interface {
	Upload(ctx context.Context, bucketName, objectName string, reader io.Reader, size int64, contentType string) (string, error)
	Download(ctx context.Context, bucketName, objectName string) (io.ReadCloser, error)
	Delete(ctx context.Context, bucketName, objectName string) error
}

type MapService interface {
	ResolveH3ToLocation(ctx context.Context, h3Index string) (*mapmodule.H3GeoMetadata, error)
}

type Service struct {
	repo       *Repository
	storage    ObjectStorage
	geolocator geolocation.Service
	mapService MapService
	cache      StatsCache // Optional cache for profile statistics
}

// LocationInput represents optional location override from client
type LocationInput struct {
	Country string
	Region  string
	City    string
	IP      string // Client IP for geolocation
}

const maxAvatarSizeBytes = 5 * 1024 * 1024 // 5MB

func NewService(repo *Repository, storage ObjectStorage, cache StatsCache, mapService MapService) *Service {
	return &Service{
		repo:       repo,
		storage:    storage,
		geolocator: geolocation.NewIPAPIClient(),
		mapService: mapService,
		cache:      cache,
	}
}

func (s *Service) GetMyProfile(ctx context.Context, userID string) (*Profile, error) {
	p, err := s.repo.GetProfile(ctx, userID)
	if err == ErrProfileNotFound {
		return s.repo.CreateDefaultProfile(ctx, userID)
	}
	if err != nil {
		return nil, err
	}
	p.RankTier = ranks.GetRankTierString(p.ReputationScore)
	return p, nil
}

func (s *Service) UpdateMyProfile(ctx context.Context, userID string, req *UpdateProfileRequest) (*Profile, error) {
	_, err := s.repo.GetProfile(ctx, userID)
	if err == ErrProfileNotFound {
		if _, err := s.repo.CreateDefaultProfile(ctx, userID); err != nil {
			return nil, err
		}
	}

	// Resolve location from client IP if not provided
	if req.ClientIP != "" && req.Country == nil && req.City == nil {
		// 2. Fall back to IP-based location if coordinates are missing
		if loc, err := s.geolocator.GetLocationByIP(ctx, req.ClientIP); err == nil {
			req.Country = &loc.Country
			req.City = &loc.City
		}
	}

	p, err := s.repo.UpdateProfile(ctx, userID, req)
	if err != nil {
		return nil, err
	}
	p.RankTier = ranks.GetRankTierString(p.ReputationScore)
	return p, nil
}

func (s *Service) GetPublicProfile(ctx context.Context, targetUserID string) (*PublicProfileResponse, error) {
	p, err := s.repo.GetProfile(ctx, targetUserID)
	if err != nil {
		return nil, err
	}
	if !p.IsPublic {
		return nil, ErrProfilePrivate
	}

	// Use actual first_name/last_name from database
	// Fall back to splitting display_name only if names are empty
	firstName := p.FirstName
	lastName := p.LastName
	if firstName == "" && lastName == "" && p.DisplayName != "" {
		firstName, lastName = splitDisplayName(p.DisplayName)
	}

	return &PublicProfileResponse{
		UserID:          p.UserID,
		DisplayName:     p.DisplayName,
		FirstName:       firstName,
		LastName:        lastName,
		Bio:             p.Bio,
		AvatarURL:       p.AvatarURL,
		Country:         p.Country,
		City:            p.City,
		ReputationScore: p.ReputationScore,
		RankTier:        ranks.GetRankTierString(p.ReputationScore),
	}, nil
}

// splitDisplayName splits a display name into first and last name
func splitDisplayName(displayName string) (string, string) {
	parts := strings.Fields(displayName)
	if len(parts) == 0 {
		return "", ""
	}
	if len(parts) == 1 {
		return parts[0], ""
	}
	return parts[0], strings.Join(parts[1:], " ")
}

func (s *Service) UploadAvatar(ctx context.Context, userID, filename, contentType string, size int64, reader io.Reader) (*Profile, error) {
	if s.storage == nil {
		return nil, ErrStorageNotConfigured
	}
	if size <= 0 || size > maxAvatarSizeBytes {
		return nil, ErrAvatarTooLarge
	}
	if !isAllowedImageType(contentType) {
		return nil, ErrInvalidAvatarMimeType
	}

	if _, err := s.GetMyProfile(ctx, userID); err != nil {
		return nil, err
	}

	ext := strings.ToLower(path.Ext(filename))
	if ext == "" {
		ext = extFromContentType(contentType)
		if ext == "" {
			return nil, ErrInvalidAvatarMimeType
		}
	}

	// Keep object key bucket-relative; bucket name is added by storage client or passed as "" for default.
	objectName := fmt.Sprintf("%s/%s%s", userID, uuid.NewString(), ext)
	url, err := s.storage.Upload(ctx, "", objectName, reader, size, contentType)
	if err != nil {
		return nil, err
	}

	return s.repo.UpdateAvatarURL(ctx, userID, url)
}

func (s *Service) GetMyStats(ctx context.Context, userID string) (*ProfileStats, error) {
	if _, err := s.GetMyProfile(ctx, userID); err != nil {
		return nil, err
	}

	// Try cache first if available
	if s.cache != nil {
		if stats, err := s.cache.GetStats(ctx, userID); err == nil {
			return stats, nil // Cache HIT
		}
		// Cache MISS or error - continue to DB
	}

	// Query from database
	stats, err := s.repo.GetProfileStats(ctx, userID)
	if err != nil {
		return nil, err
	}

	// Store in cache (fire-and-forget, don't fail on cache errors)
	if s.cache != nil {
		_ = s.cache.SetStats(ctx, userID, stats, 5*time.Minute)
	}

	return stats, nil
}

func (s *Service) GetPublicStats(ctx context.Context, targetUserID string) (*ProfileStats, error) {
	// Check privacy first
	p, err := s.repo.GetProfile(ctx, targetUserID)
	if err != nil {
		return nil, err
	}
	if !p.IsPublic {
		return nil, ErrProfilePrivate
	}

	// Try cache first if available
	if s.cache != nil {
		if stats, err := s.cache.GetStats(ctx, targetUserID); err == nil {
			return stats, nil // Cache HIT
		}
		// Cache MISS or error - continue to DB
	}

	// Query from database
	stats, err := s.repo.GetProfileStats(ctx, targetUserID)
	if err != nil {
		return nil, err
	}

	// Store in cache (fire-and-forget, don't fail on cache errors)
	if s.cache != nil {
		_ = s.cache.SetStats(ctx, targetUserID, stats, 5*time.Minute)
	}

	return stats, nil
}

func (s *Service) DeleteMyProfile(ctx context.Context, userID string) error {
	return s.repo.DeleteProfile(ctx, userID)
}

func (s *Service) AddAlly(ctx context.Context, userID, targetID string) error {
	if userID == targetID {
		return fmt.Errorf("cannot ally self")
	}
	// Verify target exists
	if _, err := s.repo.GetProfile(ctx, targetID); err != nil {
		return err
	}
	return s.repo.AddAlly(ctx, userID, targetID)
}

func (s *Service) RemoveAlly(ctx context.Context, userID, targetID string) error {
	return s.repo.RemoveAlly(ctx, userID, targetID)
}

func (s *Service) GetMyAllies(ctx context.Context, userID string) ([]AllyProfile, error) {
	return s.GetAllies(ctx, userID, "", 20, 0)
}

func (s *Service) GetAllies(ctx context.Context, userID, searchQuery string, limit, offset int) ([]AllyProfile, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 50 {
		limit = 50
	}
	if offset < 0 {
		offset = 0
	}

	allies, err := s.repo.GetAllies(ctx, userID, searchQuery, limit, offset)
	if err != nil {
		return nil, err
	}
	for i := range allies {
		allies[i].RankTier = ranks.GetRankTierString(allies[i].ReputationScore)
	}
	return allies, nil
}

func (s *Service) GetPublicAllies(ctx context.Context, targetUserID, searchQuery string, limit, offset int) ([]AllyProfile, error) {
	// Check if target profile exists and is public
	p, err := s.repo.GetProfile(ctx, targetUserID)
	if err != nil {
		return nil, err
	}
	if !p.IsPublic {
		return nil, ErrProfilePrivate
	}
	return s.GetAllies(ctx, targetUserID, searchQuery, limit, offset)
}

func (s *Service) BlockUser(ctx context.Context, userID, targetID string) error {
	if userID == targetID {
		return fmt.Errorf("cannot block self")
	}
	if _, err := s.repo.GetProfile(ctx, targetID); err != nil {
		return err
	}
	return s.repo.BlockUser(ctx, userID, targetID)
}

func (s *Service) UnblockUser(ctx context.Context, userID, targetID string) error {
	return s.repo.UnblockUser(ctx, userID, targetID)
}

func (s *Service) RestrictUser(ctx context.Context, userID, targetID string) error {
	if userID == targetID {
		return fmt.Errorf("cannot restrict self")
	}
	if _, err := s.repo.GetProfile(ctx, targetID); err != nil {
		return err
	}
	return s.repo.RestrictUser(ctx, userID, targetID)
}

func (s *Service) UnrestrictUser(ctx context.Context, userID, targetID string) error {
	return s.repo.UnrestrictUser(ctx, userID, targetID)
}

func (s *Service) GetRelationshipStatus(ctx context.Context, currentUserID, targetUserID string) (*RelationshipStatus, error) {
	if currentUserID == targetUserID {
		return nil, fmt.Errorf("cannot check relationship with self")
	}
	return s.repo.GetRelationshipStatus(ctx, currentUserID, targetUserID)
}

func (s *Service) ReportUser(ctx context.Context, userID, targetID string, req *ReportRequest) error {
	if userID == targetID {
		return fmt.Errorf("cannot report self")
	}
	if _, err := s.repo.GetProfile(ctx, targetID); err != nil {
		return err
	}

	// Validate reason
	validReasons := map[string]bool{
		"spam": true, "harassment": true, "inappropriate": true, "fake_account": true, "other": true,
	}
	if !validReasons[req.Reason] {
		return fmt.Errorf("invalid_reason")
	}

	return s.repo.ReportUser(ctx, userID, targetID, req)
}

func isAllowedImageType(ct string) bool {
	switch ct {
	case "image/jpeg", "image/png", "image/webp":
		return true
	default:
		return false
	}
}

func extFromContentType(ct string) string {
	switch ct {
	case "image/jpeg":
		return ".jpg"
	case "image/png":
		return ".png"
	case "image/webp":
		return ".webp"
	default:
		return ""
	}
}

// SearchUsers — публичный поиск пользователей по имени/фамилии
func (s *Service) SearchUsers(ctx context.Context, firstName, lastName string, limit int) ([]UserSearchResult, error) {
	firstName = strings.TrimSpace(firstName)
	lastName = strings.TrimSpace(lastName)

	if firstName == "" && lastName == "" {
		return []UserSearchResult{}, nil
	}

	return s.repo.SearchUsersByName(ctx, firstName, lastName, limit)
}

// SearchProfilesForFeed — поиск профилей для домашней страницы с учетом приватности
func (s *Service) SearchProfilesForFeed(ctx context.Context, currentUserID, query string, limit, offset int) ([]ProfileSearchResult, error) {
	query = strings.TrimSpace(query)

	if query == "" {
		return []ProfileSearchResult{}, nil
	}

	results, err := s.repo.SearchProfilesForFeed(ctx, currentUserID, query, limit, offset)
	if err != nil {
		return nil, err
	}

	for i := range results {
		results[i].RankTier = ranks.GetRankTierString(results[i].ReputationScore)
	}

	return results, nil
}
