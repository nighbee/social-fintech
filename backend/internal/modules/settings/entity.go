package settings

import (
	"context"
	"time"
)

type UserSettings struct {
	UserID                      string     `db:"user_id" json:"user_id"`
	FeedTimeLimitCurrentMins    int        `db:"feed_time_limit_current_mins" json:"feed_time_limit_current_mins"`
	FeedTimeLimitPendingMins    *int       `db:"feed_time_limit_pending_mins" json:"feed_time_limit_pending_mins,omitempty"`
	FeedTimeLimitPendingApplyAt *time.Time `db:"feed_time_limit_pending_apply_at" json:"feed_time_limit_pending_apply_at,omitempty"`

	MessagesWhoCanMessage      string `db:"messages_who_can_message" json:"messages_who_can_message"`
	MessagesReadStatusEnabled  bool   `db:"messages_read_status_enabled" json:"messages_read_status_enabled"`
	MessagesSafeModeEnabled    bool   `db:"messages_safe_mode_enabled" json:"messages_safe_mode_enabled"`
	CommentsWhoCanComment      string `db:"comments_who_can_comment" json:"comments_who_can_comment"`
	CommentsFilterUnwanted     bool   `db:"comments_filter_unwanted_enabled" json:"comments_filter_unwanted_enabled"`
	MentionsWhoCanMention      string `db:"mentions_who_can_mention" json:"mentions_who_can_mention"`
	ParticipateDistrictRanking bool   `db:"participate_district_ranking" json:"participate_district_ranking"`
}

const (
	MessagePrivacyEveryone   = "everyone"
	MessagePrivacyNoOne      = "no_one"
	MessagePrivacyAlliesOnly = "allies_only"

	FeedLimitNoLimit = 0
	FeedLimit20      = 20
	FeedLimit40      = 40
	FeedLimit60      = 60

	TwoFAMethodSMS           = "sms"
	TwoFAMethodEmail         = "email"
	TwoFAMethodAuthenticator = "authenticator"
)

type SecurityOverviewResponse struct {
	TwoFAEnabled       bool     `json:"two_fa_enabled"`
	TwoFAMethods       []string `json:"two_fa_methods"`
	ActiveSessions     int      `json:"active_sessions"`
	CurrentSessionID   string   `json:"current_session_id,omitempty"`
	PasswordLoginReady bool     `json:"password_login_ready"`
}

type FeedSettingsResponse struct {
	CurrentMins    int        `json:"current_mins"`
	PendingMins    *int       `json:"pending_mins,omitempty"`
	PendingApplyAt *time.Time `json:"pending_apply_at,omitempty"`
}

type PatchFeedSettingsRequest struct {
	NewLimitMins int `json:"new_limit_mins"`
}

type PatchMessagesSettingsRequest struct {
	WhoCanMessage string `json:"who_can_message"`
	ReadStatus    *bool  `json:"read_status"`
	SafeMode      *bool  `json:"safe_mode"`
}

type PatchCommentsSettingsRequest struct {
	WhoCanComment  string `json:"who_can_comment"`
	FilterUnwanted *bool  `json:"filter_unwanted"`
}

type PatchMentionsSettingsRequest struct {
	WhoCanMention string `json:"who_can_mention"`
}

type AddKeywordRequest struct {
	Keyword string `json:"keyword"`
}

type KeywordItem struct {
	ID      string    `db:"id" json:"id"`
	Keyword string    `db:"keyword" json:"keyword"`
	AddedAt time.Time `db:"added_at" json:"added_at"`
}

type MessagesSettingsResponse struct {
	WhoCanMessage string        `json:"who_can_message"`
	ReadStatus    bool          `json:"read_status"`
	SafeMode      bool          `json:"safe_mode"`
	Keywords      []KeywordItem `json:"keywords"`
}

type CommentsSettingsResponse struct {
	WhoCanComment  string `json:"who_can_comment"`
	FilterUnwanted bool   `json:"filter_unwanted"`
}

type MentionsSettingsResponse struct {
	WhoCanMention string `json:"who_can_mention"`
}

type InteractionsSettingsResponse struct {
	Messages MessagesSettingsResponse `json:"messages"`
	Comments CommentsSettingsResponse `json:"comments"`
	Mentions MentionsSettingsResponse `json:"mentions"`
}

type SessionItem struct {
	ID           string    `json:"id"`
	DeviceName   string    `json:"device_name"`
	OS           string    `json:"os"`
	IP           string    `json:"ip"`
	LastActiveAt time.Time `json:"last_active_at"`
	IsCurrent    bool      `json:"is_current"`
}

type ChangePasswordRequest struct {
	CurrentPassword string `json:"current_password"`
	NewPassword     string `json:"new_password"`
}

type TwoFAEnableRequest struct {
	Methods []string `json:"methods"`
}

type TwoFADisableRequest struct {
	CurrentPassword string `json:"current_password"`
}

type TwoFAStatusResponse struct {
	Enabled bool     `json:"enabled"`
	Methods []string `json:"methods"`
	Secret  string   `json:"authenticator_secret,omitempty"`
}

type DeleteAccountReasonRequest struct {
	Reason string `json:"reason"`
}

type DeleteAccountReasonResponse struct {
	VerificationMethod string `json:"verification_method"`
}

type DeleteAccountVerifyRequest struct {
	Password string `json:"password,omitempty"`
	OTP      string `json:"otp,omitempty"`
}

type DeleteAccountVerifyResponse struct {
	VerificationToken string    `json:"verification_token"`
	ExpiresAt         time.Time `json:"expires_at"`
}

type DeleteAccountFinalizeRequest struct {
	VerificationToken string `json:"verification_token"`
}

type BugReportRequest struct {
	Description string `json:"description"`
	Screenshot  string `json:"screenshot,omitempty"`
	AppVersion  string `json:"app_version,omitempty"`
	DeviceOS    string `json:"device_os,omitempty"`
}

type BlockedUserItem struct {
	UserID       string    `json:"user_id" db:"user_id"`
	Username     string    `json:"username" db:"username"`
	AvatarURL    string    `json:"avatar_url" db:"avatar_url"`
	LastActiveAt time.Time `json:"last_active_at" db:"last_active_at"`
}

type BlockedUsersResponse struct {
	Items      []BlockedUserItem `json:"items"`
	NextCursor string            `json:"next_cursor,omitempty"`
}

// PublicService is exported for cross-module usage.
type PublicService interface {
	GetFeedTimeLimit(ctx context.Context, userID string) (int, error)
	GetCommentPrivacy(ctx context.Context, userID string) (string, bool, error)
	GetMessagePrivacy(ctx context.Context, userID string) (string, bool, bool, error)
	GetMentionsPrivacy(ctx context.Context, userID string) (string, error)
	IsBlockedBetween(ctx context.Context, actorID, targetID string) (bool, error)
}
