package ws

import (
	"log/slog"
	"sync"
)

// RoomListener defines an interface for listening to room events.
type RoomListener interface {
	OnFirstClientJoined(roomName string)
	OnLastClientLeft(roomName string)
}

// RoomManager manages all communication rooms and their client subscriptions.
type RoomManager struct {
	Rooms     map[string]*Room
	mu        sync.Mutex
	listeners []RoomListener
}

// NewRoomManager creates a new RoomManager instance.
func NewRoomManager() *RoomManager {
	return &RoomManager{
		Rooms:     make(map[string]*Room),
		listeners: make([]RoomListener, 0),
	}
}

// AddRoomListener registers a new listener for room events.
func (rm *RoomManager) AddRoomListener(listener RoomListener) {
	rm.mu.Lock()
	defer rm.mu.Unlock()
	rm.listeners = append(rm.listeners, listener)
}

// notifyFirstClientJoined alerts listeners that a room has gained its first client.
func (rm *RoomManager) notifyFirstClientJoined(roomName string) {
	for _, listener := range rm.listeners {
		listener.OnFirstClientJoined(roomName)
	}
}

// notifyLastClientLeft alerts listeners that a room has become empty.
func (rm *RoomManager) notifyLastClientLeft(roomName string) {
	for _, listener := range rm.listeners {
		listener.OnLastClientLeft(roomName)
	}
}

// GetOrCreateRoom returns the specified room, creating it if it doesn't exist.
func (rm *RoomManager) GetOrCreateRoom(roomName string) *Room {
	rm.mu.Lock()
	defer rm.mu.Unlock()

	if room, exists := rm.Rooms[roomName]; exists {
		return room
	}

	room := NewRoom(roomName)
	rm.Rooms[roomName] = room
	return room
}

// IsClientInRoom checks if the given client is a member of the specified room.
func (rm *RoomManager) IsClientInRoom(roomName string, client *Client) bool {
	rm.mu.Lock()
	room, exists := rm.Rooms[roomName]
	rm.mu.Unlock()

	if !exists {
		return false
	}

	return room.HasClient(client)
}

// GetRoom retrieves a room by name. Returns nil if not found.
func (rm *RoomManager) GetRoom(roomName string) *Room {
	rm.mu.Lock()
	defer rm.mu.Unlock()
	return rm.Rooms[roomName]
}

// SendToRoom broadcasts a message to all clients in the room except excludeClient.
func (rm *RoomManager) SendToRoom(roomName string, messageType string, message interface{}, excludeClient *Client) {
	rm.mu.Lock()
	room, exists := rm.Rooms[roomName]
	rm.mu.Unlock()

	if exists {
		room.SendToAllClients(messageType, message, excludeClient)
	}
}

// AddClientToRoom subscribes a client to the specified room.
func (rm *RoomManager) AddClientToRoom(roomName string, client *Client) {
	room := rm.GetOrCreateRoom(roomName)

	// Check if this is the first client
	isFirst := room.ClientCount() == 0

	// Add client to room
	room.AddClient(client)

	// Update client state
	client.Lock()
	client.Rooms[roomName] = true
	client.Unlock()

	slog.Info("Client joined room", "device", client.DeviceName, "room", roomName)

	// If first client, notify listeners
	if isFirst {
		rm.notifyFirstClientJoined(roomName)
	}
}

// RemoveClientFromRoom unsubscribes a client from the specified room.
func (rm *RoomManager) RemoveClientFromRoom(roomName string, client *Client) {
	rm.mu.Lock()
	room, exists := rm.Rooms[roomName]
	rm.mu.Unlock()

	if exists {
		// Check if this was the last client
		isLast := room.ClientCount() == 1 && room.HasClient(client)

		// Remove client from room
		room.RemoveClient(client)

		// Update client state
		client.Lock()
		delete(client.Rooms, roomName)
		client.Unlock()

		slog.Info("Client left room", "device", client.DeviceName, "room", roomName)

		// Cleanup empty room
		if room.ClientCount() == 0 {
			rm.mu.Lock()
			delete(rm.Rooms, roomName)
			rm.mu.Unlock()
			slog.Info("Room removed (empty)", "room", roomName)

			if isLast {
				rm.notifyLastClientLeft(roomName)
			}
		}
	}
}

// RemoveClientFromAllRooms unsubscribes a client from every room it belongs to.
func (rm *RoomManager) RemoveClientFromAllRooms(client *Client) {
	rm.mu.Lock()
	clientRooms := make([]string, 0)
	for roomName, room := range rm.Rooms {
		if room.HasClient(client) {
			clientRooms = append(clientRooms, roomName)
		}
	}
	rm.mu.Unlock()

	for _, roomName := range clientRooms {
		rm.RemoveClientFromRoom(roomName, client)
	}
}

// BroadcastToRoom sends a message to all clients in a room.
func (rm *RoomManager) BroadcastToRoom(roomName string, messageType string, message interface{}, excludeClient *Client) {
	room := rm.GetRoom(roomName)
	if room != nil {
		room.SendToAllClients(messageType, message, excludeClient)
	}
}
