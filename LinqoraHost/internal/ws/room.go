package ws

import (
	"encoding/json"
	"log"
	"sync"
)

// Room represents a room with a set of subscribed clients.
type Room struct {
	Name    string
	Clients map[*Client]bool
	mu      sync.Mutex
}

// NewRoom creates a new room.
func NewRoom(name string) *Room {
	return &Room{
		Name:    name,
		Clients: make(map[*Client]bool),
	}
}

// AddClient adds a client to the room.
// Updating the client's Rooms map is the caller's (RoomManager's) responsibility.
func (r *Room) AddClient(client *Client) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.Clients[client] = true
}

// RemoveClient removes a client from the room.
func (r *Room) RemoveClient(client *Client) {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.Clients, client)
}

// SendToAllClients broadcasts a message to every client in the room except
// excludeClient.
//
// Previous implementation held r.mu for the entire duration of serialisation
// and channel sends, which blocked concurrent join/leave operations.
// This version:
//  1. Serialises the JSON payload once, outside the lock.
//  2. Takes a short-lived snapshot of the client list under r.mu.
//  3. Sends to each client without holding the lock.
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

// ClientCount returns the number of clients currently in the room.
func (r *Room) ClientCount() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.Clients)
}

// HasClient reports whether the client is in the room.
func (r *Room) HasClient(client *Client) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	_, exists := r.Clients[client]
	return exists
}
