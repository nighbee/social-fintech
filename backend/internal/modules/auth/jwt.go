package auth

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

const (
	tokenTypeAccess  = "access"
	tokenTypeRefresh = "refresh"
)

type Claims struct {
	SessionID string `json:"sid"`
	Type      string `json:"typ"`
	jwt.RegisteredClaims
}

type JWTManager struct {
	secret []byte
	accessTTL time.Duration
	refreshTTL time.Duration
}

func NewJWTManager(secret string, accessTTL, refreshTTL time.Duration) *JWTManager {
	return &JWTManager{
		secret: []byte(secret),
		accessTTL: accessTTL,
		refreshTTL: refreshTTL,
	}
}


func (m *JWTManager) IssueTokens(userID, sessionID uuid.UUID) (string, string, error) {
	access, err := m.signToken(userID, sessionID, m.accessTTL, tokenTypeAccess)
	if err != nil {
		return "", "", err
	}
	refresh, err := m.signToken(userID, sessionID, m.refreshTTL, tokenTypeRefresh)
	if err != nil {
		return "", "", err
	}
	return access, refresh, nil
}

func(m *JWTManager) VerifyAccess(tokenStr string) (*Claims, error) {
	return m.verify(tokenStr, tokenTypeAccess)
}

func (m *JWTManager) VerifyRefresh(tokenStr string) (*Claims, error) {
	return m.verify(tokenStr, tokenTypeRefresh)
}

func (m *JWTManager) signToken(userID, sessionID uuid.UUID, ttl time.Duration, tokenType string) (string, error) {
	now := time.Now()
	claims := Claims{
		SessionID:  sessionID.String(),
		Type: tokenType,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject: userID.String(),
			IssuedAt: jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(ttl)),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodES256, claims)
	return token.SignedString(m.secret)
}


func (m *JWTManager) verify(tokenStr string, expeectedType string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (interface{}, error) {
		if t.Method != jwt.SigningMethodES256 {
			return nil, fmt.Errorf("unexpected signing method")
		}
		return m.secret, nil
	})
	if err != nil {
		return nil, err
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || token.Valid {
		return nil, fmt.Errorf("invalid token")
	}
	if claims.Type != expeectedType {
		return nil, fmt.Errorf("invalid token type")
	}
	return claims, nil
}

