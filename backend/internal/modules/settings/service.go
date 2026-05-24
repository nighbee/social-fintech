package settings

import (
	"context"
	"crypto/rand"
	"database/sql"
	"fmt"
	"math/big"
	"strings"
	"time"
	"unicode"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

type Service struct {
	repo         Repository
	smsSender    SMSSender
	emailSender  EmailSender
	supportInbox string
	authProvider AuthAdapter
}

const hardDeleteBatchSize = 100

// DefaultSupportInbox is the founder-mandated destination for the
// in-app Contact Us form. It can be overridden at construction time
// if a deploy needs a different recipient.
const DefaultSupportInbox = "19thZaratustra@gmail.com"

type SMSSender interface {
	Send(ctx context.Context, to, message string) error
}

// EmailSender abstracts the SMTP transport used for outbound support
// notifications (Contact Us, etc). Settings deliberately defines its
// own interface so it does not depend on the auth package.
type EmailSender interface {
	Send(ctx context.Context, to, subject, body string) error
}

type noopSMSSender struct{}

func (n *noopSMSSender) Send(ctx context.Context, to, message string) error {
	return nil
}

type noopEmailSender struct{}

func (n *noopEmailSender) Send(ctx context.Context, to, subject, body string) error {
	return nil
}

func NewService(repo Repository, smsSender SMSSender, authProvider ...AuthAdapter) *Service {
	if smsSender == nil {
		smsSender = &noopSMSSender{}
	}

	var provider AuthAdapter
	if len(authProvider) > 0 {
		provider = authProvider[0]
	}

	return &Service{
		repo:         repo,
		smsSender:    smsSender,
		emailSender:  &noopEmailSender{},
		supportInbox: DefaultSupportInbox,
		authProvider: provider,
	}
}

// SetEmailSender installs a real SMTP transport for outbound support
// emails. Called from main.go after wiring SMTP config; defaults to a
// no-op so unit tests don't need to fake delivery.
func (s *Service) SetEmailSender(sender EmailSender) {
	if sender == nil {
		return
	}
	s.emailSender = sender
}

// SetSupportInbox overrides the default support recipient address.
// Empty values are ignored so deploys can rely on the constant default.
func (s *Service) SetSupportInbox(addr string) {
	addr = strings.TrimSpace(addr)
	if addr == "" {
		return
	}
	s.supportInbox = addr
}

func (s *Service) countActiveSessions(ctx context.Context, userID string) (int, error) {
	if s.authProvider != nil {
		return s.authProvider.CountActiveSessions(ctx, userID)
	}
	return s.repo.CountActiveSessions(ctx, userID)
}

func (s *Service) listSessions(ctx context.Context, userID string) ([]SessionItem, error) {
	if s.authProvider != nil {
		return s.authProvider.ListSessions(ctx, userID)
	}
	return s.repo.ListSessions(ctx, userID)
}

func (s *Service) revokeSessionForUser(ctx context.Context, userID, sessionID string, revokedAt time.Time) error {
	if s.authProvider != nil {
		return s.authProvider.RevokeSession(ctx, userID, sessionID, revokedAt)
	}
	return s.repo.RevokeSession(ctx, userID, sessionID, revokedAt)
}

func (s *Service) revokeAllSessionsExceptForUser(ctx context.Context, userID, currentSessionID string, revokedAt time.Time) error {
	if s.authProvider != nil {
		return s.authProvider.RevokeAllSessionsExcept(ctx, userID, currentSessionID, revokedAt)
	}
	return s.repo.RevokeAllSessionsExcept(ctx, userID, currentSessionID, revokedAt)
}

func (s *Service) revokeAllSessionsForUser(ctx context.Context, userID string, revokedAt time.Time) error {
	if s.authProvider != nil {
		return s.authProvider.RevokeAllSessions(ctx, userID, revokedAt)
	}
	return s.repo.RevokeAllSessions(ctx, userID, revokedAt)
}

func (s *Service) getUserPasswordHash(ctx context.Context, userID string) (string, error) {
	if s.authProvider != nil {
		return s.authProvider.GetUserPasswordHash(ctx, userID)
	}
	return s.repo.GetUserPasswordHash(ctx, userID)
}

func (s *Service) updateUserPasswordHash(ctx context.Context, userID, passwordHash string, updatedAt time.Time) error {
	if s.authProvider != nil {
		return s.authProvider.UpdateUserPasswordHash(ctx, userID, passwordHash, updatedAt)
	}
	return s.repo.UpdateUserPasswordHash(ctx, userID, passwordHash, updatedAt)
}

func (s *Service) getUserPhone(ctx context.Context, userID string) (string, string, error) {
	if s.authProvider != nil {
		return s.authProvider.GetUserPhone(ctx, userID)
	}
	return s.repo.GetUserPhone(ctx, userID)
}

func isValidFeedLimit(v int) bool {
	return v == FeedLimitNoLimit || v == FeedLimit20 || v == FeedLimit40 || v == FeedLimit60
}

func isValidPrivacy(v string) bool {
	switch v {
	case "", MessagePrivacyEveryone, MessagePrivacyNoOne, MessagePrivacyAlliesOnly:
		return true
	default:
		return false
	}
}

func isValidDeleteReason(v string) bool {
	switch v {
	case "want_to_remove_something", "need_a_break", "cant_find_people", "privacy_concerns", "created_another_account", "trouble_getting_started", "concerned_about_my_data", "too_busy", "something_else":
		return true
	default:
		return false
	}
}

func normalizeTwoFAMethod(v string) string {
	return strings.ToLower(strings.TrimSpace(v))
}

func generateDeleteOTP() (string, error) {
	max := big.NewInt(10000)
	n, err := rand.Int(rand.Reader, max)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%04d", n.Int64()), nil
}

func isValidTwoFAMethod(v string) bool {
	switch normalizeTwoFAMethod(v) {
	case TwoFAMethodSMS, TwoFAMethodEmail, TwoFAMethodAuthenticator:
		return true
	default:
		return false
	}
}

func (s *Service) validatePasswordStrength(p string) bool {
	if len(p) < 8 {
		return false
	}
	var hasUpper, hasLower, hasDigit, hasSpecial bool
	for _, r := range p {
		switch {
		case unicode.IsUpper(r):
			hasUpper = true
		case unicode.IsLower(r):
			hasLower = true
		case unicode.IsDigit(r):
			hasDigit = true
		default:
			hasSpecial = true
		}
	}
	return hasUpper && hasLower && hasDigit && hasSpecial
}

func (s *Service) GetSecurityOverview(ctx context.Context, userID, currentSessionID string) (*SecurityOverviewResponse, error) {
	methods, err := s.repo.GetActiveTwoFAMethods(ctx, userID)
	if err != nil {
		return nil, err
	}
	sessions, err := s.countActiveSessions(ctx, userID)
	if err != nil {
		return nil, err
	}

	hash, err := s.getUserPasswordHash(ctx, userID)
	if err != nil {
		// Non-fatal, just assume no password
		hash = ""
	}

	methodNames := make([]string, 0, len(methods))
	for _, m := range methods {
		methodNames = append(methodNames, m.Method)
	}
	return &SecurityOverviewResponse{
		TwoFAEnabled:       len(methodNames) > 0,
		TwoFAMethods:       methodNames,
		ActiveSessions:     sessions,
		CurrentSessionID:   currentSessionID,
		PasswordLoginReady: hash != "",
		HasPassword:        hash != "",
	}, nil
}

func (s *Service) ChangePassword(ctx context.Context, userID, currentSessionID, currentPassword, newPassword string) error {
	if !s.validatePasswordStrength(newPassword) {
		return ErrPasswordTooWeak
	}
	hash, err := s.getUserPasswordHash(ctx, userID)
	if err != nil {
		return err
	}
	// If the user already has a password, we MUST verify the current one.
	// If they don't (e.g. magic link signup), we allow setting the first password without a current one.
	if hash != "" {
		if bcrypt.CompareHashAndPassword([]byte(hash), []byte(currentPassword)) != nil {
			return ErrInvalidCredentials
		}
	}
	newHash, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	if err := s.updateUserPasswordHash(ctx, userID, string(newHash), time.Now()); err != nil {
		return err
	}
	if err := s.revokeAllSessionsExceptForUser(ctx, userID, currentSessionID, time.Now()); err != nil {
		return err
	}
	_ = s.repo.CreateAuditLog(ctx, userID, "security_password_changed", map[string]any{"session_id": currentSessionID})
	return nil
}

func (s *Service) GetTwoFAStatus(ctx context.Context, userID string) (*TwoFAStatusResponse, error) {
	methods, err := s.repo.GetActiveTwoFAMethods(ctx, userID)
	if err != nil {
		return nil, err
	}
	resp := &TwoFAStatusResponse{Enabled: len(methods) > 0}
	for _, m := range methods {
		resp.Methods = append(resp.Methods, m.Method)
	}
	return resp, nil
}

func (s *Service) EnableTwoFA(ctx context.Context, userID string, methods []string) (*TwoFAStatusResponse, error) {
	set := make(map[string]struct{})
	for _, m := range methods {
		n := normalizeTwoFAMethod(m)
		if !isValidTwoFAMethod(n) {
			return nil, ErrInvalidTwoFAMethod
		}
		set[n] = struct{}{}
	}
	if len(set) < 2 {
		return nil, ErrTwoFAMinimumMethods
	}
	var generatedSecret string
	for method := range set {
		var secret *string
		if method == TwoFAMethodAuthenticator {
			v := strings.ReplaceAll(uuid.NewString(), "-", "")
			generatedSecret = v
			secret = &v
		}
		if err := s.repo.UpsertTwoFAMethod(ctx, userID, method, true, secret); err != nil {
			return nil, err
		}
	}
	_ = s.repo.CreateAuditLog(ctx, userID, "security_2fa_enabled", map[string]any{"methods": methods})
	status, err := s.GetTwoFAStatus(ctx, userID)
	if err != nil {
		return nil, err
	}
	if generatedSecret != "" {
		status.Secret = generatedSecret
	}
	return status, nil
}

func (s *Service) DisableTwoFA(ctx context.Context, userID, currentPassword string) error {
	hash, err := s.getUserPasswordHash(ctx, userID)
	if err != nil {
		return err
	}
	if hash != "" {
		if bcrypt.CompareHashAndPassword([]byte(hash), []byte(currentPassword)) != nil {
			return ErrInvalidCredentials
		}
	}
	if err := s.repo.DeactivateAllTwoFAMethods(ctx, userID); err != nil {
		return err
	}
	_ = s.repo.CreateAuditLog(ctx, userID, "security_2fa_disabled", nil)
	return nil
}

func (s *Service) ListSessions(ctx context.Context, userID, currentSessionID string) ([]SessionItem, error) {
	items, err := s.listSessions(ctx, userID)
	if err != nil {
		return nil, err
	}
	for i := range items {
		items[i].IsCurrent = items[i].ID == currentSessionID
	}
	return items, nil
}

func (s *Service) RevokeSession(ctx context.Context, userID, currentSessionID, sessionID string) error {
	if sessionID == currentSessionID {
		return ErrCannotDeleteCurrentSession
	}
	return s.revokeSessionForUser(ctx, userID, sessionID, time.Now())
}

func (s *Service) RevokeAllSessionsExceptCurrent(ctx context.Context, userID, currentSessionID string) error {
	return s.revokeAllSessionsExceptForUser(ctx, userID, currentSessionID, time.Now())
}

func (s *Service) DeleteAccountReason(ctx context.Context, userID, reason string) (*DeleteAccountReasonResponse, error) {
	if !isValidDeleteReason(reason) {
		return nil, ErrDeleteReasonInvalid
	}
	verificationMethod := "password"
	methods, err := s.repo.GetActiveTwoFAMethods(ctx, userID)
	if err != nil {
		return nil, err
	}
	for _, method := range methods {
		if method.Method == TwoFAMethodSMS && method.IsActive {
			countryCode, phoneNumber, phoneErr := s.getUserPhone(ctx, userID)
			if phoneErr != nil {
				return nil, phoneErr
			}
			if countryCode != "" && phoneNumber != "" {
				verificationMethod = "otp"
			}
			break
		}
	}
	requestID, err := s.repo.CreateDeleteRequest(ctx, userID, reason, verificationMethod)
	if err != nil {
		return nil, err
	}
	if verificationMethod == "otp" {
		countryCode, phoneNumber, err := s.getUserPhone(ctx, userID)
		if err != nil {
			return nil, err
		}
		otp, err := generateDeleteOTP()
		if err != nil {
			return nil, err
		}
		if err := s.repo.SetDeleteOTPCodeHash(ctx, requestID, hashDeleteOTP(otp)); err != nil {
			return nil, err
		}
		if err := s.smsSender.Send(ctx, countryCode+phoneNumber, fmt.Sprintf("Your BrightBund delete account code is %s", otp)); err != nil {
			return nil, err
		}
	}
	_ = s.repo.CreateAuditLog(ctx, userID, "security_delete_account_reason", map[string]any{"reason": reason})
	return &DeleteAccountReasonResponse{VerificationMethod: verificationMethod}, nil
}

func (s *Service) DeleteAccountVerify(ctx context.Context, userID string, req *DeleteAccountVerifyRequest) (*DeleteAccountVerifyResponse, error) {
	latest, err := s.repo.GetLatestDeleteRequest(ctx, userID)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrDeleteRequestNotFound
		}
		return nil, err
	}

	switch latest.VerificationMethod {
	case "password":
		hash, err := s.getUserPasswordHash(ctx, userID)
		if err != nil {
			return nil, err
		}
		if hash != "" {
			if bcrypt.CompareHashAndPassword([]byte(hash), []byte(req.Password)) != nil {
				return nil, ErrInvalidCredentials
			}
		}
	case "otp":
		if req.OTP == "" {
			return nil, ErrInvalidCredentials
		}
		if latest.OTPCodeHash == nil || *latest.OTPCodeHash != hashDeleteOTP(req.OTP) {
			return nil, ErrInvalidCredentials
		}
	default:
		return nil, ErrInvalidCredentials
	}

	token := uuid.NewString()
	expiresAt := time.Now().Add(10 * time.Minute)
	if err := s.repo.SetDeleteVerification(ctx, latest.ID, token, expiresAt); err != nil {
		return nil, err
	}
	if err := s.repo.MarkDeleteRequestVerified(ctx, latest.ID, time.Now()); err != nil {
		return nil, err
	}
	_ = s.repo.CreateAuditLog(ctx, userID, "security_delete_account_verified", nil)
	return &DeleteAccountVerifyResponse{VerificationToken: token, ExpiresAt: expiresAt}, nil
}

