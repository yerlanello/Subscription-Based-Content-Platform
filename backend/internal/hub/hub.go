package hub

import (
	"encoding/json"
	"sync"

	"github.com/google/uuid"
)

// Event — событие которое шлём клиенту через SSE
type Event struct {
	Type    string `json:"type"`
	Title   string `json:"title"`
	Body    string `json:"body,omitempty"`
	Link    string `json:"link,omitempty"`
	ID      string `json:"id"`
}

// client — один SSE-клиент
type client struct {
	ch chan Event
}

// Hub управляет всеми SSE-подключениями
type Hub struct {
	mu      sync.RWMutex
	clients map[uuid.UUID][]*client
}

func New() *Hub {
	return &Hub{clients: make(map[uuid.UUID][]*client)}
}

// Subscribe регистрирует клиента и возвращает канал событий и функцию отписки
func (h *Hub) Subscribe(userID uuid.UUID) (<-chan Event, func()) {
	c := &client{ch: make(chan Event, 8)}
	h.mu.Lock()
	h.clients[userID] = append(h.clients[userID], c)
	h.mu.Unlock()

	unsubscribe := func() {
		h.mu.Lock()
		defer h.mu.Unlock()
		list := h.clients[userID]
		for i, existing := range list {
			if existing == c {
				h.clients[userID] = append(list[:i], list[i+1:]...)
				break
			}
		}
		close(c.ch)
	}
	return c.ch, unsubscribe
}

// Send отправляет событие конкретному пользователю (если он подключён)
func (h *Hub) Send(userID uuid.UUID, event Event) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for _, c := range h.clients[userID] {
		select {
		case c.ch <- event:
		default: // не блокируем если канал переполнен
		}
	}
}

// SendMany отправляет событие нескольким пользователям
func (h *Hub) SendMany(userIDs []uuid.UUID, event Event) {
	for _, uid := range userIDs {
		h.Send(uid, event)
	}
}

func (e Event) ToSSE() []byte {
	data, _ := json.Marshal(e)
	return append([]byte("data: "), append(data, '\n', '\n')...)
}
