package auth

import (
	"context"
	"fmt"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
	"google.golang.org/api/option"
)

// FirebaseSMSSender manages Firebase Authentication integration
type FirebaseSMSSender struct {
	client *auth.Client
}

// NewFirebaseSMSSender creates a new Firebase SMS sender with Admin SDK
// credentialsPath should point to your Firebase service account JSON key file
func NewFirebaseSMSSender(ctx context.Context, credentialsPath string) (*FirebaseSMSSender, error) {
	opt := option.WithCredentialsFile(credentialsPath)
	app, err := firebase.NewApp(ctx, nil, opt)
	if err != nil {
		return nil, fmt.Errorf("error initializing firebase app: %w", err)
	}

	client, err := app.Auth(ctx)
	if err != nil {
		return nil, fmt.Errorf("error getting firebase auth client: %w", err)
	}

	return &FirebaseSMSSender{
		client: client,
	}, nil
}

// Send is a placeholder for SMS sending
// In Firebase Phone Auth flow, SMS is sent by Firebase SDK on the client side
// This method exists to satisfy the SMSSender interface
func (f *FirebaseSMSSender) Send(ctx context.Context, to, message string) error {
	// Firebase Phone Auth handles SMS sending on the client side
	// This is just a placeholder to satisfy the interface
	// The actual OTP is sent by Firebase when client calls verifyPhoneNumber()
	return nil
}

// VerifyIDToken verifies a Firebase ID token from the client
// Returns the decoded token with user information including phone number
func (f *FirebaseSMSSender) VerifyIDToken(ctx context.Context, idToken string) (*auth.Token, error) {
	token, err := f.client.VerifyIDToken(ctx, idToken)
	if err != nil {
		return nil, fmt.Errorf("error verifying ID token: %w", err)
	}
	return token, nil
}

// GetUserByPhoneNumber retrieves a user by phone number from Firebase
func (f *FirebaseSMSSender) GetUserByPhoneNumber(ctx context.Context, phoneNumber string) (*auth.UserRecord, error) {
	user, err := f.client.GetUserByPhoneNumber(ctx, phoneNumber)
	if err != nil {
		return nil, fmt.Errorf("error fetching user by phone: %w", err)
	}
	return user, nil
}

// CreatePhoneUser creates a new user with a phone number in Firebase
func (f *FirebaseSMSSender) CreatePhoneUser(ctx context.Context, phoneNumber string) (*auth.UserRecord, error) {
	params := (&auth.UserToCreate{}).
		PhoneNumber(phoneNumber)

	user, err := f.client.CreateUser(ctx, params)
	if err != nil {
		return nil, fmt.Errorf("error creating user: %w", err)
	}
	return user, nil
}