func (s *Service) DeleteAccountFinalize(ctx context.Context, userID, verificationToken string) error {
	latest, err := s.repo.GetLatestDeleteRequest(ctx, userID)
	if err != nil {
		if err == sql.ErrNoRows {
			return ErrDeleteRequestNotFound
		}
		return err
	}
	if latest.VerificationToken == nil || *latest.VerificationToken != verificationToken {
		return ErrDeleteVerificationInvalid
	}
	if latest.VerificationExpires == nil || time.Now().After(*latest.VerificationExpires) {
		return ErrDeleteVerificationExpired
	}

	now := time.Now()
	if err := s.repo.SoftDeleteUser(ctx, userID, now, now.Add(30*24*time.Hour)); err != nil {
		return err
	}
	if err := s.revokeAllSessionsForUser(ctx, userID, now); err != nil {
		return err
	}
	_ = s.repo.CreateAuditLog(ctx, userID, "security_delete_account_finalized", nil)
	return nil
}

func (s *Service) GetFeedSettings(ctx context.Context, userID string) (*FeedSettingsResponse, error) {
	settings, err := s.repo.GetUserSettings(ctx, userID)
	if err != nil {
		return nil, err
	}
	return &FeedSettingsResponse{
		CurrentMins:    settings.FeedTimeLimitCurrentMins,
		PendingMins:    settings.FeedTimeLimitPendingMins,
		PendingApplyAt: settings.FeedTimeLimitPendingApplyAt,
	}, nil
}

