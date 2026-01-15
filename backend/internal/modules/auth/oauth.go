package auth

import (
	"context"
	"fmt"

	"github.com/coreos/go-oidc/v3/oidc"
)


// базовая верификация для OAuth
type ProviderType string

const (
	ProviderApple  ProviderType = "apple"
	ProviderGoogle ProviderType = "google"
)

type ProviderUser struct {
	Provider ProviderType
	Subject  string
	Email    string
	Name     string
}

type OAuthVerifier interface {
	Verify(ctx context.Context, idToken string) (*ProviderUser, error)
}

type OIDCVerifier struct {
	provider ProviderType
	verifier *oidc.IDTokenVerifier
}

func NewOIDCVerifier(provider ProviderType, issuer, clienID string) (*OIDCVerifier, error) {
	ctx := context.Background()
	oidcProvider, err := oidc.NewProvider(ctx, issuer)
	if err != nil {
		return nil, fmt.Errorf("oidc discovery failed: %w", err)
	}

	verifier := oidcProvider.Verifier(&oidc.Config{
		ClientID: clienID,
	})
	return &OIDCVerifier{
		provider: provider,
		verifier: verifier,
	}, nil
}

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
		Subject: sub,
		Email: email,
		Name: name,
	}, nil
}