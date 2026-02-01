package storage

import (
	"context"
	"fmt"
	"io"
	"mime/multipart"
	"path/filepath"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

type Config struct {
	Endpoint          string
	AccessKey         string
	SecretKey         string
	UseSSL            bool
	BucketAvatars     string
	BucketPosts       string
	BucketVideos      string
	MaxFileSize       int64
	AllowedImageTypes []string
	AllowedVideoTypes []string
	URLExpiry         time.Duration
}

type Service struct {
	client *minio.Client
	config Config
}

type UploadResult struct {
	URL         string
	Key         string
	Bucket      string
	Size        int64
	ContentType string
}

func New(cfg Config) (*Service, error) {
	client, err := minio.New(cfg.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
		Secure: cfg.UseSSL,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create minio client: %w", err)
	}

	s := &Service{
		client: client,
		config: cfg,
	}

	// Ensure buckets exist
	if err := s.ensureBuckets(context.Background()); err != nil {
		return nil, fmt.Errorf("failed to ensure buckets: %w", err)
	}

	return s, nil
}

func (s *Service) ensureBuckets(ctx context.Context) error {
	buckets := []string{
		s.config.BucketAvatars,
		s.config.BucketPosts,
		s.config.BucketVideos,
	}

	for _, bucket := range buckets {
		exists, err := s.client.BucketExists(ctx, bucket)
		if err != nil {
			return fmt.Errorf("failed to check bucket %s: %w", bucket, err)
		}
		if !exists {
			if err := s.client.MakeBucket(ctx, bucket, minio.MakeBucketOptions{}); err != nil {
				return fmt.Errorf("failed to create bucket %s: %w", bucket, err)
			}
		}

		// Set bucket policy to public read
		policy := fmt.Sprintf(`{
			"Version": "2012-10-17",
			"Statement": [{
				"Effect": "Allow",
				"Principal": {"AWS": ["*"]},
				"Action": ["s3:GetObject"],
				"Resource": ["arn:aws:s3:::%s/*"]
			}]
		}`, bucket)

		if err := s.client.SetBucketPolicy(ctx, bucket, policy); err != nil {
			return fmt.Errorf("failed to set bucket policy for %s: %w", bucket, err)
		}
	}

	return nil
}

func (s *Service) UploadAvatar(ctx context.Context, file *multipart.FileHeader) (*UploadResult, error) {
	return s.uploadFile(ctx, file, s.config.BucketAvatars, "avatars/")
}

func (s *Service) UploadPostImage(ctx context.Context, file *multipart.FileHeader) (*UploadResult, error) {
	return s.uploadFile(ctx, file, s.config.BucketPosts, "images/")
}

func (s *Service) UploadPostVideo(ctx context.Context, file *multipart.FileHeader) (*UploadResult, error) {
	return s.uploadFile(ctx, file, s.config.BucketVideos, "videos/")
}

func (s *Service) uploadFile(ctx context.Context, fileHeader *multipart.FileHeader, bucket, prefix string) (*UploadResult, error) {
	// Validate file size
	if fileHeader.Size > s.config.MaxFileSize {
		return nil, fmt.Errorf("file size exceeds maximum allowed size of %d bytes", s.config.MaxFileSize)
	}

	// Validate content type
	contentType := fileHeader.Header.Get("Content-Type")
	if !s.isAllowedContentType(contentType) {
		return nil, fmt.Errorf("content type %s is not allowed", contentType)
	}

	// Open file
	file, err := fileHeader.Open()
	if err != nil {
		return nil, fmt.Errorf("failed to open file: %w", err)
	}
	defer file.Close()

	// Generate unique key
	ext := filepath.Ext(fileHeader.Filename)
	key := fmt.Sprintf("%s%s%s", prefix, uuid.NewString(), ext)

	// Upload to MinIO
	info, err := s.client.PutObject(ctx, bucket, key, file, fileHeader.Size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to upload file to minio: %w", err)
	}

	// Generate public URL
	url := s.getPublicURL(bucket, key)

	return &UploadResult{
		URL:         url,
		Key:         key,
		Bucket:      bucket,
		Size:        info.Size,
		ContentType: contentType,
	}, nil
}

func (s *Service) DeleteFile(ctx context.Context, bucket, key string) error {
	return s.client.RemoveObject(ctx, bucket, key, minio.RemoveObjectOptions{})
}

func (s *Service) DeleteAvatar(ctx context.Context, key string) error {
	return s.DeleteFile(ctx, s.config.BucketAvatars, key)
}

func (s *Service) DeletePostMedia(ctx context.Context, key string, isVideo bool) error {
	bucket := s.config.BucketPosts
	if isVideo {
		bucket = s.config.BucketVideos
	}
	return s.DeleteFile(ctx, bucket, key)
}

func (s *Service) GetPresignedURL(ctx context.Context, bucket, key string) (string, error) {
	url, err := s.client.PresignedGetObject(ctx, bucket, key, s.config.URLExpiry, nil)
	if err != nil {
		return "", fmt.Errorf("failed to generate presigned url: %w", err)
	}
	return url.String(), nil
}

func (s *Service) getPublicURL(bucket, key string) string {
	protocol := "http"
	if s.config.UseSSL {
		protocol = "https"
	}
	return fmt.Sprintf("%s://%s/%s/%s", protocol, s.config.Endpoint, bucket, key)
}

func (s *Service) isAllowedContentType(contentType string) bool {
	// Check image types
	for _, allowed := range s.config.AllowedImageTypes {
		if contentType == allowed {
			return true
		}
	}

	// Check video types
	for _, allowed := range s.config.AllowedVideoTypes {
		if contentType == allowed {
			return true
		}
	}

	return false
}

func (s *Service) CopyFile(ctx context.Context, srcBucket, srcKey, dstBucket, dstKey string) error {
	src := minio.CopySrcOptions{
		Bucket: srcBucket,
		Object: srcKey,
	}

	dst := minio.CopyDestOptions{
		Bucket: dstBucket,
		Object: dstKey,
	}

	_, err := s.client.CopyObject(ctx, dst, src)
	return err
}

// Helper to extract key from full URL
func ExtractKeyFromURL(url string) string {
	parts := strings.Split(url, "/")
	if len(parts) >= 2 {
		return strings.Join(parts[len(parts)-2:], "/")
	}
	return ""
}

// Stream file from MinIO
func (s *Service) GetFile(ctx context.Context, bucket, key string) (io.ReadCloser, error) {
	return s.client.GetObject(ctx, bucket, key, minio.GetObjectOptions{})
}
