package handlers

import (
	"encoding/json"
	"net/http"

	"diploma/backend/internal/middleware"
	"diploma/backend/internal/repository"
	"diploma/backend/internal/response"
)

type UserHandler struct {
	userRepo *repository.UserRepo
}

func NewUserHandler(userRepo *repository.UserRepo) *UserHandler {
	return &UserHandler{userRepo: userRepo}
}

func (h *UserHandler) Me(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	user, err := h.userRepo.GetByID(r.Context(), claims.UserID)
	if err != nil {
		response.Error(w, http.StatusNotFound, "user not found")
		return
	}
	response.OK(w, user)
}

func (h *UserHandler) UpdateMe(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	var input struct {
		AvatarURL *string `json:"avatar_url"`
		Bio       *string `json:"bio"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid request body")
		return
	}

	user, err := h.userRepo.UpdateProfile(r.Context(), claims.UserID, input.AvatarURL, input.Bio)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.OK(w, user)
}

func (h *UserHandler) GetByUsername(w http.ResponseWriter, r *http.Request) {
	username := r.PathValue("username")
	user, err := h.userRepo.GetByUsername(r.Context(), username)
	if err != nil {
		response.Error(w, http.StatusNotFound, "user not found")
		return
	}
	// не показываем email чужим
	user.Email = ""
	response.OK(w, user)
}