func (s *Service) PatchFeedSettings(ctx context.Context, userID string, newLimit int) error {
	if !isValidFeedLimit(newLimit) {
		return ErrInvalidFeedLimit
	}
	return s.repo.UpdateFeedLimitPending(ctx, userID, newLimit, time.Now().Add(24*time.Hour))
}

func (s *Service) GetInteractions(ctx context.Context, userID string) (*InteractionsSettingsResponse, error) {
	settings, err := s.repo.GetUserSettings(ctx, userID)
	if err != nil {
		return nil, err
	}
	keywords, err := s.repo.ListMessageKeywords(ctx, userID)
	if err != nil {
		return nil, err
	}
	return &InteractionsSettingsResponse{
		Messages: MessagesSettingsResponse{
			WhoCanMessage: settings.MessagesWhoCanMessage,
			ReadStatus:    settings.MessagesReadStatusEnabled,
			SafeMode:      settings.MessagesSafeModeEnabled,
			Keywords:      keywords,
		},
		Comments: CommentsSettingsResponse{
			WhoCanComment:  settings.CommentsWhoCanComment,
			FilterUnwanted: settings.CommentsFilterUnwanted,
		},
		Mentions: MentionsSettingsResponse{WhoCanMention: settings.MentionsWhoCanMention},
	}, nil
}

