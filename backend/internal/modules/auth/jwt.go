package auth

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// JWT claims for access/refresh tokens.

const (
	tokenTypeAccess  = "access"
	tokenTypeRefresh = "refresh"
)

// jwt claims с типом токена и айди сессии
type Claims struct {
	SessionID string `json:"sid"`
	Type      string `json:"typ"`
	jwt.RegisteredClaims
}

// создании токена и рефреша
type JWTManager struct {
	secret     []byte
	accessTTL  time.Duration
	refreshTTL time.Duration
}


//конструктор для секрета и ттл
func NewJWTManager(secret string, accessTTL, refreshTTL time.Duration) *JWTManager {
	return &JWTManager{
		secret:     []byte(secret),
		accessTTL:  accessTTL,
		refreshTTL: refreshTTL,
	}
}


// генерит аксесс + рефреш и рефреш айди
func (m *JWTManager) IssueTokens(userID, sessionID uuid.UUID) (string, string, string, error) {
	refreshID := uuid.NewString()

	access, err := m.signToken(userID, sessionID, m.accessTTL, tokenTypeAccess, "")
	if err != nil {
		return "", "", "", err
	}
	refresh, err := m.signToken(userID, sessionID, m.refreshTTL, tokenTypeRefresh, refreshID)
	if err != nil {
		return "", "", "", err
	}
	return access, refresh, refreshID, nil
}

// для проверки токенов
func (m *JWTManager) VerifyAccess(tokenStr string) (*Claims, error) {
	return m.verify(tokenStr, tokenTypeAccess)
}

func (m *JWTManager) VerifyRefresh(tokenStr string) (*Claims, error) {
	return m.verify(tokenStr, tokenTypeRefresh)
}


// сборка и подпись токена в hs256
func (m *JWTManager) signToken(userID, sessionID uuid.UUID, ttl time.Duration, tokenType, refreshID string) (string, error) {
	now := time.Now()
	claims := Claims{
		SessionID: sessionID.String(),
		Type:      tokenType,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID.String(),
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(ttl)),
			ID: refreshID,
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(m.secret)
}


// валидация подписи
func (m *JWTManager) verify(tokenStr string, expectedType string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (interface{}, error) {
		if t.Method != jwt.SigningMethodHS256 {
			return nil, fmt.Errorf("unexpected signing method")
		}
		return m.secret, nil
	})
	if err != nil {
		return nil, err
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, fmt.Errorf("invalid token")
	}
	if claims.Type != expectedType {
		return nil, fmt.Errorf("invalid token type")
	}
	return claims, nil
}

//sha256 хеш рефреш для хранения в бд
func HashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}
