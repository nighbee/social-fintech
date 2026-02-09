package profiles

import (
	"context"
	"fmt"
	"io"
	"path"
	"strings"

	"github.com/brightbund-backend/internal/platform/geolocation"
	"github.com/google/uuid"
)

type ObjectStorage interface {
	Upload(ctx context.Context, objectName string, reader io.Reader, size int64, contentType string) (string, error)
}

type Service struct {
	repo       *Repository
	storage    ObjectStorage
	geolocator geolocation.Service
}

// LocationInput represents optional location override from client
type LocationInput struct {
	Country string
	Region  string
	City    string
	IP      string // Client IP for geolocation
}

const maxAvatarSizeBytes = 5 * 1024 * 1024 // 5MB

func NewService(repo *Repository, storage ObjectStorage) *Service {
	return &Service{
		repo:       repo,
		storage:    storage,
		geolocator: geolocation.NewIPAPIClient(),
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
	p.RankTier = calculateRank(p.ReputationScore)
	return p, nil
}

func (s *Service) UpdateMyProfile(ctx context.Context, userID string, req *UpdateProfileRequest) (*Profile, error) {
	_, err := s.repo.GetProfile(ctx, userID)
	if err == ErrProfileNotFound {
		if _, err := s.repo.CreateDefaultProfile(ctx, userID); err != nil {
			return nil, err
		}
	}

	// Auto-populate location if not provided and IP is available
	if req.ClientIP != "" && req.Country == "" && req.City == "" {
		if loc, err := s.geolocator.GetLocationByIP(ctx, req.ClientIP); err == nil {
			req.Country = loc.Country
			req.City = loc.City
		}
		// Silently ignore geolocation errors - user can still update other fields
	}

	p, err := s.repo.UpdateProfile(ctx, userID, req)
	if err != nil {
		return nil, err
	}
	p.RankTier = calculateRank(p.ReputationScore)
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

	// Split display_name into first/last for backwards compatibility
	firstName, lastName := splitDisplayName(p.DisplayName)

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
		RankTier:        calculateRank(p.ReputationScore),
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

	objectName := fmt.Sprintf("avatars/%s/%s%s", userID, uuid.NewString(), ext)
	url, err := s.storage.Upload(ctx, objectName, reader, size, contentType)
	if err != nil {
		return nil, err
	}

	return s.repo.UpdateAvatarURL(ctx, userID, url)
}

func (s *Service) GetMyStats(ctx context.Context, userID string) (*ProfileStats, error) {
	if _, err := s.GetMyProfile(ctx, userID); err != nil {
		return nil, err
	}
	return s.repo.GetProfileStats(ctx, userID)
}

func (s *Service) GetPublicStats(ctx context.Context, targetUserID string) (*ProfileStats, error) {
	p, err := s.repo.GetProfile(ctx, targetUserID)
	if err != nil {
		return nil, err
	}
	if !p.IsPublic {
		return nil, ErrProfilePrivate
	}
	return s.repo.GetProfileStats(ctx, targetUserID)
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

func (s *Service) GetAllies(ctx context.Context, userID string) ([]AllyProfile, error) {
	allies, err := s.repo.GetAllies(ctx, userID)
	if err != nil {
		return nil, err
	}
	// Compute ranks
	for i := range allies {
		allies[i].RankTier = calculateRank(allies[i].ReputationScore)
	}
	return allies, nil
}

func (s *Service) BlockUser(ctx context.Context, userID, targetID string) error {
	if userID == targetID {
		return fmt.Errorf("cannot block self")
	}
	if _, err := s.repo.GetProfile(ctx, targetID); err != nil {
		return err
	}
	// Logic decision: Should blocking also remove 'ally' relationship? usually yes.
	// For MVP, valid just to add block record.
	// Often application level checks "if blocked, don't show posts".
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

func calculateRank(score int) string {
	var rank, quality string

	switch {
	case score >= 5000:
		rank = "Sovereign"
		quality = "Sovereign"
	case score >= 2500:
		rank = "Supernova"
		quality = "Transcendence"
	case score >= 1000:
		rank = "Ruby"
		quality = "Fortitude"
	case score >= 500:
		rank = "Sapphire"
		quality = "Ascendance"
	case score >= 250:
		rank = "Emerald"
		quality = "Integrity"
	case score >= 100:
		rank = "Moonstone"
		quality = "Clarity"
	default:
		rank = "Quartz"
		quality = "Origin"
	}

	return fmt.Sprintf("%s · %s", rank, quality)
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
