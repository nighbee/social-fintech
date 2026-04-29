package settings

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"golang.org/x/crypto/bcrypt"
)

type testRepo struct {
	getUserPasswordHashFn    func(ctx context.Context, userID string) (string, error)
	updateUserPasswordHashFn func(ctx context.Context, userID, passwordHash string, updatedAt time.Time) error
	revokeAllExceptFn        func(ctx context.Context, userID, currentSessionID string, revokedAt time.Time) error
	getActiveTwoFAMethodsFn  func(ctx context.Context, userID string) ([]TwoFAMethod, error)
	upsertTwoFAMethodFn      func(ctx context.Context, userID, method string, isActive bool, secret *string) error
	getUserPhoneFn           func(ctx context.Context, userID string) (string, string, error)
	createDeleteRequestFn    func(ctx context.Context, userID, reason, verificationMethod string) (string, error)
	setDeleteOTPCodeHashFn   func(ctx context.Context, requestID, otpCodeHash string) error
	getLatestDeleteReqFn     func(ctx context.Context, userID string) (*deleteAccountRequest, error)
	setDeleteVerificationFn  func(ctx context.Context, requestID, token string, expiresAt time.Time) error
	markDeleteVerifiedFn     func(ctx context.Context, requestID string, verifiedAt time.Time) error
	updateFeedLimitFn        func(ctx context.Context, userID string, pending int, applyAt time.Time) error
	applyDueFeedLimitsFn     func(ctx context.Context, now time.Time) error
	listDueHardDeleteUserIDs func(ctx context.Context, now time.Time, limit int) ([]string, error)
	hardDeleteUserFn         func(ctx context.Context, userID string) error
	addMessageKeywordFn      func(ctx context.Context, userID, keyword string) (string, error)
	createBugReportFn        func(ctx context.Context, userID string, req *BugReportRequest) error
	createAuditLogFn         func(ctx context.Context, userID, action string, details map[string]any) error

	lastTwoFAMethods []TwoFAMethod
}

func (r *testRepo) GetUserSettings(ctx context.Context, userID string) (*UserSettings, error) {
	return &UserSettings{}, nil
}

func (r *testRepo) UpdateFeedLimitPending(ctx context.Context, userID string, pending int, applyAt time.Time) error {
	if r.updateFeedLimitFn != nil {
		return r.updateFeedLimitFn(ctx, userID, pending, applyAt)
	}
	return nil
}

func (r *testRepo) ApplyDueFeedLimits(ctx context.Context, now time.Time) error {
	if r.applyDueFeedLimitsFn != nil {
		return r.applyDueFeedLimitsFn(ctx, now)
	}
	return nil
}

func (r *testRepo) ListDueHardDeleteUserIDs(ctx context.Context, now time.Time, limit int) ([]string, error) {
	if r.listDueHardDeleteUserIDs != nil {
		return r.listDueHardDeleteUserIDs(ctx, now, limit)
	}
	return nil, nil
}

func (r *testRepo) HardDeleteUser(ctx context.Context, userID string) error {
	if r.hardDeleteUserFn != nil {
		return r.hardDeleteUserFn(ctx, userID)
	}
	return nil
}

func (r *testRepo) UpdateMessagesSettings(ctx context.Context, userID, whoCanMessage string, readStatus, safeMode *bool) error {
	return nil
}

func (r *testRepo) UpdateCommentsSettings(ctx context.Context, userID, whoCanComment string, filterUnwanted *bool) error {
	return nil
}

func (r *testRepo) UpdateMentionsSettings(ctx context.Context, userID, whoCanMention string) error {
	return nil
}

func (r *testRepo) ListMessageKeywords(ctx context.Context, userID string) ([]KeywordItem, error) {
	return nil, nil
}

func (r *testRepo) AddMessageKeyword(ctx context.Context, userID, keyword string) (string, error) {
	if r.addMessageKeywordFn != nil {
		return r.addMessageKeywordFn(ctx, userID, keyword)
	}
	return "keyword-id", nil
}

func (r *testRepo) DeleteMessageKeyword(ctx context.Context, userID, keywordID string) error {
	return nil
}

func (r *testRepo) CountActiveSessions(ctx context.Context, userID string) (int, error) {
	return 0, nil
}

func (r *testRepo) ListSessions(ctx context.Context, userID string) ([]SessionItem, error) {
	return nil, nil
}

func (r *testRepo) RevokeSession(ctx context.Context, userID, sessionID string, revokedAt time.Time) error {
	return nil
}