func (s *Service) GetMessagesSettings(ctx context.Context, userID string) (*MessagesSettingsResponse, error) {
	settings, err := s.repo.GetUserSettings(ctx, userID)
	if err != nil {
		return nil, err
	}
	keywords, err := s.repo.ListMessageKeywords(ctx, userID)
	if err != nil {
		return nil, err
	}
	return &MessagesSettingsResponse{
		WhoCanMessage: settings.MessagesWhoCanMessage,
		ReadStatus:    settings.MessagesReadStatusEnabled,
		SafeMode:      settings.MessagesSafeModeEnabled,
		Keywords:      keywords,
	}, nil
}

func (s *Service) PatchMessagesSettings(ctx context.Context, userID string, req *PatchMessagesSettingsRequest) error {
	if !isValidPrivacy(req.WhoCanMessage) {
		return ErrInvalidPrivacyOption
	}
	return s.repo.UpdateMessagesSettings(ctx, userID, req.WhoCanMessage, req.ReadStatus, req.SafeMode)
}

func (s *Service) AddMessageKeyword(ctx context.Context, userID, keyword string) (string, error) {
	keyword = strings.TrimSpace(keyword)
	if keyword == "" {
		return "", ErrKeywordEmpty
	}
	return s.repo.AddMessageKeyword(ctx, userID, keyword)
}

