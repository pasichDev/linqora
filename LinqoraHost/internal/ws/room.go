package ws

import (
	"encoding/json"
	"log"
	"sync"
)

// Room represents a logical group of WebSocket clients, enabling targeted message broadcasting.
type Room struct {
	Name    string
	Clients map[*Client]bool
	mu      sync.Mutex
}

// NewRoom initialises a new room with the specified name.
func NewRoom(name string) *Room {
	return &Room{
		Name:    name,
		Clients: make(map[*Client]bool),
	}
}

// AddClient subscribes a client to the room.
// Note: Management of the client's internal room list is handled by RoomManager.
func (r *Room) AddClient(client *Client) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.Clients[client] = true
}

// RemoveClient unsubscribes a client from the room.
func (r *Room) RemoveClient(client *Client) {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.Clients, client)
}

// SendToAllClients broadcasts a message to all subscribers in the room, optionally excluding one.
// The implementation uses a client list snapshot to avoid holding the lock during network I/O.
func (r *Room) SendToAllClients(messageType string, message interface{}, excludeClient *Client) {
	// Serialise once — all clients receive the same bytes.
	successResponse := NewSuccessResponse(messageType, message)
	jsonMsg, err := json.Marshal(successResponse)
	if err != nil {
		log.Printf("Error marshaling broadcast message for room %s: %v", r.Name, err)
		return
	}

	// Build a snapshot of active clients under a short lock.
	r.mu.Lock()
	snapshot := make([]*Client, 0, len(r.Clients))
	for client := range r.Clients {
		if client != excludeClient && !client.IsClosed() {
			snapshot = append(snapshot, client)
		}
	}
	r.mu.Unlock()

	// Send without holding the lock so that join/leave are not blocked.
	for _, client := range snapshot {
		client.sendMessage(jsonMsg)
	}
}

// ClientCount returns the current number of clients in the room.
func (r *Room) ClientCount() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.Clients)
}

// HasClient checks if a specific client is currently in the room.
func (r *Room) HasClient(client *Client) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	_, exists := r.Clients[client]
	return exists
}
