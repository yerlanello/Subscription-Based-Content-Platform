package repository

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrTokenInvalid = errors.New("token invalid or expired")

type TokenRepo struct {
	db *pgxpool.Pool
}

func NewTokenRepo(db *pgxpool.Pool) *TokenRepo {
	return &TokenRepo{db: db}
}

func generateToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

// --- Email verification ---

func (r *TokenRepo) CreateVerificationToken(ctx context.Context, userID uuid.UUID) (string, error) {
	token, err := generateToken()
	if err != nil {
		return "", err
	}
	expiresAt := time.Now().Add(24 * time.Hour)

	// Delete old tokens for this user first
	_, err = r.db.Exec(ctx, `DELETE FROM email_verification_tokens WHERE user_id = $1`, userID)
	if err != nil {
		return "", err
	}

	_, err = r.db.Exec(ctx, `
		INSERT INTO email_verification_tokens (token, user_id, expires_at)
		VALUES ($1, $2, $3)
	`, token, userID, expiresAt)
	if err != nil {
		return "", err
	}
	return token, nil
}

func (r *TokenRepo) VerifyEmailToken(ctx context.Context, token string) (uuid.UUID, error) {
	var userID uuid.UUID
	var expiresAt time.Time
	err := r.db.QueryRow(ctx, `
		SELECT user_id, expires_at FROM email_verification_tokens WHERE token = $1
	`, token).Scan(&userID, &expiresAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return uuid.Nil, ErrTokenInvalid
		}
		return uuid.Nil, err
	}

	if time.Now().After(expiresAt) {
		_, _ = r.db.Exec(ctx, `DELETE FROM email_verification_tokens WHERE token = $1`, token)
		return uuid.Nil, ErrTokenInvalid
	}

	_, err = r.db.Exec(ctx, `DELETE FROM email_verification_tokens WHERE token = $1`, token)
	if err != nil {
		return uuid.Nil, err
	}
	return userID, nil
}

// --- Password reset ---

func (r *TokenRepo) CreatePasswordResetToken(ctx context.Context, userID uuid.UUID) (string, error) {
	token, err := generateToken()
	if err != nil {
		return "", err
	}
	expiresAt := time.Now().Add(1 * time.Hour)

	// Delete old tokens for this user first
	_, err = r.db.Exec(ctx, `DELETE FROM password_reset_tokens WHERE user_id = $1`, userID)
	if err != nil {
		return "", err
	}

	_, err = r.db.Exec(ctx, `
		INSERT INTO password_reset_tokens (token, user_id, expires_at)
		VALUES ($1, $2, $3)
	`, token, userID, expiresAt)
	if err != nil {
		return "", err
	}
	return token, nil
}

func (r *TokenRepo) VerifyPasswordResetToken(ctx context.Context, token string) (uuid.UUID, error) {
	var userID uuid.UUID
	var expiresAt time.Time
	err := r.db.QueryRow(ctx, `
		SELECT user_id, expires_at FROM password_reset_tokens WHERE token = $1
	`, token).Scan(&userID, &expiresAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return uuid.Nil, ErrTokenInvalid
		}
		return uuid.Nil, err
	}

	if time.Now().After(expiresAt) {
		_, _ = r.db.Exec(ctx, `DELETE FROM password_reset_tokens WHERE token = $1`, token)
		return uuid.Nil, ErrTokenInvalid
	}

	_, err = r.db.Exec(ctx, `DELETE FROM password_reset_tokens WHERE token = $1`, token)
	if err != nil {
		return uuid.Nil, err
	}
	return userID, nil
}