func (s *Service) DeleteMessageKeyword(ctx context.Context, userID, keywordID string) error {
	return s.repo.DeleteMessageKeyword(ctx, userID, keywordID)
}

func (s *Service) GetCommentsSettings(ctx context.Context, userID string) (*CommentsSettingsResponse, error) {
	settings, err := s.repo.GetUserSettings(ctx, userID)
	if err != nil {
		return nil, err
	}
	return &CommentsSettingsResponse{
		WhoCanComment:  settings.CommentsWhoCanComment,
		FilterUnwanted: settings.CommentsFilterUnwanted,
	}, nil
}

func (s *Service) PatchCommentsSettings(ctx context.Context, userID string, req *PatchCommentsSettingsRequest) error {
	if !isValidPrivacy(req.WhoCanComment) {
		return ErrInvalidPrivacyOption
	}
	return s.repo.UpdateCommentsSettings(ctx, userID, req.WhoCanComment, req.FilterUnwanted)
}

func (s *Service) GetMentionsSettings(ctx context.Context, userID string) (*MentionsSettingsResponse, error) {
	settings, err := s.repo.GetUserSettings(ctx, userID)
	if err != nil {
		return nil, err
	}
	return &MentionsSettingsResponse{WhoCanMention: settings.MentionsWhoCanMention}, nil
}

