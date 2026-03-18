package repository

import (
	"context"
	"errors"

	"diploma/backend/internal/models"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type CreatorRepo struct {
	db *pgxpool.Pool
}

func NewCreatorRepo(db *pgxpool.Pool) *CreatorRepo {
	return &CreatorRepo{db: db}
}

func (r *CreatorRepo) Create(ctx context.Context, userID uuid.UUID, displayName string) (*models.CreatorProfile, error) {
	p := &models.CreatorProfile{}
	err := r.db.QueryRow(ctx, `
		INSERT INTO creator_profiles (user_id, display_name)
		VALUES ($1, $2)
		RETURNING id, user_id, display_name, description, cover_url, category,
		          subscription_price_cents, subscription_description, created_at, updated_at
	`, userID, displayName).Scan(
		&p.ID, &p.UserID, &p.DisplayName, &p.Description, &p.CoverURL, &p.Category,
		&p.SubscriptionPriceCents, &p.SubscriptionDescription, &p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		if isUniqueViolation(err) {
			return nil, ErrConflict
		}
		return nil, err
	}
	return p, nil
}

func (r *CreatorRepo) GetByUserID(ctx context.Context, userID uuid.UUID) (*models.CreatorProfile, error) {
	return r.scanOne(ctx, `
		SELECT id, user_id, display_name, description, cover_url, category,
		       subscription_price_cents, subscription_description, created_at, updated_at
		FROM creator_profiles WHERE user_id = $1
	`, userID)
}

func (r *CreatorRepo) Update(ctx context.Context, userID uuid.UUID,
	displayName, description, coverURL, category, subDescription *string,
	priceCents *int,
) (*models.CreatorProfile, error) {
	p := &models.CreatorProfile{}
	err := r.db.QueryRow(ctx, `
		UPDATE creator_profiles SET
			display_name             = COALESCE($2, display_name),
			description              = COALESCE($3, description),
			cover_url                = COALESCE($4, cover_url),
			category                 = COALESCE($5, category),
			subscription_description = COALESCE($6, subscription_description),
			subscription_price_cents = COALESCE($7, subscription_price_cents),
			updated_at               = NOW()
		WHERE user_id = $1
		RETURNING id, user_id, display_name, description, cover_url, category,
		          subscription_price_cents, subscription_description, created_at, updated_at
	`, userID, displayName, description, coverURL, category, subDescription, priceCents).Scan(
		&p.ID, &p.UserID, &p.DisplayName, &p.Description, &p.CoverURL, &p.Category,
		&p.SubscriptionPriceCents, &p.SubscriptionDescription, &p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return p, nil
}

// List — каталог авторов с пагинацией
func (r *CreatorRepo) List(ctx context.Context, limit, offset int, category *string) ([]models.CreatorWithProfile, error) {
	query := `
		SELECT u.id, u.username, u.avatar_url, u.bio, u.created_at,
		       cp.id, cp.display_name, cp.description, cp.cover_url, cp.category,
		       cp.subscription_price_cents, cp.subscription_description, cp.created_at
		FROM users u
		JOIN creator_profiles cp ON cp.user_id = u.id
	`
	args := []any{limit, offset}
	if category != nil {
		query += ` WHERE cp.category = $3`
		args = append(args, *category)
	}
	query += ` ORDER BY cp.created_at DESC LIMIT $1 OFFSET $2`

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []models.CreatorWithProfile
	for rows.Next() {
		var c models.CreatorWithProfile
		err := rows.Scan(
			&c.User.ID, &c.User.Username, &c.User.AvatarURL, &c.User.Bio, &c.User.CreatedAt,
			&c.Profile.ID, &c.Profile.DisplayName, &c.Profile.Description,
			&c.Profile.CoverURL, &c.Profile.Category,
			&c.Profile.SubscriptionPriceCents, &c.Profile.SubscriptionDescription, &c.Profile.CreatedAt,
		)
		if err != nil {
			return nil, err
		}
		results = append(results, c)
	}
	return results, nil
}

func (r *CreatorRepo) scanOne(ctx context.Context, query string, args ...any) (*models.CreatorProfile, error) {
	p := &models.CreatorProfile{}
	err := r.db.QueryRow(ctx, query, args...).Scan(
		&p.ID, &p.UserID, &p.DisplayName, &p.Description, &p.CoverURL, &p.Category,
		&p.SubscriptionPriceCents, &p.SubscriptionDescription, &p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return p, nil
}
