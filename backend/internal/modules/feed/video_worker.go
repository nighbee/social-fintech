package feed

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/brightbund-backend/internal/platform/logger"
	"github.com/google/uuid"
	"github.com/hibiken/asynq"
	"go.uber.org/zap"
)

type VideoWorker struct {
	repo       Repository
	storage    ObjectStorage
	ffmpegPath string
	tempBucket string
}

func NewVideoWorker(repo Repository, storage ObjectStorage, ffmpegPath, tempBucket string) *VideoWorker {
	if ffmpegPath == "" {
		ffmpegPath = "ffmpeg" // system path default
	}
	return &VideoWorker{
		repo:       repo,
		storage:    storage,
		ffmpegPath: ffmpegPath,
		tempBucket: tempBucket,
	}
}

func (w *VideoWorker) ProcessVideoTask(ctx context.Context, t *asynq.Task) error {
	var payload VideoProcessingPayload
	if err := json.Unmarshal(t.Payload(), &payload); err != nil {
		return fmt.Errorf("failed to unmarshal payload: %w", err)
	}

	logger.Info("processing video task", 
		zap.String("media_id", payload.MediaID.String()),
		zap.String("original_path", payload.OriginalPath))

	// 1. Download original file
	rawReader, err := w.storage.Download(ctx, w.tempBucket, payload.OriginalPath)
	if err != nil {
		return fmt.Errorf("failed to download raw file: %w", err)
	}
	defer rawReader.Close()

	tempDir, err := os.MkdirTemp("", "video-proc-*")
	if err != nil {
		return fmt.Errorf("failed to create temp dir: %w", err)
	}
	defer os.RemoveAll(tempDir)

	inputPath := filepath.Join(tempDir, "input"+filepath.Ext(payload.OriginalPath))
	out, err := os.Create(inputPath)
	if err != nil {
		return fmt.Errorf("failed to create input file: %w", err)
	}
	if _, err := io.Copy(out, rawReader); err != nil {
		out.Close()
		return fmt.Errorf("failed to save input file: %w", err)
	}
	out.Close()

	// 2. Define output paths
	baseName := uuid.New().String()
	highResPath := filepath.Join(tempDir, baseName+"_1080p.mp4")
	lowResPath := filepath.Join(tempDir, baseName+"_480p.mp4")
	thumbPath := filepath.Join(tempDir, baseName+"_thumb.jpg")

	// 3. Optimized FFmpeg Sequence
	// 3a. Extract Thumbnail first (instantaneous)
	thumbArgs := []string{"-ss", "00:00:01", "-i", inputPath, "-vframes", "1", "-q:v", "2", thumbPath}
	if err := w.runFFmpeg(ctx, thumbArgs...); err != nil {
		// Fallback to start of video if 1s fails
		_ = w.runFFmpeg(ctx, "-i", inputPath, "-vframes", "1", "-q:v", "2", thumbPath)
	}

	// 3b. Generate 1080p Master (High Quality)
	highArgs := []string{
		"-i", inputPath,
		"-vf", "scale='min(1080,iw)':-2",
		"-c:v", "libx264", "-preset", "medium", "-crf", "23",
		"-movflags", "+faststart",
		"-c:a", "aac", "-b:a", "128k",
		highResPath,
	}
	if err := w.runFFmpeg(ctx, highArgs...); err != nil {
		return fmt.Errorf("failed to generate 1080p master: %w", err)
	}

	// 3c. Generate 480p Proxy from the 1080p Master (Faster than raw re-encode)
	lowArgs := []string{
		"-i", highResPath,
		"-vf", "scale='min(480,iw)':-2",
		"-c:v", "libx264", "-preset", "medium", "-crf", "28",
		"-movflags", "+faststart",
		"-c:a", "aac", "-b:a", "64k",
		lowResPath,
	}
	if err := w.runFFmpeg(ctx, lowArgs...); err != nil {
		return fmt.Errorf("failed to generate 480p proxy: %w", err)
	}

	// 4. Upload Tiered Media to Main Bucket
	highObjName := "media/" + baseName + "_1080p.mp4"
	lowObjName := "media/" + baseName + "_480p.mp4"
	thumbObjName := "media/" + baseName + "_thumb.jpg"

	highURL, err := w.uploadFile(ctx, highResPath, highObjName, "video/mp4")
	if err != nil {
		return fmt.Errorf("failed to upload 1080p: %w", err)
	}
	lowURL, err := w.uploadFile(ctx, lowResPath, lowObjName, "video/mp4")
	if err != nil {
		// Log but continue, 1080p is the master
		logger.Error("failed to upload 480p proxy", zap.Error(err))
	}
	
	var thumbURL string
	if _, err := os.Stat(thumbPath); err == nil {
		thumbURL, _ = w.uploadFile(ctx, thumbPath, thumbObjName, "image/jpeg")
	}

	// 5. Update Repository with all resolution tiers
	err = w.repo.UpdateMediaProcessingResult(ctx, payload.MediaID, highURL, lowURL, thumbURL, ProcessingStatusReady)
	if err != nil {
		return fmt.Errorf("failed to update db with processing results: %w", err)
	}

	// 6. Cleanup temp-uploads
	_ = w.storage.Delete(ctx, w.tempBucket, payload.OriginalPath)

	logger.Info("video processing completed", 
		zap.String("media_id", payload.MediaID.String()),
		zap.String("high_url", highURL))

	return nil
}

func (w *VideoWorker) runFFmpeg(ctx context.Context, args ...string) error {
	cmd := exec.CommandContext(ctx, w.ffmpegPath, args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("ffmpeg error: %v, output: %s", err, string(output))
	}
	return nil
}

func (w *VideoWorker) uploadFile(ctx context.Context, localPath, objectName, contentType string) (string, error) {
	file, err := os.Open(localPath)
	if err != nil {
		return "", fmt.Errorf("failed to open processed file: %w", err)
	}
	defer file.Close()

	stat, _ := file.Stat()
	url, err := w.storage.Upload(ctx, "", objectName, file, stat.Size(), contentType)
	if err != nil {
		return "", fmt.Errorf("failed to upload processed file: %w", err)
	}
	return url, nil
}