func (r *testRepo) RevokeAllSessionsExcept(ctx context.Context, userID, currentSessionID string, revokedAt time.Time) error {
	if r.revokeAllExceptFn != nil {
		return r.revokeAllExceptFn(ctx, userID, currentSessionID, revokedAt)
	}
	return nil
}

func (r *testRepo) RevokeAllSessions(ctx context.Context, userID string, revokedAt time.Time) error {
	return nil
}

func (r *testRepo) GetUserPasswordHash(ctx context.Context, userID string) (string, error) {
	if r.getUserPasswordHashFn != nil {
		return r.getUserPasswordHashFn(ctx, userID)
	}
	return "", nil
}

func (r *testRepo) UpdateUserPasswordHash(ctx context.Context, userID, passwordHash string, updatedAt time.Time) error {
	if r.updateUserPasswordHashFn != nil {
		return r.updateUserPasswordHashFn(ctx, userID, passwordHash, updatedAt)
	}
	return nil
}

func (r *testRepo) GetActiveTwoFAMethods(ctx context.Context, userID string) ([]TwoFAMethod, error) {
	if r.getActiveTwoFAMethodsFn != nil {
		return r.getActiveTwoFAMethodsFn(ctx, userID)
	}
	return r.lastTwoFAMethods, nil
}

func (r *testRepo) UpsertTwoFAMethod(ctx context.Context, userID, method string, isActive bool, secret *string) error {
	if r.upsertTwoFAMethodFn != nil {
		return r.upsertTwoFAMethodFn(ctx, userID, method, isActive, secret)
	}
	r.lastTwoFAMethods = append(r.lastTwoFAMethods, TwoFAMethod{Method: method, IsActive: isActive, SecretEncrypted: secret})
	return nil
}

func (r *testRepo) DeactivateAllTwoFAMethods(ctx context.Context, userID string) error { return nil }

func (r *testRepo) GetUserPhone(ctx context.Context, userID string) (string, string, error) {
	if r.getUserPhoneFn != nil {
		return r.getUserPhoneFn(ctx, userID)
	}
	return "", "", nil
}

func (r *testRepo) CreateDeleteRequest(ctx context.Context, userID, reason, verificationMethod string) (string, error) {
	if r.createDeleteRequestFn != nil {
		return r.createDeleteRequestFn(ctx, userID, reason, verificationMethod)
	}
	return "delete-request-id", nil
}

func (r *testRepo) GetLatestDeleteRequest(ctx context.Context, userID string) (*deleteAccountRequest, error) {
	if r.getLatestDeleteReqFn != nil {
		return r.getLatestDeleteReqFn(ctx, userID)
	}
	return nil, errors.New("not implemented")
}

func (r *testRepo) SetDeleteOTPCodeHash(ctx context.Context, requestID, otpCodeHash string) error {
	if r.setDeleteOTPCodeHashFn != nil {
		return r.setDeleteOTPCodeHashFn(ctx, requestID, otpCodeHash)
	}
	return nil
}

func (r *testRepo) SetDeleteVerification(ctx context.Context, requestID, token string, expiresAt time.Time) error {
	if r.setDeleteVerificationFn != nil {
		return r.setDeleteVerificationFn(ctx, requestID, token, expiresAt)
	}
	return nil
}

func (r *testRepo) MarkDeleteRequestVerified(ctx context.Context, requestID string, verifiedAt time.Time) error {
	if r.markDeleteVerifiedFn != nil {
		return r.markDeleteVerifiedFn(ctx, requestID, verifiedAt)
	}
	return nil
}

func (r *testRepo) SoftDeleteUser(ctx context.Context, userID string, deletedAt, hardDeleteAt time.Time) error {
	return nil
}

func (r *testRepo) CreateBugReport(ctx context.Context, userID string, req *BugReportRequest) error {
	if r.createBugReportFn != nil {
		return r.createBugReportFn(ctx, userID, req)
	}
	return nil
}

func (r *testRepo) CreateContactMessage(ctx context.Context, id, userID string, req *ContactRequest) error {
	return nil
}

func (r *testRepo) MarkContactMessageDelivered(ctx context.Context, id string, deliveredAt time.Time, deliveryErr string) error {
	return nil
}

func (r *testRepo) GetUserEmail(ctx context.Context, userID string) (string, error) {
	return "", nil
}

func (r *testRepo) ListBlockedUsers(ctx context.Context, userID string, cursor *time.Time, limit int) ([]BlockedUserItem, error) {
	return nil, nil
}

func (r *testRepo) UnblockUser(ctx context.Context, userID, targetUserID string) error { return nil }

func (r *testRepo) IsBlockedBetween(ctx context.Context, actorID, targetID string) (bool, error) {
	return false, nil
}