func (s *Service) PatchMentionsSettings(ctx context.Context, userID string, req *PatchMentionsSettingsRequest) error {
	if !isValidPrivacy(req.WhoCanMention) {
		return ErrInvalidPrivacyOption
	}
	return s.repo.UpdateMentionsSettings(ctx, userID, req.WhoCanMention)
}

func (s *Service) GetNotificationSettings(ctx context.Context, userID string) (*NotificationsSettingsResponse, error) {
	settings, err := s.repo.GetUserSettings(ctx, userID)
	if err != nil {
		return nil, err
	}
	return &NotificationsSettingsResponse{
		NotifyGoldHonor: settings.NotifyGoldHonorReceived,
		NotifyMedal:     settings.NotifyMedalUnlocked,
		NotifyRank:      settings.NotifyRankIncreased,
		NotifyTasks:     settings.NotifyTaskUpdates,
		NotifyComments:  settings.NotifyCommentsReplies,
		NotifyLikes:     settings.NotifyLikesReactions,
		QuietHoursStart: settings.QuietHoursStart,
		QuietHoursEnd:   settings.QuietHoursEnd,
	}, nil
}

func (s *Service) PatchNotificationSettings(ctx context.Context, userID string, req PatchNotificationsSettingsRequest) error {
	return s.repo.UpdateNotificationSettings(ctx, userID, req)
}

func (s *Service) ListBlockedUsers(ctx context.Context, userID, cursor string, limit int) (*BlockedUsersResponse, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	var cursorTime *time.Time
	if cursor != "" {
		if t, err := time.Parse(time.RFC3339Nano, cursor); err == nil {
			cursorTime = &t
		}
	}
	items, err := s.repo.ListBlockedUsers(ctx, userID, cursorTime, limit+1)
	if err != nil {
		return nil, err
	}
	resp := &BlockedUsersResponse{}
	if len(items) > limit {
		last := items[limit-1]
		resp.NextCursor = last.LastActiveAt.UTC().Format(time.RFC3339Nano)
		items = items[:limit]
	}
	resp.Items = items
	return resp, nil
}

func (s *Service) UnblockUser(ctx context.Context, userID, targetUserID string) error {
	return s.repo.UnblockUser(ctx, userID, targetUserID)
}

func (s *Service) CreateBugReport(ctx context.Context, userID string, req *BugReportRequest) error {
	req.Description = strings.TrimSpace(req.Description)
	if req.Description == "" {
		return ErrDescriptionRequired
	}
	if len(req.Description) > 2000 {
		return ErrDescriptionTooLong
	}
	return s.repo.CreateBugReport(ctx, userID, req)
}

// CreateContactMessage persists a Contact Us submission and forwards it
// to the support inbox. The DB row is the source of truth: it's written
// before the SMTP attempt so that even if delivery fails we still have
// the user's message and can retry transport later.
func (s *Service) CreateContactMessage(ctx context.Context, userID string, req *ContactRequest) (*ContactResponse, error) {
	if req == nil {
		return nil, ErrMessageRequired
	}

	req.Category = ContactCategory(strings.ToLower(strings.TrimSpace(string(req.Category))))
	if !req.Category.IsValid() {
		return nil, ErrInvalidContactCategory
	}

	req.Message = strings.TrimSpace(req.Message)
	if req.Message == "" {
		return nil, ErrMessageRequired
	}
	if len(req.Message) > 5000 {
		return nil, ErrMessageTooLong
	}

	req.Subject = strings.TrimSpace(req.Subject)
	req.Email = strings.TrimSpace(req.Email)
	req.AppVersion = strings.TrimSpace(req.AppVersion)
	req.DeviceOS = strings.TrimSpace(req.DeviceOS)

	id := uuid.NewString()
	if err := s.repo.CreateContactMessage(ctx, id, userID, req); err != nil {
		return nil, err
	}

	// Best-effort fill of the reply-to: prefer what the user typed, but
	// fall back to their account email so support can always respond.
	replyTo := req.Email
	if replyTo == "" && userID != "" {
		if accountEmail, err := s.repo.GetUserEmail(ctx, userID); err == nil {
			replyTo = accountEmail
		}
	}

	subject := contactSubjectLine(req.Category, req.Subject)
	body := buildContactEmailBody(id, userID, replyTo, req)

	now := time.Now()
	if err := s.emailSender.Send(ctx, s.supportInbox, subject, body); err != nil {
		// Persist the transport error so support tooling can re-drive
		// undelivered messages without losing them.
		_ = s.repo.MarkContactMessageDelivered(ctx, id, time.Time{}, err.Error())
		return &ContactResponse{
			ID:         id,
			Status:     "queued",
			ReceivedAt: now,
		}, nil
	}

	_ = s.repo.MarkContactMessageDelivered(ctx, id, now, "")
	return &ContactResponse{
		ID:         id,
		Status:     "delivered",
		ReceivedAt: now,
	}, nil
}

