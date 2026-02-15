package storage

import (
	"context"
	"fmt"
	"io"
	"strings"

	"github.com/brightbund-backend/internal/config"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

// Client wraps MinIO SDK for simple uploads.
type Client struct {
	minio     *minio.Client
	bucket    string
	publicURL string
}

// NewMinioClient initializes a MinIO client and ensures bucket exists.
func NewMinioClient(cfg config.StorageConfig) (*Client, error) {
	if cfg.Endpoint == "" || cfg.AccessKey == "" || cfg.SecretKey == "" || cfg.Bucket == "" {
		return nil, fmt.Errorf("storage config is incomplete")
	}

	cli, err := minio.New(cfg.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
		Secure: cfg.UseSSL,
	})
	if err != nil {
		return nil, err
	}

	exists, err := cli.BucketExists(context.Background(), cfg.Bucket)
	if err != nil {
		return nil, err
	}
	if !exists {
		if err := cli.MakeBucket(context.Background(), cfg.Bucket, minio.MakeBucketOptions{}); err != nil {
			return nil, err
		}
	}
	// Make avatar objects publicly readable for direct URL access from mobile/web.
	// This is required because profile.avatar_url is stored as a static URL.
	policy := fmt.Sprintf(`{
		"Version":"2012-10-17",
		"Statement":[
			{
				"Effect":"Allow",
				"Principal":{"AWS":["*"]},
				"Action":["s3:GetObject"],
				"Resource":["arn:aws:s3:::%s/*"]
			}
		]
	}`, cfg.Bucket)
	if err := cli.SetBucketPolicy(context.Background(), cfg.Bucket, policy); err != nil {
		return nil, err
	}

	return &Client{
		minio:     cli,
		bucket:    cfg.Bucket,
		publicURL: strings.TrimRight(cfg.PublicURL, "/"),
	}, nil
}

// Upload uploads object to MinIO and returns public URL.
func (c *Client) Upload(ctx context.Context, objectName string, reader io.Reader, size int64, contentType string) (string, error) {
	_, err := c.minio.PutObject(ctx, c.bucket, objectName, reader, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", err
	}

	if c.publicURL != "" {
		return fmt.Sprintf("%s/%s/%s", c.publicURL, c.bucket, objectName), nil
	}
	return fmt.Sprintf("%s/%s", c.bucket, objectName), nil
}
