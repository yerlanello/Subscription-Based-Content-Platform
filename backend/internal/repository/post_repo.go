package repository

import (
	"context"
	"errors"

	"diploma/backend/internal/models"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PostRepo struct {
	db *pgxpool.Pool
}

func NewPostRepo(db *pgxpool.Pool) *PostRepo {
	return &PostRepo{db: db}
}

func (r *PostRepo) Create(ctx context.Context, creatorID uuid.UUID, title string, content *string, postType models.PostType, isFree bool) (*models.Post, error) {
	post := &models.Post{}
	err := r.db.QueryRow(ctx, `
		INSERT INTO posts (creator_id, title, content, type, is_free)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, creator_id, title, content, type, is_free, is_published, published_at, created_at, updated_at
	`, creatorID, title, content, postType, isFree).Scan(
		&post.ID, &post.CreatorID, &post.Title, &post.Content, &post.Type,
		&post.IsFree, &post.IsPublished, &post.PublishedAt, &post.CreatedAt, &post.UpdatedAt,
	)
	return post, err
}

func (r *PostRepo) GetByID(ctx context.Context, id uuid.UUID) (*models.Post, error) {
	post := &models.Post{}
	creator := &models.PublicUser{}
	err := r.db.QueryRow(ctx, `
		SELECT p.id, p.creator_id, p.title, p.content, p.type, p.is_free, p.is_published, p.published_at, p.created_at, p.updated_at,
		       u.id, u.username, u.avatar_url
		FROM posts p
		JOIN users u ON u.id = p.creator_id
		WHERE p.id = $1
	`, id).Scan(
		&post.ID, &post.CreatorID, &post.Title, &post.Content, &post.Type,
		&post.IsFree, &post.IsPublished, &post.PublishedAt, &post.CreatedAt, &post.UpdatedAt,
		&creator.ID, &creator.Username, &creator.AvatarURL,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	post.Creator = creator
	return post, nil
}

func (r *PostRepo) Update(ctx context.Context, id uuid.UUID, title, content *string, isFree *bool) (*models.Post, error) {
	post := &models.Post{}
	err := r.db.QueryRow(ctx, `
		UPDATE posts SET
			title   = COALESCE($2, title),
			content = COALESCE($3, content),
			is_free = COALESCE($4, is_free),
			updated_at = NOW()
		WHERE id = $1
		RETURNING id, creator_id, title, content, type, is_free, is_published, published_at, created_at, updated_at
	`, id, title, content, isFree).Scan(
		&post.ID, &post.CreatorID, &post.Title, &post.Content, &post.Type,
		&post.IsFree, &post.IsPublished, &post.PublishedAt, &post.CreatedAt, &post.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return post, nil
}

func (r *PostRepo) Publish(ctx context.Context, id uuid.UUID) (*models.Post, error) {
	post := &models.Post{}
	err := r.db.QueryRow(ctx, `
		UPDATE posts SET is_published = true, published_at = NOW(), updated_at = NOW()
		WHERE id = $1
		RETURNING id, creator_id, title, content, type, is_free, is_published, published_at, created_at, updated_at
	`, id).Scan(
		&post.ID, &post.CreatorID, &post.Title, &post.Content, &post.Type,
		&post.IsFree, &post.IsPublished, &post.PublishedAt, &post.CreatedAt, &post.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return post, nil
}

func (r *PostRepo) Unpublish(ctx context.Context, id uuid.UUID) (*models.Post, error) {
	post := &models.Post{}
	err := r.db.QueryRow(ctx, `
		UPDATE posts SET is_published = false, updated_at = NOW()
		WHERE id = $1
		RETURNING id, creator_id, title, content, type, is_free, is_published, published_at, created_at, updated_at
	`, id).Scan(
		&post.ID, &post.CreatorID, &post.Title, &post.Content, &post.Type,
		&post.IsFree, &post.IsPublished, &post.PublishedAt, &post.CreatedAt, &post.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return post, nil
}

func (r *PostRepo) Delete(ctx context.Context, id uuid.UUID) error {
	tag, err := r.db.Exec(ctx, `DELETE FROM posts WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ListByCreator — посты конкретного автора
func (r *PostRepo) ListByCreator(ctx context.Context, creatorID uuid.UUID, limit, offset int, onlyPublished bool) ([]models.Post, error) {
	query := `
		SELECT p.id, p.creator_id, p.title, p.content, p.type, p.is_free, p.is_published, p.published_at, p.created_at, p.updated_at,
		       (SELECT COUNT(*) FROM likes    WHERE post_id = p.id) AS likes_count,
		       (SELECT COUNT(*) FROM comments WHERE post_id = p.id) AS comments_count
		FROM posts p WHERE p.creator_id = $1
	`
	if onlyPublished {
		query += ` AND p.is_published = true`
	}
	query += ` ORDER BY p.created_at DESC LIMIT $2 OFFSET $3`

	rows, err := r.db.Query(ctx, query, creatorID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanPostsWithCounts(rows)
}

// Feed — посты от авторов, на которых подписан пользователь
func (r *PostRepo) Feed(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Post, error) {
	rows, err := r.db.Query(ctx, `
		SELECT p.id, p.creator_id, p.title, p.content, p.type, p.is_free, p.is_published, p.published_at, p.created_at, p.updated_at,
		       (SELECT COUNT(*) FROM likes    WHERE post_id = p.id) AS likes_count,
		       (SELECT COUNT(*) FROM comments WHERE post_id = p.id) AS comments_count
		FROM posts p
		JOIN subscriptions s ON s.creator_id = p.creator_id
		WHERE s.patron_id = $1 AND s.status = 'active' AND p.is_published = true
		ORDER BY p.published_at DESC
		LIMIT $2 OFFSET $3
	`, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanPostsWithCounts(rows)
}

// LikesCount
func (r *PostRepo) LikesCount(ctx context.Context, postID uuid.UUID) (int, error) {
	var count int
	err := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM likes WHERE post_id = $1`, postID).Scan(&count)
	return count, err
}

func (r *PostRepo) IsLiked(ctx context.Context, postID, userID uuid.UUID) (bool, error) {
	var exists bool
	err := r.db.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM likes WHERE post_id = $1 AND user_id = $2)
	`, postID, userID).Scan(&exists)
	return exists, err
}

func (r *PostRepo) Like(ctx context.Context, postID, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO likes (post_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING
	`, postID, userID)
	return err
}

func (r *PostRepo) Unlike(ctx context.Context, postID, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM likes WHERE post_id = $1 AND user_id = $2`, postID, userID)
	return err
}

// Attachments
func (r *PostRepo) AddAttachment(ctx context.Context, postID uuid.UUID, url, mimeType string, size int64) (*models.PostAttachment, error) {
	a := &models.PostAttachment{}
	err := r.db.QueryRow(ctx, `
		INSERT INTO post_attachments (post_id, url, mime_type, size_bytes)
		VALUES ($1, $2, $3, $4)
		RETURNING id, post_id, url, mime_type, size_bytes, created_at
	`, postID, url, mimeType, size).Scan(
		&a.ID, &a.PostID, &a.URL, &a.MimeType, &a.SizeBytes, &a.CreatedAt,
	)
	return a, err
}

func (r *PostRepo) DeleteAttachment(ctx context.Context, attachmentID, requesterID uuid.UUID) error {
	// Проверяем что requester — автор поста через JOIN
	tag, err := r.db.Exec(ctx, `
		DELETE FROM post_attachments pa
		USING posts p
		WHERE pa.id = $1 AND pa.post_id = p.id AND p.creator_id = $2
	`, attachmentID, requesterID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *PostRepo) GetAttachments(ctx context.Context, postID uuid.UUID) ([]models.PostAttachment, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, post_id, url, mime_type, size_bytes, created_at
		FROM post_attachments WHERE post_id = $1
	`, postID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var attachments []models.PostAttachment
	for rows.Next() {
		var a models.PostAttachment
		if err := rows.Scan(&a.ID, &a.PostID, &a.URL, &a.MimeType, &a.SizeBytes, &a.CreatedAt); err != nil {
			return nil, err
		}
		attachments = append(attachments, a)
	}
	return attachments, nil
}

func scanPosts(rows pgx.Rows) ([]models.Post, error) {
	var posts []models.Post
	for rows.Next() {
		var p models.Post
		if err := rows.Scan(
			&p.ID, &p.CreatorID, &p.Title, &p.Content, &p.Type,
			&p.IsFree, &p.IsPublished, &p.PublishedAt, &p.CreatedAt, &p.UpdatedAt,
		); err != nil {
			return nil, err
		}
		posts = append(posts, p)
	}
	return posts, nil
}

func scanPostsWithCounts(rows pgx.Rows) ([]models.Post, error) {
	var posts []models.Post
	for rows.Next() {
		var p models.Post
		if err := rows.Scan(
			&p.ID, &p.CreatorID, &p.Title, &p.Content, &p.Type,
			&p.IsFree, &p.IsPublished, &p.PublishedAt, &p.CreatedAt, &p.UpdatedAt,
			&p.LikesCount, &p.CommentsCount,
		); err != nil {
			return nil, err
		}
		posts = append(posts, p)
	}
	return posts, nil
}
