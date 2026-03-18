package repository

import (
	"context"
	"errors"

	"diploma/backend/internal/models"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type SubscriptionRepo struct {
	db *pgxpool.Pool
}

func NewSubscriptionRepo(db *pgxpool.Pool) *SubscriptionRepo {
	return &SubscriptionRepo{db: db}
}

func (r *SubscriptionRepo) Subscribe(ctx context.Context, patronID, creatorID uuid.UUID) (*models.Subscription, error) {
	s := &models.Subscription{}
	err := r.db.QueryRow(ctx, `
		INSERT INTO subscriptions (patron_id, creator_id)
		VALUES ($1, $2)
		ON CONFLICT (patron_id, creator_id) DO UPDATE SET status = 'active', ends_at = NULL
		RETURNING id, patron_id, creator_id, status, started_at, ends_at
	`, patronID, creatorID).Scan(
		&s.ID, &s.PatronID, &s.CreatorID, &s.Status, &s.StartedAt, &s.EndsAt,
	)
	if err != nil {
		return nil, err
	}
	return s, nil
}

func (r *SubscriptionRepo) Unsubscribe(ctx context.Context, patronID, creatorID uuid.UUID) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE subscriptions SET status = 'cancelled', ends_at = NOW()
		WHERE patron_id = $1 AND creator_id = $2 AND status = 'active'
	`, patronID, creatorID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *SubscriptionRepo) IsSubscribed(ctx context.Context, patronID, creatorID uuid.UUID) (bool, error) {
	var exists bool
	err := r.db.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1 FROM subscriptions
			WHERE patron_id = $1 AND creator_id = $2 AND status = 'active'
		)
	`, patronID, creatorID).Scan(&exists)
	return exists, err
}

func (r *SubscriptionRepo) GetByPatron(ctx context.Context, patronID uuid.UUID) ([]models.Subscription, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, patron_id, creator_id, status, started_at, ends_at
		FROM subscriptions WHERE patron_id = $1 ORDER BY started_at DESC
	`, patronID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var subs []models.Subscription
	for rows.Next() {
		var s models.Subscription
		if err := rows.Scan(&s.ID, &s.PatronID, &s.CreatorID, &s.Status, &s.StartedAt, &s.EndsAt); err != nil {
			return nil, err
		}
		subs = append(subs, s)
	}
	return subs, nil
}

// Follow / Unfollow

type FollowRepo struct {
	db *pgxpool.Pool
}

func NewFollowRepo(db *pgxpool.Pool) *FollowRepo {
	return &FollowRepo{db: db}
}

func (r *FollowRepo) Follow(ctx context.Context, followerID, creatorID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO follows (follower_id, creator_id) VALUES ($1, $2) ON CONFLICT DO NOTHING
	`, followerID, creatorID)
	return err
}

func (r *FollowRepo) Unfollow(ctx context.Context, followerID, creatorID uuid.UUID) error {
	tag, err := r.db.Exec(ctx, `
		DELETE FROM follows WHERE follower_id = $1 AND creator_id = $2
	`, followerID, creatorID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *FollowRepo) IsFollowing(ctx context.Context, followerID, creatorID uuid.UUID) (bool, error) {
	var exists bool
	err := r.db.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM follows WHERE follower_id = $1 AND creator_id = $2)
	`, followerID, creatorID).Scan(&exists)
	return exists, err
}

// helper
func isUniqueViolation(err error) bool {
	var pgErr interface{ SQLState() string }
	if errors.As(err, &pgErr) {
		return pgErr.SQLState() == "23505"
	}
	return false
}
