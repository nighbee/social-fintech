-- Migration: allow media-only comments
-- Description: replaces strict content-only check with media-aware rule.

ALTER TABLE post_comments
    DROP CONSTRAINT IF EXISTS post_comments_content_check;

ALTER TABLE post_comments
    ADD CONSTRAINT post_comments_content_check
    CHECK (
        LENGTH(TRIM(content)) > 0
        OR media_attachment IS NOT NULL
        OR (media_attachments IS NOT NULL AND jsonb_array_length(media_attachments) > 0)
    );
