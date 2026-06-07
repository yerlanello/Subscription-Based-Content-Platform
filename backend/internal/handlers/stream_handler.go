package handlers

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"diploma/backend/internal/hub"
	"diploma/backend/internal/middleware"
	"diploma/backend/internal/models"
	"diploma/backend/internal/repository"
	"diploma/backend/internal/response"

	"github.com/go-chi/chi/v5"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type StreamHandler struct {
	streamRepo  *repository.StreamRepo
	notifRepo   *repository.NotificationRepo
	notifHub    *hub.Hub
}

func NewStreamHandler(
	streamRepo *repository.StreamRepo,
	notifRepo *repository.NotificationRepo,
	notifHub *hub.Hub,
) *StreamHandler {
	return &StreamHandler{
		streamRepo: streamRepo,
		notifRepo:  notifRepo,
		notifHub:   notifHub,
	}
}

// livekitToken generates a LiveKit access token manually (standard JWT).
func livekitToken(roomName, identity, name string, isPublisher bool) (string, error) {
	apiKey := os.Getenv("LIVEKIT_API_KEY")
	apiSecret := os.Getenv("LIVEKIT_API_SECRET")

	canPublish := isPublisher
	canSubscribe := true

	type videoGrant struct {
		RoomJoin       bool   `json:"roomJoin"`
		Room           string `json:"room"`
		CanPublish     *bool  `json:"canPublish"`
		CanPublishData *bool  `json:"canPublishData"` // needed for chat data channel
		CanSubscribe   *bool  `json:"canSubscribe"`
	}

	canPublishData := true // everyone can chat
	claims := jwt.MapClaims{
		"iss": apiKey,
		"sub": identity,
		"name": name,
		"exp": time.Now().Add(4 * time.Hour).Unix(),
		"nbf": time.Now().Unix(),
		"video": videoGrant{
			RoomJoin:       true,
			Room:           roomName,
			CanPublish:     &canPublish,
			CanPublishData: &canPublishData,
			CanSubscribe:   &canSubscribe,
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(apiSecret))
}

// GET /api/streams/my — returns caller's active stream + fresh token (for session restore)
func (h *StreamHandler) GetMine(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)

	stream, err := h.streamRepo.GetActiveByCreator(r.Context(), claims.UserID)
	if err != nil {
		// No active stream — return null data, not an error
		response.OK(w, nil)
		return
	}

	token, err := livekitToken(stream.LivekitRoom, claims.UserID.String(), claims.Username, true)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "failed to generate token")
		return
	}

	response.OK(w, map[string]any{
		"stream":      stream,
		"token":       token,
		"livekit_url": os.Getenv("LIVEKIT_URL"),
	})
}

// POST /api/streams/start
func (h *StreamHandler) Start(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)

	var input struct {
		Title string `json:"title"`
	}
	json.NewDecoder(r.Body).Decode(&input)
	if input.Title == "" {
		input.Title = "Прямой эфир"
	}

	// End any existing live stream for this user before starting a new one
	if err := h.streamRepo.EndAllByCreator(r.Context(), claims.UserID); err != nil {
		log.Printf("warn: end previous streams for %s: %v", claims.UserID, err)
	}

	roomName := "stream-" + claims.UserID.String()
	stream, err := h.streamRepo.Create(r.Context(), claims.UserID, input.Title, roomName)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "failed to create stream")
		return
	}

	token, err := livekitToken(roomName, claims.UserID.String(), claims.Username, true)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "failed to generate token")
		return
	}

	response.Created(w, map[string]any{
		"stream":      stream,
		"token":       token,
		"livekit_url": os.Getenv("LIVEKIT_URL"),
	})

	// Notify followers/subscribers in the background
	go func() {
		ctx := r.Context()
		ids, err := h.notifRepo.GetFollowerAndSubscriberIDs(ctx, claims.UserID)
		if err != nil || len(ids) == 0 {
			return
		}
		streamURL := fmt.Sprintf("/streams/%s", stream.ID)
		body := input.Title
		for _, uid := range ids {
			_, err := h.notifRepo.Create(ctx, uid, "stream_live",
				fmt.Sprintf("%s начал прямой эфир", claims.Username),
				&body, &streamURL,
			)
			if err == nil {
				h.notifHub.Send(uid, hub.Event{
					Type:  "notification",
					Title: fmt.Sprintf("%s начал прямой эфир", claims.Username),
					Body:  body,
					Link:  streamURL,
				})
			}
		}
	}()
}

