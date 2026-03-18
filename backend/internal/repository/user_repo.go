package repository

import (
	"context"
	"errors"
	"time"

	"diploma/backend/internal/models"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("not found")
var ErrConflict = errors.New("already exists")

type UserRepo struct {
	db *pgxpool.Pool
}

func NewUserRepo(db *pgxpool.Pool) *UserRepo {
	return &UserRepo{db: db}
}

func (r *UserRepo) Create(ctx context.Context, username, email, passwordHash string) (*models.User, error) {
	user := &models.User{}
	err := r.db.QueryRow(ctx, `
		INSERT INTO users (username, email, password_hash)
		VALUES ($1, $2, $3)
		RETURNING id, username, email, password_hash, role, avatar_url, bio, created_at, updated_at
	`, username, email, passwordHash).Scan(
		&user.ID, &user.Username, &user.Email, &user.PasswordHash,
		&user.Role, &user.AvatarURL, &user.Bio, &user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		if isUniqueViolation(err) {
			return nil, ErrConflict
		}
		return nil, err
	}
	return user, nil
}

func (r *UserRepo) GetByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	user := &models.User{}
	err := r.db.QueryRow(ctx, `
		SELECT id, username, email, password_hash, role, avatar_url, bio, created_at, updated_at
		FROM users WHERE id = $1
	`, id).Scan(
		&user.ID, &user.Username, &user.Email, &user.PasswordHash,
		&user.Role, &user.AvatarURL, &user.Bio, &user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return user, nil
}

func (r *UserRepo) GetByEmail(ctx context.Context, email string) (*models.User, error) {
	user := &models.User{}
	err := r.db.QueryRow(ctx, `
		SELECT id, username, email, password_hash, role, avatar_url, bio, created_at, updated_at
		FROM users WHERE email = $1
	`, email).Scan(
		&user.ID, &user.Username, &user.Email, &user.PasswordHash,
		&user.Role, &user.AvatarURL, &user.Bio, &user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return user, nil
}

func (r *UserRepo) GetByUsername(ctx context.Context, username string) (*models.User, error) {
	user := &models.User{}
	err := r.db.QueryRow(ctx, `
		SELECT id, username, email, password_hash, role, avatar_url, bio, created_at, updated_at
		FROM users WHERE username = $1
	`, username).Scan(
		&user.ID, &user.Username, &user.Email, &user.PasswordHash,
		&user.Role, &user.AvatarURL, &user.Bio, &user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return user, nil
}

func (r *UserRepo) UpdateProfile(ctx context.Context, id uuid.UUID, avatarURL, bio *string) (*models.User, error) {
	user := &models.User{}
	err := r.db.QueryRow(ctx, `
		UPDATE users SET avatar_url = COALESCE($2, avatar_url), bio = COALESCE($3, bio), updated_at = NOW()
		WHERE id = $1
		RETURNING id, username, email, password_hash, role, avatar_url, bio, created_at, updated_at
	`, id, avatarURL, bio).Scan(
		&user.ID, &user.Username, &user.Email, &user.PasswordHash,
		&user.Role, &user.AvatarURL, &user.Bio, &user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return user, nil
}

func (r *UserRepo) SetRole(ctx context.Context, id uuid.UUID, role models.UserRole) error {
	_, err := r.db.Exec(ctx, `UPDATE users SET role = $2, updated_at = NOW() WHERE id = $1`, id, role)
	return err
}

// --- Refresh Tokens ---

func (r *UserRepo) SaveRefreshToken(ctx context.Context, userID uuid.UUID, tokenHash string, expiresAt time.Time) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)
	`, userID, tokenHash, expiresAt)
	return err
}

func (r *UserRepo) GetRefreshToken(ctx context.Context, tokenHash string) (*models.RefreshToken, error) {
	rt := &models.RefreshToken{}
	err := r.db.QueryRow(ctx, `
		SELECT id, user_id, token_hash, expires_at, created_at
		FROM refresh_tokens WHERE token_hash = $1
	`, tokenHash).Scan(&rt.ID, &rt.UserID, &rt.TokenHash, &rt.ExpiresAt, &rt.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return rt, nil
}

func (r *UserRepo) DeleteRefreshToken(ctx context.Context, tokenHash string) error {
	_, err := r.db.Exec(ctx, `DELETE FROM refresh_tokens WHERE token_hash = $1`, tokenHash)
	return err
}

func (r *UserRepo) DeleteAllRefreshTokens(ctx context.Context, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM refresh_tokens WHERE user_id = $1`, userID)
	return err
}
