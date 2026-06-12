package settings

import (
	"context"
	"strings"
	"time"

	"github.com/brightbund-backend/internal/modules/auth"
)

type AuthAdapter interface {
	CountActiveSessions(ctx context.Context, userID string) (int, error)
	ListSessions(ctx context.Context, userID string) ([]SessionItem, error)
	RevokeSession(ctx context.Context, userID, sessionID string, revokedAt time.Time) error
	RevokeAllSessionsExcept(ctx context.Context, userID, currentSessionID string, revokedAt time.Time) error
	RevokeAllSessions(ctx context.Context, userID string, revokedAt time.Time) error
	GetUserPasswordHash(ctx context.Context, userID string) (string, error)
	UpdateUserPasswordHash(ctx context.Context, userID, passwordHash string, updatedAt time.Time) error
	GetUserPhone(ctx context.Context, userID string) (string, string, error)
	UsernameExists(ctx context.Context, username string) (bool, error)
}

type authRepositoryAdapter struct {
	repo auth.Repository
}

func NewAuthAdapter(repo auth.Repository) AuthAdapter {
	if repo == nil {
		return nil
	}
	return &authRepositoryAdapter{repo: repo}
}

func (a *authRepositoryAdapter) CountActiveSessions(ctx context.Context, userID string) (int, error) {
	return a.repo.CountActiveSessionsByUser(ctx, userID)
}

func (a *authRepositoryAdapter) ListSessions(ctx context.Context, userID string) ([]SessionItem, error) {
	sessions, err := a.repo.ListActiveSessionsByUser(ctx, userID)
	if err != nil {
		return nil, err
	}

	items := make([]SessionItem, 0, len(sessions))
	for _, session := range sessions {
		osName := "unknown"
		agent := strings.ToLower(session.UserAgent)
		switch {
		case strings.Contains(agent, "android"):
			osName = "android"
		case strings.Contains(agent, "ios"), strings.Contains(agent, "iphone"), strings.Contains(agent, "ipad"):
			osName = "ios"
		case strings.Contains(agent, "windows"):
			osName = "windows"
		case strings.Contains(agent, "mac"):
			osName = "macos"
		case strings.Contains(agent, "linux"):
			osName = "linux"
		}

		deviceName := session.DeviceID
		if deviceName == "" {
			deviceName = "Unknown device"
		}

		items = append(items, SessionItem{
			ID:           session.ID,
			DeviceName:   deviceName,
			OS:           osName,
			IP:           session.IP,
			LastActiveAt: session.LastActiveAt,
		})
	}

	return items, nil
}

func (a *authRepositoryAdapter) RevokeSession(ctx context.Context, userID, sessionID string, revokedAt time.Time) error {
	return a.repo.RevokeSessionForUser(ctx, userID, sessionID, revokedAt)
}

func (a *authRepositoryAdapter) RevokeAllSessionsExcept(ctx context.Context, userID, currentSessionID string, revokedAt time.Time) error {
	return a.repo.RevokeAllSessionsExceptForUser(ctx, userID, currentSessionID, revokedAt)
}

func (a *authRepositoryAdapter) RevokeAllSessions(ctx context.Context, userID string, revokedAt time.Time) error {
	return a.repo.RevokeAllSessionsForUser(ctx, userID, revokedAt)
}

func (a *authRepositoryAdapter) GetUserPasswordHash(ctx context.Context, userID string) (string, error) {
	return a.repo.GetUserPasswordHashByID(ctx, userID)
}

func (a *authRepositoryAdapter) UpdateUserPasswordHash(ctx context.Context, userID, passwordHash string, updatedAt time.Time) error {
	return a.repo.UpdateUserPasswordHashByID(ctx, userID, passwordHash, updatedAt)
}

func (a *authRepositoryAdapter) GetUserPhone(ctx context.Context, userID string) (string, string, error) {
	return a.repo.GetUserPhoneByID(ctx, userID)
}

func (a *authRepositoryAdapter) UsernameExists(ctx context.Context, username string) (bool, error) {
	return a.repo.UsernameExists(ctx, username)
}
