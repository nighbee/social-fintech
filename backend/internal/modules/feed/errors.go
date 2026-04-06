package feed

import "errors"

var (
	// ── Feed State / Anti-Doomscroll ─────────────────────────────────────
	// ErrInvalidDelta is returned when the client reports a non-positive delta_seconds.
	ErrInvalidDelta = errors.New("delta_seconds must be greater than 0")
	// ErrInvalidDeviceID is returned when the client does not provide device_id.
	ErrInvalidDeviceID = errors.New("device_id is required")
	// ErrInvalidFeedContext is returned when sync payload does not include feed context.
	ErrInvalidFeedContext = errors.New("feed context is required: is_feed_active or app_section")
	// ErrInvalidAppSection is returned when app_section is not supported.
	ErrInvalidAppSection = errors.New("invalid app_section")

	// ErrDeltaTooLarge is returned when the reported delta exceeds the server-side
	// anti-cheat ceiling (real elapsed + NetworkBufferSeconds).
	ErrDeltaTooLarge = errors.New("delta_seconds exceeds maximum allowed window")

	// ErrUserInCooldown is returned when the user has already exceeded their feed limit
	// and the server refuses to accumulate further active time.
	ErrUserInCooldown = errors.New("user_in_cooldown: feed limit reached")

	// ErrInvalidFeedTimeLimit is returned when the client sends a feed_time_limit_mins
	// value that is not one of the allowed choices (0, 20, 30, 40).
	ErrInvalidFeedTimeLimit = errors.New("feed_time_limit_mins must be 0 (no limit), 20, 30, or 40")

	// ── Posts ─────────────────────────────────────────────────────────────
	// ErrPostNotFound is returned when a post ID does not match any persisted post.
	ErrPostNotFound = errors.New("post_not_found")

	// ErrPostRequiresMedia is returned when a CreatePost request has neither
	// a caption nor any media attachments.
	ErrPostRequiresMedia = errors.New("post_requires_content_or_media")

	// ErrInvalidVisibility is returned when the post visibility value is not
	// one of the allowed options (ANYONE, ALLIES_ONLY).
	ErrInvalidVisibility = errors.New("invalid_visibility: must be ANYONE or ALLIES_ONLY")

	// ErrInvalidCommentPermission is returned when the comment_permission value
	// is not one of ANYONE, ALLIES_ONLY, or NO_ONE.
	ErrInvalidCommentPermission = errors.New("invalid_comment_permission: must be ANYONE, ALLIES_ONLY, or NO_ONE")

	// ErrPostAlreadyDeleted is returned when an operation targets a post that
	// was already soft-deleted.
	ErrPostAlreadyDeleted = errors.New("post_already_deleted")

	// ErrNotPostAuthor is returned when a mutation (delete, edit) is attempted
	// by a user who is not the original post author.
	ErrNotPostAuthor = errors.New("not_post_author: only the original author can perform this action")

	// ErrInvalidPostUpdate is returned when a post update payload contains
	// no supported fields.
	ErrInvalidPostUpdate = errors.New("invalid_post_update_payload")

	// ErrPublishingRestricted is returned when author publication is temporarily blocked
	// by policy escalation (e.g. repeated actioned post removals).
	ErrPublishingRestricted = errors.New("publishing_restricted")

	// ── Comments ─────────────────────────────────────────────────────────
	// ErrCommentNotFound is returned when a specified comment does not exist.
	ErrCommentNotFound = errors.New("comment_not_found")

	// ErrCommentRequiresText is returned when a CreateComment request has
	// neither text content nor a media attachment.
	ErrCommentRequiresText = errors.New("comment_requires_text_or_media")

	// ErrCommentNotAllowed is returned when the post's comment_permission
	// prevents the requesting user from commenting (e.g. NO_ONE, or ALLIES_ONLY
	// when the requester is not an ally).
	ErrCommentNotAllowed = errors.New("comment_not_allowed")

	// ErrCommentNestingTooDeep is reserved for optional depth limits in threaded comments.
	ErrCommentNestingTooDeep = errors.New("comment_nesting_too_deep")

	// ErrNotCommentAuthor is returned when a delete is attempted by a user
	// who is not the comment author.
	ErrNotCommentAuthor = errors.New("not_comment_author: only the original author can delete this comment")
	// ErrInvalidReportReason is returned when comment report reason is empty.
	ErrInvalidReportReason = errors.New("invalid_report_reason")
	// ErrDuplicateReport is returned when reporter already reported the same target.
	ErrDuplicateReport = errors.New("duplicate_report")
	// ErrReportRateLimited is returned when reporter exceeds allowed report rate.
	ErrReportRateLimited = errors.New("report_rate_limited")
	// ErrInvalidReportTargetType is returned when moderation target type is not supported.
	ErrInvalidReportTargetType = errors.New("invalid_report_target_type")
	// ErrInvalidReportDecision is returned when moderation decision is not supported.
	ErrInvalidReportDecision = errors.New("invalid_report_decision")

	// ── Likes ─────────────────────────────────────────────────────────────
	// ErrLikeQueueFull is returned when the Redis write-behind buffer for likes
	// is unavailable or overflowing.
	ErrLikeQueueFull = errors.New("like_queue_full: try again shortly")

	// ── Seals ─────────────────────────────────────────────────────────────
	// ErrInvalidSealAmount is returned when the seal amount is not exactly 1.
	ErrInvalidSealAmount = errors.New("seal_amount must be exactly 1")

	// ErrInsufficientBalance is returned when the sender does not have enough
	// Silver to cover the requested seal amount.
	ErrInsufficientBalance = errors.New("insufficient_silver_balance")

	// ErrSealOwnPost is returned when a user attempts to seal their own post.
	ErrSealOwnPost = errors.New("cannot_seal_own_post")

	// ── Media ─────────────────────────────────────────────────────────────
	// ErrMediaTooLarge is returned when an uploaded file exceeds the size limit.
	ErrMediaTooLarge = errors.New("media_too_large: file exceeds maximum allowed size")

	// ErrUnsupportedMediaType is returned when the uploaded file MIME type is
	// not in the allowlist (image/jpeg, image/png, image/webp, video/mp4).
	ErrUnsupportedMediaType = errors.New("unsupported_media_type")

	// ErrTooManyMediaAttachments is returned when a post or comment exceeds
	// the maximum number of allowed media items (e.g. > 10 for a post).
	ErrTooManyMediaAttachments = errors.New("too_many_media_attachments: maximum is 10 items per post")

	// ── Visibility / Privacy ──────────────────────────────────────────────
	// ErrFeedNotAuthorized is returned when the viewer is not allowed to see
	// the requested post (e.g. ALLIES_ONLY and viewer is not an ally).
	ErrFeedNotAuthorized = errors.New("feed_not_authorized: post is restricted to allies only")

	// ── Rate Limiting ─────────────────────────────────────────────────────
	// ErrRateLimitExceeded is returned when a user exceeds the allowed
	// request frequency for a feed action (e.g. too many comments per minute).
	ErrRateLimitExceeded = errors.New("rate_limit_exceeded: slow down and try again")
)
