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
	"diploma/backend/internal/service"

	"github.com/google/uuid"
)

type PostHandler struct {
	postSvc    *service.PostService
	commentRepo *repository.CommentRepo
	userRepo   *repository.UserRepo
}

func NewPostHandler(postSvc *service.PostService, commentRepo *repository.CommentRepo, userRepo *repository.UserRepo) *PostHandler {
	return &PostHandler{postSvc: postSvc, commentRepo: commentRepo, userRepo: userRepo}
}

func (h *PostHandler) Create(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)

	var input struct {
		Title   string          `json:"title"`
		Content *string         `json:"content"`
		Type    models.PostType `json:"type"`
		IsFree  bool            `json:"is_free"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil || input.Title == "" {
		response.Error(w, http.StatusBadRequest, "title is required")
		return
	}
	if input.Type == "" {
		input.Type = models.PostTypeText
	}

	post, err := h.postSvc.Create(r.Context(), service.CreatePostInput{
		CreatorID: claims.UserID,
		Title:     input.Title,
		Content:   input.Content,
		Type:      input.Type,
		IsFree:    input.IsFree,
	})
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.Created(w, post)
}

func (h *PostHandler) Get(w http.ResponseWriter, r *http.Request) {
	postID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.Error(w, http.StatusBadRequest, "invalid post id")
		return
	}

	var requesterID uuid.UUID
	if claims := middleware.GetClaims(r); claims != nil {
		requesterID = claims.UserID
	}

	post, err := h.postSvc.Get(r.Context(), postID, requesterID)
	if err != nil {
		if errors.Is(err, service.ErrNotFound) {
			response.Error(w, http.StatusNotFound, "post not found")
			return
		}
		if errors.Is(err, service.ErrAccessDenied) {
			response.Error(w, http.StatusPaymentRequired, "subscription required to view this post")
			return
		}
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.OK(w, post)
}

func (h *PostHandler) Update(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	postID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.Error(w, http.StatusBadRequest, "invalid post id")
		return
	}

	var input struct {
		Title   *string `json:"title"`
		Content *string `json:"content"`
		IsFree  *bool   `json:"is_free"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid request body")
		return
	}

	post, err := h.postSvc.Update(r.Context(), postID, claims.UserID, input.Title, input.Content, input.IsFree)
	if err != nil {
		switch {
		case errors.Is(err, service.ErrNotFound):
			response.Error(w, http.StatusNotFound, "post not found")
		case errors.Is(err, service.ErrForbidden):
			response.Error(w, http.StatusForbidden, "forbidden")
		default:
			response.Error(w, http.StatusInternalServerError, "internal error")
		}
		return
	}
	response.OK(w, post)
}

func (h *PostHandler) Publish(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	postID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.Error(w, http.StatusBadRequest, "invalid post id")
		return
	}

	post, err := h.postSvc.Publish(r.Context(), postID, claims.UserID)
	if err != nil {
		switch {
		case errors.Is(err, service.ErrNotFound):
			response.Error(w, http.StatusNotFound, "post not found")
		case errors.Is(err, service.ErrForbidden):
			response.Error(w, http.StatusForbidden, "forbidden")
		default:
			response.Error(w, http.StatusInternalServerError, "internal error")
		}
		return
	}
	response.OK(w, post)
}

func (h *PostHandler) Delete(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	postID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.Error(w, http.StatusBadRequest, "invalid post id")
		return
	}

	if err := h.postSvc.Delete(r.Context(), postID, claims.UserID); err != nil {
		switch {
		case errors.Is(err, service.ErrNotFound):
			response.Error(w, http.StatusNotFound, "post not found")
		case errors.Is(err, service.ErrForbidden):
			response.Error(w, http.StatusForbidden, "forbidden")
		default:
			response.Error(w, http.StatusInternalServerError, "internal error")
		}
		return
	}
	response.NoContent(w)
}

func (h *PostHandler) ListByCreator(w http.ResponseWriter, r *http.Request) {
	username := r.PathValue("username")
	user, err := h.userRepo.GetByUsername(r.Context(), username)
	if err != nil {
		response.Error(w, http.StatusNotFound, "creator not found")
		return
	}

	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))
	if limit <= 0 || limit > 50 {
		limit = 20
	}

	var requesterID uuid.UUID
	if claims := middleware.GetClaims(r); claims != nil {
		requesterID = claims.UserID
	}

	posts, err := h.postSvc.ListByCreator(r.Context(), user.ID, requesterID, limit, offset)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.OK(w, posts)
}

func (h *PostHandler) Feed(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))
	if limit <= 0 || limit > 50 {
		limit = 20
	}

	posts, err := h.postSvc.Feed(r.Context(), claims.UserID, limit, offset)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.OK(w, posts)
}

func (h *PostHandler) Like(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	postID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.Error(w, http.StatusBadRequest, "invalid post id")
		return
	}
	if err := h.postSvc.Like(r.Context(), postID, claims.UserID); err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.NoContent(w)
}

func (h *PostHandler) Unlike(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	postID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.Error(w, http.StatusBadRequest, "invalid post id")
		return
	}
	if err := h.postSvc.Unlike(r.Context(), postID, claims.UserID); err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.NoContent(w)
}

// Comments

func (h *PostHandler) GetComments(w http.ResponseWriter, r *http.Request) {
	postID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.Error(w, http.StatusBadRequest, "invalid post id")
		return
	}

	comments, err := h.commentRepo.GetByPost(r.Context(), postID)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.OK(w, comments)
}

func (h *PostHandler) CreateComment(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	postID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.Error(w, http.StatusBadRequest, "invalid post id")
		return
	}

	var input struct {
		Content  string     `json:"content"`
		ParentID *uuid.UUID `json:"parent_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil || input.Content == "" {
		response.Error(w, http.StatusBadRequest, "content is required")
		return
	}

	comment, err := h.commentRepo.Create(r.Context(), postID, claims.UserID, input.ParentID, input.Content)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.Created(w, comment)
}

func (h *PostHandler) DeleteComment(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	commentID, err := uuid.Parse(r.PathValue("commentId"))
	if err != nil {
		response.Error(w, http.StatusBadRequest, "invalid comment id")
		return
	}

	if err := h.commentRepo.Delete(r.Context(), commentID, claims.UserID); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			response.Error(w, http.StatusNotFound, "comment not found")
			return
		}
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.NoContent(w)
}