func (r *testRepo) CreateAuditLog(ctx context.Context, userID, action string, details map[string]any) error {
	if r.createAuditLogFn != nil {
		return r.createAuditLogFn(ctx, userID, action, details)
	}
	return nil
}

func (r *testRepo) GetFeedTimeLimit(ctx context.Context, userID string) (int, error) { return 20, nil }

func (r *testRepo) GetCommentPrivacy(ctx context.Context, userID string) (string, bool, error) {
	return MessagePrivacyEveryone, false, nil
}

func (r *testRepo) GetMessagePrivacy(ctx context.Context, userID string) (string, bool, bool, error) {
	return MessagePrivacyEveryone, true, false, nil
}

func (r *testRepo) GetMentionsPrivacy(ctx context.Context, userID string) (string, error) {
	return MessagePrivacyEveryone, nil
}

type testSMSSender struct {
	to      string
	message string
	err     error
}

func (s *testSMSSender) Send(ctx context.Context, to, message string) error {
	s.to = to
	s.message = message
	return s.err
}

func TestChangePassword_RevokesAllSessionsExceptCurrent(t *testing.T) {
	hash, err := bcrypt.GenerateFromPassword([]byte("Current1!"), bcrypt.DefaultCost)
	if err != nil {
		t.Fatalf("generate hash: %v", err)
	}

	updatedHash := ""
	revokedSession := ""
	repo := &testRepo{
		getUserPasswordHashFn: func(ctx context.Context, userID string) (string, error) {
			return string(hash), nil
		},
		updateUserPasswordHashFn: func(ctx context.Context, userID, passwordHash string, updatedAt time.Time) error {
			updatedHash = passwordHash
			return nil
		},
		revokeAllExceptFn: func(ctx context.Context, userID, currentSessionID string, revokedAt time.Time) error {
			revokedSession = currentSessionID
			return nil
		},
	}
	svc := NewService(repo, nil)

	if err := svc.ChangePassword(context.Background(), "user-1", "session-1", "Current1!", "NewStrong1!"); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if updatedHash == "" || updatedHash == string(hash) {
		t.Fatal("expected password hash to be updated")
	}
	if revokedSession != "session-1" {
		t.Fatalf("expected current session to be preserved, got %q", revokedSession)
	}
}

func TestEnableTwoFA_ReturnsSecretButGetStatusDoesNot(t *testing.T) {
	repo := &testRepo{}
	svc := NewService(repo, nil)

	enabled, err := svc.EnableTwoFA(context.Background(), "user-1", []string{TwoFAMethodSMS, TwoFAMethodAuthenticator})
	if err != nil {
		t.Fatalf("unexpected enable error: %v", err)
	}
	if enabled.Secret == "" {
		t.Fatal("expected authenticator secret on enable")
	}

	status, err := svc.GetTwoFAStatus(context.Background(), "user-1")
	if err != nil {
		t.Fatalf("unexpected status error: %v", err)
	}
	if status.Secret != "" {
		t.Fatal("did not expect secret in get status response")
	}
}

func TestDeleteAccountReason_UsesOTPWhenSMS2FAAndPhonePresent(t *testing.T) {
	sender := &testSMSSender{}
	verificationMethod := ""
	otpHash := ""
	repo := &testRepo{
		getActiveTwoFAMethodsFn: func(ctx context.Context, userID string) ([]TwoFAMethod, error) {
			return []TwoFAMethod{{Method: TwoFAMethodSMS, IsActive: true}}, nil
		},
		getUserPhoneFn: func(ctx context.Context, userID string) (string, string, error) {
			return "+1", "5551234567", nil
		},
		createDeleteRequestFn: func(ctx context.Context, userID, reason, method string) (string, error) {
			verificationMethod = method
			return "delete-request-id", nil
		},
		setDeleteOTPCodeHashFn: func(ctx context.Context, requestID, value string) error {
			otpHash = value
			return nil
		},
	}
	svc := NewService(repo, sender)

	resp, err := svc.DeleteAccountReason(context.Background(), "user-1", "privacy_concerns")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.VerificationMethod != "otp" || verificationMethod != "otp" {
		t.Fatalf("expected otp verification, got response=%q repo=%q", resp.VerificationMethod, verificationMethod)
	}
	if otpHash == "" {
		t.Fatal("expected otp hash to be stored")
	}
	if sender.to != "+15551234567" {
		t.Fatalf("unexpected sms recipient: %q", sender.to)
	}
	if !strings.Contains(sender.message, "delete account code") {
		t.Fatalf("unexpected sms message: %q", sender.message)
	}
}

