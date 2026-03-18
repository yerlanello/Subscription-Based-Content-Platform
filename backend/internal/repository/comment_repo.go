package repository

import (
	"context"
	"errors"

	"diploma/backend/internal/models"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type CommentRepo struct {
	db *pgxpool.Pool
}

func NewCommentRepo(db *pgxpool.Pool) *CommentRepo {
	return &CommentRepo{db: db}
}

func (r *CommentRepo) Create(ctx context.Context, postID, userID uuid.UUID, parentID *uuid.UUID, content string) (*models.Comment, error) {
	c := &models.Comment{}
	err := r.db.QueryRow(ctx, `
		INSERT INTO comments (post_id, user_id, parent_id, content)
		VALUES ($1, $2, $3, $4)
		RETURNING id, post_id, user_id, parent_id, content, created_at, updated_at
	`, postID, userID, parentID, content).Scan(
		&c.ID, &c.PostID, &c.UserID, &c.ParentID, &c.Content, &c.CreatedAt, &c.UpdatedAt,
	)
	return c, err
}

func (r *CommentRepo) GetByPost(ctx context.Context, postID uuid.UUID) ([]models.Comment, error) {
	rows, err := r.db.Query(ctx, `
		SELECT c.id, c.post_id, c.user_id, c.parent_id, c.content, c.created_at, c.updated_at,
		       u.id, u.username, u.avatar_url
		FROM comments c
		JOIN users u ON u.id = c.user_id
		WHERE c.post_id = $1
		ORDER BY c.created_at ASC
	`, postID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var comments []models.Comment
	for rows.Next() {
		var c models.Comment
		c.Author = &models.PublicUser{}
		if err := rows.Scan(
			&c.ID, &c.PostID, &c.UserID, &c.ParentID, &c.Content, &c.CreatedAt, &c.UpdatedAt,
			&c.Author.ID, &c.Author.Username, &c.Author.AvatarURL,
		); err != nil {
			return nil, err
		}
		comments = append(comments, c)
	}
	return comments, nil
}

func (r *CommentRepo) Delete(ctx context.Context, id, userID uuid.UUID) error {
	tag, err := r.db.Exec(ctx, `DELETE FROM comments WHERE id = $1 AND user_id = $2`, id, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *CommentRepo) GetByID(ctx context.Context, id uuid.UUID) (*models.Comment, error) {
	c := &models.Comment{}
	err := r.db.QueryRow(ctx, `
		SELECT id, post_id, user_id, parent_id, content, created_at, updated_at
		FROM comments WHERE id = $1
	`, id).Scan(&c.ID, &c.PostID, &c.UserID, &c.ParentID, &c.Content, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return c, nil
}
