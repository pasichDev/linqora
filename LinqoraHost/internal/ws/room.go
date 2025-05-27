package ws

import (
	"sync"
)

// Room представляет комнату с клиентами
type Room struct {
	Name    string
	Clients map[*Client]bool
	mu      sync.Mutex
}

// NewRoom создает новую комнату
func NewRoom(name string) *Room {
	return &Room{
		Name:    name,
		Clients: make(map[*Client]bool),
	}
}

// AddClient добавляет клиента в комнату
// НЕ обновляет состояние клиента - это ответственность RoomManager
func (r *Room) AddClient(client *Client) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.Clients[client] = true
}

// RemoveClient удаляет клиента из комнаты
// НЕ обновляет состояние клиента - это ответственность RoomManager
func (r *Room) RemoveClient(client *Client) {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.Clients, client)
}

// SendToAllClients отправляет сообщение всем клиентам в комнате, кроме исключенного
func (r *Room) SendToAllClients(messageType string, message interface{}, excludeClient *Client) {
	r.mu.Lock()
	defer r.mu.Unlock()

	for client := range r.Clients {
		if client != excludeClient && !client.IsClosed() {
			client.SendSuccess(messageType, message)
		}
	}
}

// ClientCount возвращает количество клиентов в комнате
func (r *Room) ClientCount() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.Clients)
}

// HasClient проверяет, находится ли клиент в комнате
func (r *Room) HasClient(client *Client) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	_, exists := r.Clients[client]
	return exists
}
