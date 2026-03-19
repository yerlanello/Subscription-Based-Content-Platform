package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"path/filepath"
	"strconv"
	"strings"

	"diploma/backend/internal/middleware"
	"diploma/backend/internal/models"
	"diploma/backend/internal/repository"
	"diploma/backend/internal/response"
	"diploma/backend/internal/service"
	"diploma/backend/internal/storage"

	"github.com/google/uuid"
)

type PostHandler struct {
	postSvc     *service.PostService
	commentRepo *repository.CommentRepo
	userRepo    *repository.UserRepo
	storage     *storage.MinioStorage
}

func NewPostHandler(postSvc *service.PostService, commentRepo *repository.CommentRepo, userRepo *repository.UserRepo, storage *storage.MinioStorage) *PostHandler {
	return &PostHandler{postSvc: postSvc, commentRepo: commentRepo, userRepo: userRepo, storage: storage}
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

func (h *PostHandler) Unpublish(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	postID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.Error(w, http.StatusBadRequest, "invalid post id")
		return
	}
	post, err := h.postSvc.Unpublish(r.Context(), postID, claims.UserID)
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

var allowedMimeTypes = map[string]string{
	".jpg":  "image/jpeg",
	".jpeg": "image/jpeg",
	".png":  "image/png",
	".webp": "image/webp",
	".gif":  "image/gif",
	".mp4":  "video/mp4",
	".webm": "video/webm",
	".mov":  "video/quicktime",
	".mp3":  "audio/mpeg",
	".wav":  "audio/wav",
	".ogg":  "audio/ogg",
	".m4a":  "audio/mp4",
}

func (h *PostHandler) UploadAttachment(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	postID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.Error(w, http.StatusBadRequest, "invalid post id")
		return
	}

	// Проверяем что пост принадлежит пользователю
	post, err := h.postSvc.GetOwn(r.Context(), postID, claims.UserID)
	if err != nil {
		response.Error(w, http.StatusForbidden, "forbidden")
		return
	}
	_ = post

	if h.storage == nil {
		response.Error(w, http.StatusServiceUnavailable, "storage not configured")
		return
	}

	if err := r.ParseMultipartForm(50 << 20); err != nil { // 50 MB
		response.Error(w, http.StatusBadRequest, "file too large (max 50MB)")
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		response.Error(w, http.StatusBadRequest, "file is required")
		return
	}
	defer file.Close()

	ext := strings.ToLower(filepath.Ext(header.Filename))
	mimeType, ok := allowedMimeTypes[ext]
	if !ok {
		response.Error(w, http.StatusBadRequest, "unsupported file type")
		return
	}

	objectName := fmt.Sprintf("posts/%s/%s%s", postID, uuid.New().String(), ext)
	url, err := h.storage.UploadFile(r.Context(), file, objectName, mimeType, header.Size)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "upload failed")
		return
	}

	attachment, err := h.postSvc.AddAttachment(r.Context(), postID, url, mimeType, header.Size)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}

	response.Created(w, attachment)
}

func (h *PostHandler) DeleteAttachment(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	attachmentID, err := uuid.Parse(r.PathValue("attachmentId"))
	if err != nil {
		response.Error(w, http.StatusBadRequest, "invalid attachment id")
		return
	}

	if err := h.postSvc.DeleteAttachment(r.Context(), attachmentID, claims.UserID); err != nil {
		if errors.Is(err, service.ErrForbidden) {
			response.Error(w, http.StatusForbidden, "forbidden")
			return
		}
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.NoContent(w)
}