func TestDeleteAccountVerify_OTPReturnsVerificationToken(t *testing.T) {
	storedToken := ""
	var expiresAt time.Time
	repo := &testRepo{
		getLatestDeleteReqFn: func(ctx context.Context, userID string) (*deleteAccountRequest, error) {
			hash := hashDeleteOTP("1234")
			return &deleteAccountRequest{
				ID:                 "delete-request-id",
				UserID:             userID,
				VerificationMethod: "otp",
				OTPCodeHash:        &hash,
				CreatedAt:          time.Now(),
			}, nil
		},
		setDeleteVerificationFn: func(ctx context.Context, requestID, token string, exp time.Time) error {
			storedToken = token
			expiresAt = exp
			return nil
		},
	}
	svc := NewService(repo, nil)

	resp, err := svc.DeleteAccountVerify(context.Background(), "user-1", &DeleteAccountVerifyRequest{OTP: "1234"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.VerificationToken == "" || storedToken == "" {
		t.Fatal("expected verification token to be stored and returned")
	}
	if expiresAt.IsZero() || time.Until(expiresAt) <= 0 {
		t.Fatal("expected verification expiry to be set in the future")
	}
}

func TestPatchFeedSettings_SchedulesPendingFor24Hours(t *testing.T) {
	var pending int
	var applyAt time.Time
	repo := &testRepo{
		updateFeedLimitFn: func(ctx context.Context, userID string, value int, at time.Time) error {
			pending = value
			applyAt = at
			return nil
		},
	}
	svc := NewService(repo, nil)

	before := time.Now().Add(24 * time.Hour)
	if err := svc.PatchFeedSettings(context.Background(), "user-1", FeedLimit60); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	after := time.Now().Add(24 * time.Hour)
	if pending != FeedLimit60 {
		t.Fatalf("expected pending limit %d, got %d", FeedLimit60, pending)
	}
	if applyAt.Before(before.Add(-2*time.Second)) || applyAt.After(after.Add(2*time.Second)) {
		t.Fatalf("unexpected apply time: %s", applyAt)
	}
}

func TestAddMessageKeyword_RejectsEmptyKeyword(t *testing.T) {
	svc := NewService(&testRepo{}, nil)

	_, err := svc.AddMessageKeyword(context.Background(), "user-1", "   ")
	if !errors.Is(err, ErrKeywordEmpty) {
		t.Fatalf("expected ErrKeywordEmpty, got %v", err)
	}
}

func TestCreateBugReport_RejectsTooLongDescription(t *testing.T) {
	svc := NewService(&testRepo{}, nil)
	req := &BugReportRequest{Description: strings.Repeat("a", 2001)}

	err := svc.CreateBugReport(context.Background(), "user-1", req)
	if !errors.Is(err, ErrDescriptionTooLong) {
		t.Fatalf("expected ErrDescriptionTooLong, got %v", err)
	}
}

func TestApplyDueHardDeletes_ProcessesAllBatches(t *testing.T) {
	var hardDeleted []string
	call := 0

	repo := &testRepo{
		listDueHardDeleteUserIDs: func(ctx context.Context, now time.Time, limit int) ([]string, error) {
			call++
			switch call {
			case 1:
				users := make([]string, hardDeleteBatchSize)
				for i := range users {
					users[i] = "user-batch-1-" + time.Now().Add(time.Duration(i)*time.Nanosecond).Format("150405.000000000")
				}
				return users, nil
			case 2:
				return []string{"user-batch-2-a", "user-batch-2-b"}, nil
			default:
				return nil, nil
			}
		},
		hardDeleteUserFn: func(ctx context.Context, userID string) error {
			hardDeleted = append(hardDeleted, userID)
			return nil
		},
	}

	svc := NewService(repo, nil)
	if err := svc.ApplyDueHardDeletes(context.Background()); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	expected := hardDeleteBatchSize + 2
	if len(hardDeleted) != expected {
		t.Fatalf("expected %d hard-deleted users, got %d", expected, len(hardDeleted))
	}
}

func TestApplyDueHardDeletes_ReturnsErrorOnHardDeleteFailure(t *testing.T) {
	repo := &testRepo{
		listDueHardDeleteUserIDs: func(ctx context.Context, now time.Time, limit int) ([]string, error) {
			return []string{"user-1"}, nil
		},
		hardDeleteUserFn: func(ctx context.Context, userID string) error {
			return errors.New("delete failed")
		},
	}

	svc := NewService(repo, nil)
	err := svc.ApplyDueHardDeletes(context.Background())
	if err == nil || err.Error() != "delete failed" {
		t.Fatalf("expected delete failed error, got %v", err)
	}
}

