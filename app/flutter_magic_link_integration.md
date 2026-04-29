# Flutter Developer Integration Guide: Firebase Magic Links

This guide outlines the exact steps and API payloads the Flutter developer needs to implement to integrate the new Firebase Email Authentication (Magic Link) flow with the BrightBund Go backend.

## 1. Firebase Setup & Deep Linking
To make Magic Links work, the app needs to be able to catch the URL when the user clicks it in their email client.

- [ ] **Configure Firebase Hosting / Dynamic Links:** Ensure that your Firebase project has an authorized domain configured for email link authentication.
- [ ] **Setup App Links (Android) / Universal Links (iOS):** Configure the `AndroidManifest.xml` and `Runner.entitlements` to intercept the specific domain used for the Magic Link.
- [ ] **Listen for Deep Links:** Use the `firebase_dynamic_links` or `app_links` package in Flutter to listen for incoming deep links when the app is resumed or opened from a terminated state.

## 2. Triggering the Magic Link
When the user enters their email address and taps "Send Link":

- [ ] **Call Firebase Auth:** Use `FirebaseAuth.instance.sendSignInLinkToEmail()`.
- [ ] **ActionCodeSettings:** Pass the `ActionCodeSettings` ensuring `url` points to your deep link domain, `handleCodeInApp` is `true`, and both `iOSBundleId` and `androidPackageName` are correctly set.
- [ ] **Save Email Locally:** You *must* save the email address locally (e.g., using `shared_preferences`) because you will need it again when the user clicks the link to complete the sign-in.

## 3. Completing the Sign-In via Firebase
When the app catches the deep link:

- [ ] **Verify Link:** Check if the link is a sign-in link using `FirebaseAuth.instance.isSignInWithEmailLink(link)`.
- [ ] **Retrieve Saved Email:** Fetch the email address you saved in Step 2. (If missing, prompt the user to type it in again).
- [ ] **Sign In:** Call `FirebaseAuth.instance.signInWithEmailLink(email: email, emailLink: link)`.
- [ ] **Extract Token:** If successful, extract the Firebase ID Token:
  ```dart
  final user = FirebaseAuth.instance.currentUser;
  final idToken = await user?.getIdToken();
  ```

## 4. Authenticating with the BrightBund Backend
Once you have the `idToken`, you need to exchange it for a BrightBund JWT Session.

### Scenario A: Login (Existing User)
Try to log the user in first. 

- [ ] **Endpoint:** `POST /auth/firebase-email-login`
- [ ] **Payload:**
  ```json
  {
    "firebase_id_token": "eyJhb...",
    "device_id": "unique-device-uuid",
    "user_agent": "Dart/3.1 (iOS 17.0)",
    "app_version": "1.0.0"
  }
  ```
- **Handling Responses:**
  - `200 OK`: Success! Save the `access_token` and `refresh_token` and route to the main app feed.
  - `404 Not Found`: The user does not exist in our database. **Proceed to Scenario B (Registration).**
  - `400 Bad Request` (`error: invalid_email_domain`): The user tried to use a disposable or unsupported email provider. Show an error indicating they must use a supported provider (e.g., Gmail, Yahoo, iCloud).

### Scenario B: Registration (New User)
If the login endpoint returns a `404`, route the user to an onboarding screen to collect their profile details.

- [ ] **Collect Details:** Ask for First Name, Last Name, and Date of Birth.
- [ ] **Endpoint:** `POST /auth/firebase-email-register`
- [ ] **Payload:**
  ```json
  {
    "firebase_id_token": "eyJhb...",
    "first_name": "John",
    "last_name": "Doe",
    "date_of_birth": "1995-08-24",
    "referrer_user_id": "optional-referral-code",
    "device_id": "unique-device-uuid",
    "user_agent": "Dart/3.1 (iOS 17.0)",
    "app_version": "1.0.0"
  }
  ```
- **Handling Responses:**
  - `200 OK`: Success! Save tokens and route to the main app feed.
  - `400 Bad Request` (`error: invalid_email_domain`): The user tried to use a disposable or unsupported email provider. Show an error.

## 5. Security & Rate Limiting Guidelines
- [ ] Ensure the UI handles `429 Too Many Requests` gracefully if the user tries to request too many links or hits the registration endpoint too frequently.
- [ ] Implement a heartbeat animation or subtle UI cue when handling `INSUFFICIENT_FUNDS` or rate limits, rather than disruptive popups (as per BrightBund's Anti-Abuse mandates).
