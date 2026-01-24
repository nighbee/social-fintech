package auth

import (
	"context"
	"fmt"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
	"google.golang.org/api/option"
)

// FirebaseSMSSender sends OTP via Firebase Auth
type FirebaseSMSSender struct {
	client *auth.Client
}

// NewFirebaseSMSSender creates a new Firebase SMS sender
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

// Send sends an OTP code via Firebase
// Note: Firebase handles the actual SMS sending through their infrastructure
// The 'to' parameter should be in format: +[country_code][phone_number]
// The 'message' parameter is ignored as Firebase generates its own message
func (f *FirebaseSMSSender) Send(ctx context.Context, to, message string) error {
	// Firebase Auth doesn't provide a direct API to send custom SMS with custom messages
	// Instead, it handles the entire phone auth flow through their SDK
	// For production use, you have two options:
	//
	// Option 1: Use Firebase Auth on client-side
	//   - Client uses Firebase Auth SDK to send OTP
	//   - Firebase sends SMS automatically
	//   - Client verifies OTP with Firebase
	//   - Client sends Firebase ID token to your backend
	//   - Your backend verifies the Firebase token
	//
	// Option 2: Use a dedicated SMS service (Twilio, AWS SNS, etc.)
	//   - Keep your current OTP generation logic
	//   - Use SMS service to send the actual message

	// For now, we'll implement a verification helper
	// This is a placeholder that shows how to verify a phone number exists
	// You'll need to integrate with client-side Firebase Auth for full functionality

	return fmt.Errorf("firebase SMS sending requires client-side Firebase Auth SDK integration")
}

// VerifyIDToken verifies a Firebase ID token from the client
// This is useful if your client app uses Firebase Auth SDK
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
