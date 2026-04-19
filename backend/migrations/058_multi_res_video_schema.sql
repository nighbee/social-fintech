-- Migration: Multi-Resolution Video Schema
-- Description: Renames media URL columns to explicit 1080p and 480p tiers

ALTER TABLE post_media RENAME COLUMN media_url TO video_1080p_url;
ALTER TABLE post_media RENAME COLUMN media_url_low TO video_480p_url;

-- Update Documentation
COMMENT ON COLUMN post_media.video_1080p_url IS 'URL for the 1080p (high-resolution) version of the video or primary image URL';
COMMENT ON COLUMN post_media.video_480p_url IS 'URL for the 480p (low-resolution) version of the video';
COMMENT ON COLUMN post_media.thumbnail_url IS 'URL for the generated video thumbnail (JPG)';
