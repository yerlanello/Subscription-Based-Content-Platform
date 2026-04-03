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

func (r *SubscriptionRepo) CountByCreator(ctx context.Context, creatorID uuid.UUID) (int, error) {
	var count int
	err := r.db.QueryRow(ctx, `
		SELECT COUNT(*) FROM subscriptions WHERE creator_id = $1 AND status = 'active'
	`, creatorID).Scan(&count)
	return count, err
}

func (r *SubscriptionRepo) GetBillingHistory(ctx context.Context, patronID uuid.UUID) ([]models.BillingSubscription, error) {
	rows, err := r.db.Query(ctx, `
		SELECT s.id, s.status, s.started_at, s.ends_at,
		       u.username, cp.display_name, u.avatar_url, cp.subscription_price_cents
		FROM subscriptions s
		JOIN users u ON u.id = s.creator_id
		JOIN creator_profiles cp ON cp.user_id = s.creator_id
		WHERE s.patron_id = $1
		ORDER BY s.started_at DESC
	`, patronID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []models.BillingSubscription
	for rows.Next() {
		var b models.BillingSubscription
		if err := rows.Scan(
			&b.ID, &b.Status, &b.StartedAt, &b.EndsAt,
			&b.CreatorUsername, &b.CreatorName, &b.CreatorAvatar, &b.PriceCents,
		); err != nil {
			return nil, err
		}
		result = append(result, b)
	}
	return result, nil
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

func (r *FollowRepo) CountByCreator(ctx context.Context, creatorID uuid.UUID) (int, error) {
	var count int
	err := r.db.QueryRow(ctx, `
		SELECT COUNT(*) FROM follows WHERE creator_id = $1
	`, creatorID).Scan(&count)
	return count, err
}

func (r *FollowRepo) IsFollowing(ctx context.Context, followerID, creatorID uuid.UUID) (bool, error) {
	var exists bool
	err := r.db.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM follows WHERE follower_id = $1 AND creator_id = $2)
	`, followerID, creatorID).Scan(&exists)
	return exists, err
}

func (r *FollowRepo) GetFollowing(ctx context.Context, followerID uuid.UUID) ([]models.CreatorWithProfile, error) {
	rows, err := r.db.Query(ctx, `
		SELECT u.id, u.username, u.email, u.role, u.avatar_url, u.bio, u.created_at, u.updated_at,
		       cp.id, cp.user_id, cp.display_name, cp.description, cp.cover_url, cp.category,
		       cp.subscription_price_cents, cp.subscription_description, cp.created_at, cp.updated_at
		FROM follows f
		JOIN users u ON u.id = f.creator_id
		JOIN creator_profiles cp ON cp.user_id = f.creator_id
		WHERE f.follower_id = $1
		ORDER BY f.created_at DESC
	`, followerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []models.CreatorWithProfile
	for rows.Next() {
		var c models.CreatorWithProfile
		if err := rows.Scan(
			&c.User.ID, &c.User.Username, &c.User.Email, &c.User.Role,
			&c.User.AvatarURL, &c.User.Bio, &c.User.CreatedAt, &c.User.UpdatedAt,
			&c.Profile.ID, &c.Profile.UserID, &c.Profile.DisplayName, &c.Profile.Description,
			&c.Profile.CoverURL, &c.Profile.Category, &c.Profile.SubscriptionPriceCents,
			&c.Profile.SubscriptionDescription, &c.Profile.CreatedAt, &c.Profile.UpdatedAt,
		); err != nil {
			return nil, err
		}
		result = append(result, c)
	}
	return result, nil
}

// helper
func isUniqueViolation(err error) bool {
	var pgErr interface{ SQLState() string }
	if errors.As(err, &pgErr) {
		return pgErr.SQLState() == "23505"
	}
	return false
}