// POST /api/streams/{id}/end
func (h *StreamHandler) End(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		response.Error(w, http.StatusBadRequest, "invalid id")
		return
	}
	if err := h.streamRepo.End(r.Context(), id, claims.UserID); err != nil {
		response.Error(w, http.StatusInternalServerError, "failed to end stream")
		return
	}
	response.NoContent(w)
}

// PATCH /api/streams/{id}/location
func (h *StreamHandler) UpdateLocation(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		response.Error(w, http.StatusBadRequest, "invalid id")
		return
	}

	var input struct {
		Latitude  float64 `json:"latitude"`
		Longitude float64 `json:"longitude"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		response.Error(w, http.StatusBadRequest, "invalid body")
		return
	}

	if err := h.streamRepo.UpdateLocation(r.Context(), id, claims.UserID, input.Latitude, input.Longitude); err != nil {
		response.Error(w, http.StatusInternalServerError, "failed to update location")
		return
	}
	response.NoContent(w)
}

// GET /api/streams
func (h *StreamHandler) List(w http.ResponseWriter, r *http.Request) {
	streams, err := h.streamRepo.ListLive(r.Context())
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	if streams == nil {
		streams = []models.Stream{}
	}
	response.OK(w, streams)
}

// GET /api/streams/{id}
func (h *StreamHandler) Get(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		response.Error(w, http.StatusBadRequest, "invalid id")
		return
	}
	stream, err := h.streamRepo.GetByID(r.Context(), id)
	if err != nil {
		response.Error(w, http.StatusNotFound, "stream not found")
		return
	}
	response.OK(w, stream)
}

// POST /api/streams/{id}/join
func (h *StreamHandler) Join(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		response.Error(w, http.StatusBadRequest, "invalid id")
		return
	}

	stream, err := h.streamRepo.GetByID(r.Context(), id)
	if err != nil {
		response.Error(w, http.StatusNotFound, "stream not found")
		return
	}
	if stream.Status != "live" {
		response.Error(w, http.StatusBadRequest, "stream is not live")
		return
	}

	token, err := livekitToken(stream.LivekitRoom, claims.UserID.String(), claims.Username, false)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "failed to generate token")
		return
	}

	response.OK(w, map[string]any{
		"token":       token,
		"livekit_url": os.Getenv("LIVEKIT_URL"),
		"stream":      stream,
	})
}

// GET /api/streams/by-creator/{username}
func (h *StreamHandler) GetByCreator(w http.ResponseWriter, r *http.Request) {
	username := chi.URLParam(r, "username")
	stream, err := h.streamRepo.GetActiveByUsername(r.Context(), username)
	if err != nil {
		response.OK(w, nil)
		return
	}
	response.OK(w, stream)
}

// GET /api/streams/{id}/messages
func (h *StreamHandler) GetMessages(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		response.Error(w, http.StatusBadRequest, "invalid id")
		return
	}
	msgs, err := h.streamRepo.GetMessages(r.Context(), id)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "internal error")
		return
	}
	response.OK(w, msgs)
}

// POST /api/streams/{id}/messages
func (h *StreamHandler) SendMessage(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetClaims(r)
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		response.Error(w, http.StatusBadRequest, "invalid id")
		return
	}

	var input struct {
		Message     string `json:"message"`
		DisplayName string `json:"display_name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil || input.Message == "" {
		response.Error(w, http.StatusBadRequest, "message required")
		return
	}
	if len(input.Message) > 500 {
		response.Error(w, http.StatusBadRequest, "message too long")
		return
	}
	displayName := input.DisplayName
	if displayName == "" {
		displayName = claims.Username
	}

	msg, err := h.streamRepo.SaveMessage(r.Context(), id, claims.UserID, claims.Username, displayName, input.Message)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "failed to save message")
		return
	}
	response.Created(w, msg)
}
