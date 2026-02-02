package profiles

import (
	"context"
	"fmt"
	"io"
	"path"
	"strings"

	"github.com/google/uuid"
)

type ObjectStorage interface {
	Upload(ctx context.Context, objectName string, reader io.Reader, size int64, contentType string) (string, error)
}

type Service struct {
	repo    *Repository
	storage ObjectStorage
}

const maxAvatarSizeBytes = 5 * 1024 * 1024 // 5MB

func NewService(repo *Repository, storage ObjectStorage) *Service {
	return &Service{repo: repo, storage: storage}
}

func (s *Service) GetMyProfile(ctx context.Context, userID string) (*Profile, error) {
	p, err := s.repo.GetProfile(ctx, userID)
	if err == ErrProfileNotFound {
		return s.repo.CreateDefaultProfile(ctx, userID)
	}
	return p, err
}

func (s *Service) UpdateMyProfile(ctx context.Context, userID string, req *UpdateProfileRequest) (*Profile, error) {
	_, err := s.repo.GetProfile(ctx, userID)
	if err == ErrProfileNotFound {
		if _, err := s.repo.CreateDefaultProfile(ctx, userID); err != nil {
			return nil, err
		}
	}
	return s.repo.UpdateProfile(ctx, userID, req)
}

func (s *Service) GetPublicProfile(ctx context.Context, targetUserID string) (*PublicProfileResponse, error) {
	p, err := s.repo.GetProfile(ctx, targetUserID)
	if err != nil {
		return nil, err
	}
	if !p.IsPublic {
		return nil, ErrProfilePrivate
	}
	return &PublicProfileResponse{
		UserID:    p.UserID,
		FirstName: p.FirstName,
		LastName:  p.LastName,
		Bio:       p.Bio,
		AvatarURL: p.AvatarURL,
		Country:   p.Country,
		Region:    p.Region,
		City:      p.City,
	}, nil
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
