-- Migration: Add video processing fields to post_media
-- Description: Supports asynchronous video transcoding and multiple resolutions

ALTER TABLE post_media 
ADD COLUMN IF NOT EXISTS media_url_low TEXT,
ADD COLUMN IF NOT EXISTS processing_status VARCHAR(20) DEFAULT 'ready',
ADD COLUMN IF NOT EXISTS original_path TEXT;

-- Index for background worker lookup to quickly find pending tasks
CREATE INDEX IF NOT EXISTS idx_post_media_processing ON post_media(processing_status) 
WHERE processing_status = 'processing';

-- Documentation
COMMENT ON COLUMN post_media.media_url_low IS 'URL for the 480p (low-resolution) version of the video';
COMMENT ON COLUMN post_media.processing_status IS 'Status of video transcoding (ready, processing, failed)';
COMMENT ON COLUMN post_media.original_path IS 'Path to the raw uploaded file in the temp bucket';
