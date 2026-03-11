-- Migration: Add media_attachments to post_comments
-- Description: Supports multiple media items per comment while preserving legacy media_attachment.

ALTER TABLE post_comments
    ADD COLUMN IF NOT EXISTS media_attachments JSONB;

UPDATE post_comments
SET media_attachments = CASE
    WHEN media_attachment IS NULL THEN '[]'::jsonb
    ELSE jsonb_build_array(media_attachment)
END
WHERE media_attachments IS NULL;

COMMENT ON COLUMN post_comments.media_attachments IS 'Optional array of media objects for comment attachments';
