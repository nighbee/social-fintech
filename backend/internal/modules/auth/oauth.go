package auth

import (
	"context"
	"fmt"

	"github.com/coreos/go-oidc/v3/oidc"
)

//для понимания провайдера входа
type ProviderType string

const (
	ProviderApple  ProviderType = "apple"
	ProviderGoogle ProviderType = "google"
	ProviderEmail  ProviderType = "email"
	ProviderPhone  ProviderType = "phone"
)

// нормализованные данные с токена
type ProviderUser struct {
	Provider ProviderType
	Subject  string
	Email    string
	Name     string
}

//всего одна функция интерфейса для верификации
type OAuthVerifier interface {
	Verify(ctx context.Context, idToken string) (*ProviderUser, error)
}

// OIDC проверка для Apple/Google
type OIDCVerifier struct {
	provider ProviderType
	verifier *oidc.IDTokenVerifier
}


//инициализация именно oauth с client_id
func NewOIDCVerifier(provider ProviderType, issuer, clientID string) (*OIDCVerifier, error) {
	ctx := context.Background()
	oidcProvider, err := oidc.NewProvider(ctx, issuer)
	if err != nil {
		return nil, fmt.Errorf("oidc discovery failed: %w", err)
	}

	verifier := oidcProvider.Verifier(&oidc.Config{
		ClientID: clientID,
	})
	return &OIDCVerifier{
		provider: provider,
		verifier: verifier,
	}, nil
}


// валидирует айди токен и вытаскивает claims
func (v *OIDCVerifier) Verify(ctx context.Context, idToken string) (*ProviderUser, error) {
	token, err := v.verifier.Verify(ctx, idToken)
	if err != nil {
		return nil, fmt.Errorf("token verify failed: %w", err)
	}

	claims := map[string]interface{}{}
	if err := token.Claims(&claims); err != nil {
		return nil, fmt.Errorf("token claims parse failed: %w", err)
	}

	sub, _ := claims["sub"].(string)
	email, _ := claims["email"].(string)
	name, _ := claims["name"].(string)

	if sub == "" {
		return nil, fmt.Errorf("missing subject")
	}

	return &ProviderUser{
		Provider: v.provider,
		Subject:  sub,
		Email:    email,
		Name:     name,
	}, nil
}
