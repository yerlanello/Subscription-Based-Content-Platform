package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"

	"diploma/backend/internal/middleware"
	"diploma/backend/internal/repository"
	"diploma/backend/internal/response"
	"diploma/backend/internal/storage"
)

type UserHandler struct {
	userRepo *repository.UserRepo
	storage  *storage.MinioStorage
}

func NewUserHandler(userRepo *repository.UserRepo, storage *storage.MinioStorage) *UserHandler {
	return &UserHandler{userRepo: userRepo, storage: storage}
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

func (h *UserHandler) UploadAvatar(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)

	if err := r.ParseMultipartForm(5 << 20); err != nil { // 5 MB
		response.Error(w, http.StatusBadRequest, "file too large (max 5MB)")
		return
	}

	file, header, err := r.FormFile("avatar")
	if err != nil {
		response.Error(w, http.StatusBadRequest, "avatar file is required")
		return
	}
	defer file.Close()

	// Проверяем тип файла
	ct := header.Header.Get("Content-Type")
	if ct != "image/jpeg" && ct != "image/png" && ct != "image/webp" && ct != "image/gif" {
		ct = "image/jpeg"
	}

	if h.storage == nil {
		response.Error(w, http.StatusServiceUnavailable, "storage not configured")
		return
	}

	url, err := h.storage.UploadAvatar(r.Context(), file, header)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, fmt.Sprintf("upload failed: %v", err))
		return
	}

	user, err := h.userRepo.UpdateProfile(r.Context(), claims.UserID, &url, nil)
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
