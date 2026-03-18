package service

import (
	"context"
	"errors"
	"time"

	"diploma/backend/internal/auth"
	"diploma/backend/internal/models"
	"diploma/backend/internal/repository"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrUserExists         = errors.New("user already exists")
	ErrTokenExpired       = errors.New("token expired")
	ErrTokenInvalid       = errors.New("token invalid")
)

type AuthService struct {
	userRepo  *repository.UserRepo
	jwtSecret string
}

func NewAuthService(userRepo *repository.UserRepo, jwtSecret string) *AuthService {
	return &AuthService{userRepo: userRepo, jwtSecret: jwtSecret}
}

type RegisterInput struct {
	Username string
	Email    string
	Password string
}

type AuthResult struct {
	User         *models.User
	AccessToken  string
	RefreshToken string
}

func (s *AuthService) Register(ctx context.Context, input RegisterInput) (*AuthResult, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	user, err := s.userRepo.Create(ctx, input.Username, input.Email, string(hash))
	if err != nil {
		if errors.Is(err, repository.ErrConflict) {
			return nil, ErrUserExists
		}
		return nil, err
	}

	return s.issueTokens(ctx, user)
}

func (s *AuthService) Login(ctx context.Context, email, password string) (*AuthResult, error) {
	user, err := s.userRepo.GetByEmail(ctx, email)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, ErrInvalidCredentials
		}
		return nil, err
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		return nil, ErrInvalidCredentials
	}

	return s.issueTokens(ctx, user)
}

func (s *AuthService) Refresh(ctx context.Context, rawToken string) (*AuthResult, error) {
	hash := auth.HashToken(rawToken)
	rt, err := s.userRepo.GetRefreshToken(ctx, hash)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, ErrTokenInvalid
		}
		return nil, err
	}

	if time.Now().After(rt.ExpiresAt) {
		_ = s.userRepo.DeleteRefreshToken(ctx, hash)
		return nil, ErrTokenExpired
	}

	user, err := s.userRepo.GetByID(ctx, rt.UserID)
	if err != nil {
		return nil, err
	}

	// rotate — удаляем старый, выдаём новый
	_ = s.userRepo.DeleteRefreshToken(ctx, hash)
	return s.issueTokens(ctx, user)
}

func (s *AuthService) Logout(ctx context.Context, rawToken string) error {
	hash := auth.HashToken(rawToken)
	return s.userRepo.DeleteRefreshToken(ctx, hash)
}

func (s *AuthService) LogoutAll(ctx context.Context, userID uuid.UUID) error {
	return s.userRepo.DeleteAllRefreshTokens(ctx, userID)
}

func (s *AuthService) issueTokens(ctx context.Context, user *models.User) (*AuthResult, error) {
	accessToken, err := auth.GenerateAccessToken(user.ID, user.Username, string(user.Role), s.jwtSecret)
	if err != nil {
		return nil, err
	}

	rawRefresh, hashRefresh, expiresAt, err := auth.GenerateRefreshToken()
	if err != nil {
		return nil, err
	}

	if err := s.userRepo.SaveRefreshToken(ctx, user.ID, hashRefresh, expiresAt); err != nil {
		return nil, err
	}

	return &AuthResult{
		User:         user,
		AccessToken:  accessToken,
		RefreshToken: rawRefresh,
	}, nil
}
