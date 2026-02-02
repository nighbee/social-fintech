package profiles

import "context"

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
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