func contactSubjectLine(category ContactCategory, subject string) string {
	prefix := fmt.Sprintf("[BrightBund Contact - %s]", strings.ToUpper(string(category)))
	if subject == "" {
		return prefix + " New message"
	}
	return prefix + " " + subject
}

func buildContactEmailBody(id, userID, replyTo string, req *ContactRequest) string {
	var b strings.Builder
	fmt.Fprintf(&b, "Submission ID: %s\n", id)
	fmt.Fprintf(&b, "Category:      %s\n", req.Category)
	if userID != "" {
		fmt.Fprintf(&b, "User ID:       %s\n", userID)
	} else {
		b.WriteString("User ID:       (anonymous)\n")
	}
	if replyTo != "" {
		fmt.Fprintf(&b, "Reply-to:      %s\n", replyTo)
	}
	if req.AppVersion != "" {
		fmt.Fprintf(&b, "App version:   %s\n", req.AppVersion)
	}
	if req.DeviceOS != "" {
		fmt.Fprintf(&b, "Device OS:     %s\n", req.DeviceOS)
	}
	b.WriteString("\n--- Message ---\n")
	b.WriteString(req.Message)
	b.WriteString("\n")
	return b.String()
}

func (s *Service) ApplyDueFeedLimits(ctx context.Context) error {
	return s.repo.ApplyDueFeedLimits(ctx, time.Now())
}

func (s *Service) ApplyDueHardDeletes(ctx context.Context) error {
	now := time.Now()

	for {
		userIDs, err := s.repo.ListDueHardDeleteUserIDs(ctx, now, hardDeleteBatchSize)
		if err != nil {
			return err
		}
		if len(userIDs) == 0 {
			return nil
		}

		for _, userID := range userIDs {
			if err := s.repo.HardDeleteUser(ctx, userID); err != nil {
				return err
			}
		}

		if len(userIDs) < hardDeleteBatchSize {
			return nil
		}
	}
}

// Public service methods for cross-module usage.
func (s *Service) GetFeedTimeLimit(ctx context.Context, userID string) (int, error) {
	return s.repo.GetFeedTimeLimit(ctx, userID)
}

func (s *Service) GetCommentPrivacy(ctx context.Context, userID string) (string, bool, error) {
	return s.repo.GetCommentPrivacy(ctx, userID)
}

func (s *Service) GetMessagePrivacy(ctx context.Context, userID string) (string, bool, bool, error) {
	return s.repo.GetMessagePrivacy(ctx, userID)
}

func (s *Service) GetMentionsPrivacy(ctx context.Context, userID string) (string, error) {
	return s.repo.GetMentionsPrivacy(ctx, userID)
}

func (s *Service) GetNotificationPreferences(ctx context.Context, userID string) (map[string]bool, error) {
	return s.repo.GetNotificationPreferences(ctx, userID)
}

func (s *Service) IsBlockedBetween(ctx context.Context, actorID, targetID string) (bool, error) {
	return s.repo.IsBlockedBetween(ctx, actorID, targetID)
}
