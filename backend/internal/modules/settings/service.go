package settings

import (
	"context"
	"database/sql"
	"strings"
	"time"
	"unicode"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

type Service struct {
	repo Repository
}

func NewService(repo Repository) *Service {
	return &Service{repo: repo}
}

func isValidFeedLimit(v int) bool {
	return v == FeedLimitNoLimit || v == FeedLimit20 || v == FeedLimit30 || v == FeedLimit40
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
	sessions, err := s.repo.CountActiveSessions(ctx, userID)
	if err != nil {
		return nil, err
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
		PasswordLoginReady: true,
	}, nil
}

func (s *Service) ChangePassword(ctx context.Context, userID, currentSessionID, currentPassword, newPassword string) error {
	if !s.validatePasswordStrength(newPassword) {
		return ErrPasswordTooWeak
	}
	hash, err := s.repo.GetUserPasswordHash(ctx, userID)
	if err != nil {
		return err
	}
	if hash == "" || bcrypt.CompareHashAndPassword([]byte(hash), []byte(currentPassword)) != nil {
		return ErrInvalidCredentials
	}
	newHash, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	if err := s.repo.UpdateUserPasswordHash(ctx, userID, string(newHash), time.Now()); err != nil {
		return err
	}
	if err := s.repo.RevokeAllSessionsExcept(ctx, userID, currentSessionID, time.Now()); err != nil {
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
		if m.Method == TwoFAMethodAuthenticator && m.SecretEncrypted != nil {
			resp.Secret = *m.SecretEncrypted
		}
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
	hash, err := s.repo.GetUserPasswordHash(ctx, userID)
	if err != nil {
		return err
	}
	if hash == "" || bcrypt.CompareHashAndPassword([]byte(hash), []byte(currentPassword)) != nil {
		return ErrInvalidCredentials
	}
	if err := s.repo.DeactivateAllTwoFAMethods(ctx, userID); err != nil {
		return err
	}
	_ = s.repo.CreateAuditLog(ctx, userID, "security_2fa_disabled", nil)
	return nil
}

func (s *Service) ListSessions(ctx context.Context, userID, currentSessionID string) ([]SessionItem, error) {
	items, err := s.repo.ListSessions(ctx, userID)
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
	return s.repo.RevokeSession(ctx, userID, sessionID, time.Now())
}

func (s *Service) RevokeAllSessionsExceptCurrent(ctx context.Context, userID, currentSessionID string) error {
	return s.repo.RevokeAllSessionsExcept(ctx, userID, currentSessionID, time.Now())
}

func (s *Service) DeleteAccountReason(ctx context.Context, userID, reason string) (*DeleteAccountReasonResponse, error) {
	if !isValidDeleteReason(reason) {
		return nil, ErrDeleteReasonInvalid
	}
	verificationMethod := "password"
	if _, err := s.repo.CreateDeleteRequest(ctx, userID, reason, verificationMethod); err != nil {
		return nil, err
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
		hash, err := s.repo.GetUserPasswordHash(ctx, userID)
		if err != nil {
			return nil, err
		}
		if hash == "" || bcrypt.CompareHashAndPassword([]byte(hash), []byte(req.Password)) != nil {
			return nil, ErrInvalidCredentials
		}
	case "otp":
		if req.OTP == "" {
			return nil, ErrInvalidCredentials
		}
		return nil, ErrInvalidCredentials
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
	if err := s.repo.RevokeAllSessions(ctx, userID, now); err != nil {
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

func (s *Service) ApplyDueFeedLimits(ctx context.Context) error {
	return s.repo.ApplyDueFeedLimits(ctx, time.Now())
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

func (s *Service) IsBlockedBetween(ctx context.Context, actorID, targetID string) (bool, error) {
	return s.repo.IsBlockedBetween(ctx, actorID, targetID)
}
