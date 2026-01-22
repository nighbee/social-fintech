# Firebase Phone Authentication Setup Guide

## Overview

This guide explains how to set up Firebase Phone Authentication for SMS OTP in the BrightBund backend.

## Important Note About Firebase Phone Auth

**Firebase Phone Authentication works differently than our current implementation:**

1. **Client-Side Approach (Recommended):**
   - Client app uses Firebase Auth SDK directly
   - Firebase handles OTP generation and SMS sending automatically
   - User enters OTP in client app
   - Client verifies with Firebase and gets an ID token
   - Client sends Firebase ID token to your backend
   - Backend verifies the token using Firebase Admin SDK

2. **Custom Backend Approach (Current Implementation):**
   - Backend generates OTP codes
   - Backend needs an SMS service to send codes
   - Firebase Admin SDK doesn't directly send SMS for custom OTP flows
   - You would need to integrate Twilio, AWS SNS, or similar services

## Setup Steps for Client-Side Firebase Auth (Recommended)

### 1. Create or Select Firebase Project

```bash
# List existing projects
firebase projects:list

# Create new project (if needed)
firebase projects:create brightbund-app --display-name "BrightBund"

# Or use the Firebase MCP to create a project
```

### 2. Enable Phone Authentication in Firebase Console

1. Go to https://console.firebase.google.com
2. Select your project (or create new one)
3. Navigate to **Authentication** → **Sign-in method**
4. Enable **Phone** provider
5. Configure your authorized domains

### 3. Download Service Account Key

1. Go to **Project Settings** → **Service Accounts**
2. Click **Generate New Private Key**
3. Save the JSON file as `firebase-service-account.json`
4. **IMPORTANT:** Add this file to `.gitignore`

```bash
# Add to .gitignore
echo "backend/firebase-service-account.json" >> .gitignore
```

### 4. Configure Backend

Place the service account JSON file in your backend directory:

```bash
cd backend/
# Copy your downloaded JSON file here
cp ~/Downloads/brightbund-xxxxx-firebase-adminsdk-xxxxx.json firebase-service-account.json
```

Update `config.yaml` or set environment variables:

```yaml
firebase:
  enabled: true
  credentials_path: ./firebase-service-account.json
  project_id: your-firebase-project-id
```

Or use environment variables:

```bash
export FIREBASE_ENABLED=true
export FIREBASE_CREDENTIALS_PATH=/path/to/firebase-service-account.json
export FIREBASE_PROJECT_ID=your-firebase-project-id
```

### 5. Update Client-Side Implementation

Your mobile app (Flutter) should use Firebase Auth SDK:

```dart
// In your Flutter app
import 'package:firebase_auth/firebase_auth.dart';

Future<void> verifyPhoneNumber(String phoneNumber) async {
  await FirebaseAuth.instance.verifyPhoneNumber(
    phoneNumber: phoneNumber,
    verificationCompleted: (PhoneAuthCredential credential) async {
      // Auto-verification completed
      await FirebaseAuth.instance.signInWithCredential(credential);
    },
    verificationFailed: (FirebaseAuthException e) {
      // Handle error
    },
    codeSent: (String verificationId, int? resendToken) {
      // SMS sent - show OTP input screen
    },
    codeAutoRetrievalTimeout: (String verificationId) {
      // Auto-retrieval timeout
    },
  );
}

Future<String> getIdToken() async {
  User? user = FirebaseAuth.instance.currentUser;
  return await user?.getIdToken() ?? '';
}
```

### 6. Update Backend to Verify Firebase Tokens

Add a new endpoint to verify Firebase ID tokens:

```go
// POST /auth/firebase-phone-verify
func (h *Handler) VerifyFirebasePhone(c *fiber.Ctx) error {
    var req struct {
        IDToken string `json:"id_token"`
        DeviceID string `json:"device_id"`
        UserAgent string `json:"user_agent"`
        AppVersion string `json:"app_version"`
    }
    
    if err := c.BodyParser(&req); err != nil {
        return c.Status(400).JSON(fiber.Map{"error": "invalid_body"})
    }
    
    // Verify Firebase token
    token, err := h.service.firebaseSender.VerifyIDToken(c.Context(), req.IDToken)
    if err != nil {
        return c.Status(401).JSON(fiber.Map{"error": "invalid_token"})
    }
    
    // Extract phone number from token
    phoneNumber := token.Claims["phone_number"].(string)
    
    // Create or login user with phone number
    // ... rest of your auth logic
}
```

## Alternative: Use SMS Service for Custom OTP

If you want to keep the current OTP generation logic, integrate an SMS service:

### Option A: Twilio

```go
// Create TwilioSMSSender
type TwilioSMSSender struct {
    accountSID string
    authToken  string
    fromNumber string
}

func (t *TwilioSMSSender) Send(ctx context.Context, to, message string) error {
    // Use Twilio SDK or REST API
}
```

### Option B: AWS SNS

```go
// Create SNSSMSSender
type SNSSMSSender struct {
    client *sns.Client
}

func (s *SNSSMSSender) Send(ctx context.Context, to, message string) error {
    // Use AWS SNS SDK
}
```

## Current Implementation Status

- ✅ Firebase Admin SDK installed
- ✅ Configuration structure added
- ✅ Conditional SMS sender initialization
- ✅ Development mode (NoopSMSSender) still available
- ⚠️  Firebase SMS sending requires client-side integration
- ⚠️  Service account key needs to be generated and configured

## Testing

### Development Mode (No SMS)

OTP codes are logged to console:

```
sms_placeholder to=+15551234567 msg=Your BrightBund code is 1234
```

### Production Mode (Firebase)

1. Set `firebase.enabled: true` in config
2. Add service account JSON file
3. Client must use Firebase Auth SDK
4. Backend verifies Firebase ID tokens

## Security Notes

- ⚠️ **Never commit** `firebase-service-account.json` to git
- ⚠️ Use environment variables for sensitive config in production
- ⚠️ Rotate service account keys periodically
- ⚠️ Set up proper Firebase security rules
- ⚠️ Configure rate limiting for phone auth endpoints

## Resources

- [Firebase Phone Auth Documentation](https://firebase.google.com/docs/auth/web/phone-auth)
- [Firebase Admin SDK Go](https://firebase.google.com/docs/admin/setup#go)
- [Flutter Firebase Auth](https://firebase.flutter.dev/docs/auth/phone/)
