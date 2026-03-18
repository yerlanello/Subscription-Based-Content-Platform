package handlers

import (
	"encoding/json"
	"errors"
	"net/http"

	"diploma/backend/internal/middleware"
	"diploma/backend/internal/response"
	"diploma/backend/internal/service"
)

type AuthHandler struct {
	authSvc *service.AuthService
}

func NewAuthHandler(authSvc *service.AuthService) *AuthHandler {
	return &AuthHandler{authSvc: authSvc}
}

func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Username string `json:"username"`
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if input.Username == "" || input.Email == "" || input.Password == "" {
		response.Error(w, http.StatusBadRequest, "username, email and password are required")
		return
	}
	if len(input.Password) < 8 {
		response.Error(w, http.StatusBadRequest, "password must be at least 8 characters")
		return
	}

	result, err := h.authSvc.Register(r.Context(), service.RegisterInput{
		Username: input.Username,
		Email:    input.Email,
		Password: input.Password,
	})
	if err != nil {
		if errors.Is(err, service.ErrUserExists) {
			response.Error(w, http.StatusConflict, "user with this email or username already exists")
			return
		}
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}

	response.Created(w, map[string]any{
		"user":          result.User,
		"access_token":  result.AccessToken,
		"refresh_token": result.RefreshToken,
	})
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid request body")
		return
	}

	result, err := h.authSvc.Login(r.Context(), input.Email, input.Password)
	if err != nil {
		if errors.Is(err, service.ErrInvalidCredentials) {
			response.Error(w, http.StatusUnauthorized, "invalid email or password")
			return
		}
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}

	response.OK(w, map[string]any{
		"user":          result.User,
		"access_token":  result.AccessToken,
		"refresh_token": result.RefreshToken,
	})
}

func (h *AuthHandler) Refresh(w http.ResponseWriter, r *http.Request) {
	var input struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil || input.RefreshToken == "" {
		response.Error(w, http.StatusBadRequest, "refresh_token is required")
		return
	}

	result, err := h.authSvc.Refresh(r.Context(), input.RefreshToken)
	if err != nil {
		if errors.Is(err, service.ErrTokenExpired) || errors.Is(err, service.ErrTokenInvalid) {
			response.Error(w, http.StatusUnauthorized, "invalid or expired refresh token")
			return
		}
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}

	response.OK(w, map[string]any{
		"access_token":  result.AccessToken,
		"refresh_token": result.RefreshToken,
	})
}

func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	var input struct {
		RefreshToken string `json:"refresh_token"`
	}
	json.NewDecoder(r.Body).Decode(&input)
	if input.RefreshToken != "" {
		h.authSvc.Logout(r.Context(), input.RefreshToken)
	}
	response.NoContent(w)
}

func (h *AuthHandler) LogoutAll(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	h.authSvc.LogoutAll(r.Context(), claims.UserID)
	response.NoContent(w)
}
