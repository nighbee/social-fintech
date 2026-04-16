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

// NewMinioClient initializes a MinIO client and ensures buckets exist.
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

	buckets := []string{cfg.Bucket}
	if cfg.TempBucket != "" {
		buckets = append(buckets, cfg.TempBucket)
	}

	for _, b := range buckets {
		exists, err := cli.BucketExists(context.Background(), b)
		if err != nil {
			return nil, err
		}
		if !exists {
			if err := cli.MakeBucket(context.Background(), b, minio.MakeBucketOptions{}); err != nil {
				return nil, err
			}
		}

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
		}`, b)
		if err := cli.SetBucketPolicy(context.Background(), b, policy); err != nil {
			return nil, err
		}
	}

	return &Client{
		minio:     cli,
		bucket:    cfg.Bucket,
		publicURL: strings.TrimRight(cfg.PublicURL, "/"),
	}, nil
}

// Upload uploads object to a bucket and returns public URL.
// If bucketName is empty, it uses the default bucket.
func (c *Client) Upload(ctx context.Context, bucketName, objectName string, reader io.Reader, size int64, contentType string) (string, error) {
	if bucketName == "" {
		bucketName = c.bucket
	}

	_, err := c.minio.PutObject(ctx, bucketName, objectName, reader, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", err
	}

	if c.publicURL != "" {
		return fmt.Sprintf("%s/%s/%s", c.publicURL, bucketName, objectName), nil
	}
	return fmt.Sprintf("%s/%s", bucketName, objectName), nil
}

// Download retrieves an object from a bucket.
func (c *Client) Download(ctx context.Context, bucketName, objectName string) (io.ReadCloser, error) {
	if bucketName == "" {
		bucketName = c.bucket
	}
	return c.minio.GetObject(ctx, bucketName, objectName, minio.GetObjectOptions{})
}

// Delete removes an object from a bucket.
func (c *Client) Delete(ctx context.Context, bucketName, objectName string) error {
	if bucketName == "" {
		bucketName = c.bucket
	}
	return c.minio.RemoveObject(ctx, bucketName, objectName, minio.RemoveObjectOptions{})
}
