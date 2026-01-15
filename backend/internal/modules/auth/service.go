package auth

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
)

//Слой сервиса так же включает в себя репо + jwt и верификация логина рефреша и логаута

type Service struct {
	repo      Repository
	jwt       *JWTManager
	verifiers map[ProviderType]OAuthVerifier
}

func NewService(repo Repository, jwt *JWTManager, verifiers map[ProviderType]OAuthVerifier) *Service {
	return &Service{
		repo:      repo,
		jwt:       jwt,
		verifiers: verifiers,
	}
}

func (s *Service) Login(ctx context.Context, req LoginRequest, ip string) (*LoginResponse, error) {
	verifier := s.verifiers[req.ProviderType]
	if verifier == nil {
		return nil, fmt.Errorf("unsopptedte provider")
	}

	providerUser, err := verifier.Verify(ctx, req.ProviderToken)
	if err != nil {
		return nil, ErrInvalidProviderToken
	}

	user, err := s.repo.GetUserByIdentity(ctx, string(providerUser.Provider), providerUser.Subject)
	if err != nil && IsNotFound(err){
		return nil, err
	}

	if user == nil {
		if providerUser.Email == "" {
			return nil, ErrEmailRequired
		}

		existing, err := s.repo.GetUserByEmail(ctx, providerUser.Email)
		if err != nil && !IsNotFound(err) {
			return nil, err
		}

		if existing != nil {
			user = existing
			identity := &Identity{
				UserID: user.ID,
				Provider: string(providerUser.Provider),
				Subject: providerUser.Subject,
				Email: providerUser.Email,
				CreatedAt: time.Now(),
			}
			if err := s.repo.CreateIdentity(ctx, identity); err != nil {
				return nil, err
			}
		} else {
			username, err := s.generateUniqueUsername(ctx, providerUser.Email)
			if err != nil {
				return nil, err
			}


			now := time.Now()
			user = &User{
				ID: uuid.NewString(),
				Email: providerUser.Email,
				Username: username,
				AvatarURL: "",
				IsShadowBanned: false,
				CreatedAt: now,
				UpdatedAt: now,
				LastActiveAt: now,
			}
			if err := s.repo.CreateUser(ctx, user); err != nil {
				return nil, err
			}
			identity := &Identity{
				UserID: user.ID,
				Provider: string(providerUser.Provider),
				Subject: providerUser.Subject,
				Email: providerUser.Email,
				CreatedAt: time.Now(),
			}
			if err := s.repo.CreateIdentity(ctx, identity); err != nil {
				return nil, err
			}
		}
	}

	session := &Session{
		ID: uuid.NewString(),
		UserID: user.ID,
		DeviceID: req.DeviceID,
		IP: ip,
		LastActiveAt: time.Now(),
		CreatedAt: time.Now(),
	}
	if err := s.repo.CreateSession(ctx, session); err != nil {
		return nil, err
	}

	access, refresh, err := s.jwt.IssueTokens(uuid.MustParse(user.ID), uuid.MustParse(session.ID))
	if err != nil {
		return nil, err
	}

	return &LoginResponse{
		AccessToken: access,
		RefreshToken: refresh,
		User: *user,
	}, nil
}

func (s *Service) Refresh(ctx context.Context, refreshToken string) (*LoginResponse, error) {
	claims, err := s.jwt.VerifyRefresh(refreshToken)

	if err != nil {
		return nil, err
	}

	session, err := s.repo.GetSessionByID(ctx, claims.SessionID)
	

	if err != nil {
		return nil, ErrSessionNotFound
	}

	user := &User{ID: session.UserID}
	access, refresh, err := s.jwt.IssueTokens(uuid.MustParse(user.ID), uuid.MustParse(session.ID))
	if err != nil {
		return nil, err
	}

	return &LoginResponse{
		AccessToken: access,
		RefreshToken: refresh,
		User: *user,
	}, nil
}

func (s *Service) Logout(ctx context.Context, sessionID string) error {
	return s.repo.DeleteSession(ctx, sessionID)
}

func (s *Service) generateUniqueUsername(ctx context.Context, email string) (string, error) {
	base := strings.Split(email, "@")[0]
	base = cleanUsername(base)
	username := base

	// чуть детское решение для генерации рандомных, число 20 символично поставил
	for i := 0; i < 20; i++ {
		exists, err := s.repo.UsernameExists(ctx, username)
		if err != nil {
			return "", err
		}
		if !exists {
			return username, nil
		}
		username = fmt.Sprint("%s%d", base, i+1)
	}

	return "", fmt.Errorf("unable to gen")
}

func cleanUsername(s string) string {
	s = strings.ToLower(s)
	s = strings.ReplaceAll(s, ".", "_")
	s = strings.ReplaceAll(s, "-", "_")
	s = strings.TrimSpace(s)
	if s == "" {
		return "user"
	}
	return s
}