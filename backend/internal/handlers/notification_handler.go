package handlers

import (
	"fmt"
	"net/http"
	"time"

	"diploma/backend/internal/hub"
	"diploma/backend/internal/middleware"
	"diploma/backend/internal/repository"
	"diploma/backend/internal/response"

	"github.com/google/uuid"
)

type NotificationHandler struct {
	notifRepo *repository.NotificationRepo
	hub       *hub.Hub
}

func NewNotificationHandler(notifRepo *repository.NotificationRepo, h *hub.Hub) *NotificationHandler {
	return &NotificationHandler{notifRepo: notifRepo, hub: h}
}

// Stream — SSE endpoint, держит соединение и шлёт события
// Принимает токен через Authorization header ИЛИ ?token= query param (для EventSource)
func (h *NotificationHandler) Stream(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	if claims == nil {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")

	flusher, ok := w.(http.Flusher)
	if !ok {
		response.Error(w, http.StatusInternalServerError, "streaming not supported")
		return
	}

	// Отправляем ping сразу чтобы открыть соединение
	fmt.Fprintf(w, ": ping\n\n")
	flusher.Flush()

	events, unsubscribe := h.hub.Subscribe(claims.UserID)
	defer unsubscribe()

	ticker := time.NewTicker(25 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-r.Context().Done():
			return
		case <-ticker.C:
			// keepalive ping
			fmt.Fprintf(w, ": ping\n\n")
			flusher.Flush()
		case event, ok := <-events:
			if !ok {
				return
			}
			w.Write(event.ToSSE())
			flusher.Flush()
		}
	}
}

// List — список уведомлений
func (h *NotificationHandler) List(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	notifs, err := h.notifRepo.GetByUser(r.Context(), claims.UserID, 30)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}

	unread, _ := h.notifRepo.UnreadCount(r.Context(), claims.UserID)

	if notifs == nil {
		notifs = []repository.Notification{}
	}

	response.OK(w, map[string]any{
		"notifications": notifs,
		"unread_count":  unread,
	})
}

// MarkAllRead — отметить все прочитанными
func (h *NotificationHandler) MarkAllRead(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	if err := h.notifRepo.MarkAllRead(r.Context(), claims.UserID); err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.NoContent(w)
}

// MarkRead — отметить одно прочитанным
func (h *NotificationHandler) MarkRead(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.Error(w, http.StatusBadRequest, "invalid id")
		return
	}
	if err := h.notifRepo.MarkRead(r.Context(), id, claims.UserID); err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.NoContent(w)
}

// Delete — удалить одно уведомление
func (h *NotificationHandler) Delete(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.Error(w, http.StatusBadRequest, "invalid id")
		return
	}
	if err := h.notifRepo.Delete(r.Context(), id, claims.UserID); err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.NoContent(w)
}

// DeleteAll — удалить все уведомления
func (h *NotificationHandler) DeleteAll(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	if err := h.notifRepo.DeleteAll(r.Context(), claims.UserID); err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.NoContent(w)
}
