package handlers

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	"diploma/backend/internal/middleware"
	"diploma/backend/internal/models"
	"diploma/backend/internal/repository"
	"diploma/backend/internal/response"
)

type CreatorHandler struct {
	creatorRepo *repository.CreatorRepo
	userRepo    *repository.UserRepo
	subRepo     *repository.SubscriptionRepo
	followRepo  *repository.FollowRepo
}

func NewCreatorHandler(
	creatorRepo *repository.CreatorRepo,
	userRepo *repository.UserRepo,
	subRepo *repository.SubscriptionRepo,
	followRepo *repository.FollowRepo,
) *CreatorHandler {
	return &CreatorHandler{creatorRepo: creatorRepo, userRepo: userRepo, subRepo: subRepo, followRepo: followRepo}
}

// BecomeCreator — создать профиль автора
func (h *CreatorHandler) BecomeCreator(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)

	var input struct {
		DisplayName string `json:"display_name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil || input.DisplayName == "" {
		response.Error(w, http.StatusBadRequest, "display_name is required")
		return
	}

	profile, err := h.creatorRepo.Create(r.Context(), claims.UserID, input.DisplayName)
	if err != nil {
		if errors.Is(err, repository.ErrConflict) {
			response.Error(w, http.StatusConflict, "creator profile already exists")
			return
		}
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}

	// Обновляем роль пользователя
	_ = h.userRepo.SetRole(r.Context(), claims.UserID, models.RoleCreator)

	response.Created(w, profile)
}

// GetCreatorByUsername — публичный профиль автора
func (h *CreatorHandler) GetCreatorByUsername(w http.ResponseWriter, r *http.Request) {
	username := r.PathValue("username")
	user, err := h.userRepo.GetByUsername(r.Context(), username)
	if err != nil {
		response.Error(w, http.StatusNotFound, "creator not found")
		return
	}

	profile, err := h.creatorRepo.GetByUserID(r.Context(), user.ID)
	if err != nil {
		response.Error(w, http.StatusNotFound, "creator not found")
		return
	}

	// Статусы для текущего пользователя
	var isSubscribed, isFollowing bool
	claims := middleware.GetClaims(r)
	if claims != nil {
		isSubscribed, _ = h.subRepo.IsSubscribed(r.Context(), claims.UserID, user.ID)
		isFollowing, _ = h.followRepo.IsFollowing(r.Context(), claims.UserID, user.ID)
	}

	user.Email = ""
	response.OK(w, map[string]any{
		"user":          user,
		"profile":       profile,
		"is_subscribed": isSubscribed,
		"is_following":  isFollowing,
	})
}

// UpdateProfile — обновить профиль автора
func (h *CreatorHandler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)

	var input struct {
		DisplayName             *string `json:"display_name"`
		Description             *string `json:"description"`
		CoverURL                *string `json:"cover_url"`
		Category                *string `json:"category"`
		SubscriptionPriceCents  *int    `json:"subscription_price_cents"`
		SubscriptionDescription *string `json:"subscription_description"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid request body")
		return
	}

	profile, err := h.creatorRepo.Update(r.Context(), claims.UserID,
		input.DisplayName, input.Description, input.CoverURL, input.Category,
		input.SubscriptionDescription, input.SubscriptionPriceCents,
	)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			response.Error(w, http.StatusNotFound, "creator profile not found")
			return
		}
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.OK(w, profile)
}

// List — каталог авторов
func (h *CreatorHandler) List(w http.ResponseWriter, r *http.Request) {
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))
	if limit <= 0 || limit > 50 {
		limit = 20
	}

	var category *string
	if c := r.URL.Query().Get("category"); c != "" {
		category = &c
	}

	creators, err := h.creatorRepo.List(r.Context(), limit, offset, category)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.OK(w, creators)
}

// Subscribe / Unsubscribe

func (h *CreatorHandler) Subscribe(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	creatorUser, err := h.userRepo.GetByUsername(r.Context(), r.PathValue("username"))
	if err != nil {
		response.Error(w, http.StatusNotFound, "creator not found")
		return
	}
	if creatorUser.ID == claims.UserID {
		response.Error(w, http.StatusBadRequest, "cannot subscribe to yourself")
		return
	}

	sub, err := h.subRepo.Subscribe(r.Context(), claims.UserID, creatorUser.ID)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.Created(w, sub)
}

func (h *CreatorHandler) Unsubscribe(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	creatorUser, err := h.userRepo.GetByUsername(r.Context(), r.PathValue("username"))
	if err != nil {
		response.Error(w, http.StatusNotFound, "creator not found")
		return
	}

	if err := h.subRepo.Unsubscribe(r.Context(), claims.UserID, creatorUser.ID); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			response.Error(w, http.StatusNotFound, "subscription not found")
			return
		}
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.NoContent(w)
}

// Follow / Unfollow

func (h *CreatorHandler) Follow(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	creatorUser, err := h.userRepo.GetByUsername(r.Context(), r.PathValue("username"))
	if err != nil {
		response.Error(w, http.StatusNotFound, "creator not found")
		return
	}
	if err := h.followRepo.Follow(r.Context(), claims.UserID, creatorUser.ID); err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.NoContent(w)
}

func (h *CreatorHandler) Unfollow(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	creatorUser, err := h.userRepo.GetByUsername(r.Context(), r.PathValue("username"))
	if err != nil {
		response.Error(w, http.StatusNotFound, "creator not found")
		return
	}
	if err := h.followRepo.Unfollow(r.Context(), claims.UserID, creatorUser.ID); err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.NoContent(w)
}

// MySubscriptions
func (h *CreatorHandler) MySubscriptions(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	subs, err := h.subRepo.GetByPatron(r.Context(), claims.UserID)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.OK(w, subs)
}
