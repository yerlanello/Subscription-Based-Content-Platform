package storage

import (
	"context"
	"fmt"
	"io"
	"mime/multipart"
	"path/filepath"

	"github.com/google/uuid"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

type MinioStorage struct {
	client     *minio.Client
	bucket     string
	publicURL  string
}

func NewMinioStorage(endpoint, accessKey, secretKey, bucket, publicURL string) (*MinioStorage, error) {
	client, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: false,
	})
	if err != nil {
		return nil, err
	}

	ctx := context.Background()
	exists, err := client.BucketExists(ctx, bucket)
	if err != nil {
		return nil, err
	}
	if !exists {
		if err := client.MakeBucket(ctx, bucket, minio.MakeBucketOptions{}); err != nil {
			return nil, err
		}
		// делаем бакет публичным на чтение
		policy := fmt.Sprintf(`{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":["*"]},"Action":["s3:GetObject"],"Resource":["arn:aws:s3:::%s/*"]}]}`, bucket)
		_ = client.SetBucketPolicy(ctx, bucket, policy)
	}

	return &MinioStorage{client: client, bucket: bucket, publicURL: publicURL}, nil
}

func (s *MinioStorage) UploadAvatar(ctx context.Context, file multipart.File, header *multipart.FileHeader) (string, error) {
	ext := filepath.Ext(header.Filename)
	if ext == "" {
		ext = ".jpg"
	}
	objectName := fmt.Sprintf("avatars/%s%s", uuid.New().String(), ext)

	_, err := s.client.PutObject(ctx, s.bucket, objectName, file, header.Size, minio.PutObjectOptions{
		ContentType: header.Header.Get("Content-Type"),
	})
	if err != nil {
		return "", err
	}

	return fmt.Sprintf("%s/%s/%s", s.publicURL, s.bucket, objectName), nil
}

func (s *MinioStorage) UploadFile(ctx context.Context, reader io.Reader, objectName, contentType string, size int64) (string, error) {
	_, err := s.client.PutObject(ctx, s.bucket, objectName, reader, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%s/%s/%s", s.publicURL, s.bucket, objectName), nil
}
