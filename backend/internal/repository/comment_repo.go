package repository

import (
	"context"
	"errors"
	"sort"

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

func (r *CommentRepo) GetByPost(ctx context.Context, postID, userID uuid.UUID) ([]models.Comment, error) {
	rows, err := r.db.Query(ctx, `
		SELECT c.id, c.post_id, c.user_id, c.parent_id, c.content, c.created_at, c.updated_at,
		       u.id, u.username, u.avatar_url,
		       (SELECT COUNT(*) FROM comment_likes WHERE comment_id = c.id) AS likes_count,
		       EXISTS(SELECT 1 FROM comment_likes WHERE comment_id = c.id AND user_id = $2) AS is_liked
		FROM comments c
		JOIN users u ON u.id = c.user_id
		WHERE c.post_id = $1
		ORDER BY c.created_at ASC
	`, postID, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var all []models.Comment
	for rows.Next() {
		var c models.Comment
		c.Author = &models.PublicUser{}
		if err := rows.Scan(
			&c.ID, &c.PostID, &c.UserID, &c.ParentID, &c.Content, &c.CreatedAt, &c.UpdatedAt,
			&c.Author.ID, &c.Author.Username, &c.Author.AvatarURL,
			&c.LikesCount, &c.IsLiked,
		); err != nil {
			return nil, err
		}
		all = append(all, c)
	}

	byID := make(map[uuid.UUID]*models.Comment, len(all))
	for i := range all {
		byID[all[i].ID] = &all[i]
	}

	// Flatten: walk up parent chain to find root, then attach there
	for i := range all {
		if all[i].ParentID == nil {
			continue
		}
		parentID := *all[i].ParentID
		for {
			parent, ok := byID[parentID]
			if !ok {
				break
			}
			if parent.ParentID == nil {
				parent.Replies = append(parent.Replies, all[i])
				break
			}
			parentID = *parent.ParentID
		}
	}

	// Collect root comments and sort by likes DESC (most liked first)
	var result []models.Comment
	for i := range all {
		if all[i].ParentID == nil {
			result = append(result, *byID[all[i].ID])
		}
	}
	sort.Slice(result, func(i, j int) bool {
		return result[i].LikesCount > result[j].LikesCount
	})
	return result, nil
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

func (r *CommentRepo) LikeComment(ctx context.Context, commentID, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO comment_likes (user_id, comment_id) VALUES ($1, $2) ON CONFLICT DO NOTHING
	`, userID, commentID)
	return err
}

func (r *CommentRepo) UnlikeComment(ctx context.Context, commentID, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM comment_likes WHERE user_id = $1 AND comment_id = $2`, userID, commentID)
	return err
}

func (r *CommentRepo) CommentLikesCount(ctx context.Context, commentID uuid.UUID) (int, error) {
	var count int
	err := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM comment_likes WHERE comment_id = $1`, commentID).Scan(&count)
	return count, err
}

func (r *CommentRepo) IsCommentLiked(ctx context.Context, commentID, userID uuid.UUID) (bool, error) {
	var exists bool
	err := r.db.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM comment_likes WHERE comment_id = $1 AND user_id = $2)
	`, commentID, userID).Scan(&exists)
	return exists, err
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
