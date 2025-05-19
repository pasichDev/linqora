package ws

import (
	"log"
	"sync"
)

// Room представляє кімнату для WebSocket клієнтів
type Room struct {
	Name    string
	Clients map[*Client]bool
	mu      sync.Mutex
}

// NewRoom створює нову кімнату
func NewRoom(name string) *Room {
	return &Room{
		Name:    name,
		Clients: make(map[*Client]bool),
	}
}

// AddClient додає клієнта до кімнати
func (r *Room) AddClient(client *Client) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.Clients[client] = true
}

// RemoveClient видаляє клієнта з кімнати
func (r *Room) RemoveClient(client *Client) {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.Clients, client)
}

// Broadcast надсилає повідомлення всім клієнтам у кімнаті
func (r *Room) Broadcast(roomName string, message interface{}, excludeClient *Client) {
	r.mu.Lock()
	defer r.mu.Unlock()

	for client := range r.Clients {
		if client != excludeClient {
			client.SendSuccess(roomName, message)
		}
	}
}

// ClientCount повертає кількість клієнтів у кімнаті
func (r *Room) ClientCount() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.Clients)
}

// RoomManager керує кімнатами
type RoomManager struct {
	Rooms map[string]*Room
	mu    sync.Mutex
}

// NewRoomManager створює новий менеджер кімнат
func NewRoomManager() *RoomManager {
	return &RoomManager{
		Rooms: make(map[string]*Room),
	}
}

// AddClientToRoom додає клієнта до кімнати
func (rm *RoomManager) AddClientToRoom(roomName string, client *Client) {
	rm.mu.Lock()
	if _, exists := rm.Rooms[roomName]; !exists {
		rm.Rooms[roomName] = NewRoom(roomName)
	}
	room := rm.Rooms[roomName]
	rm.mu.Unlock()

	room.AddClient(client)

	client.mu.Lock()
	client.Rooms[roomName] = true
	client.mu.Unlock()

	log.Printf("Client %s joined room: %s", client.DeviceName, roomName)
}

// RemoveClientFromRoom видаляє клієнта з кімнати
func (rm *RoomManager) RemoveClientFromRoom(roomName string, client *Client) {
	rm.mu.Lock()
	room, exists := rm.Rooms[roomName]
	rm.mu.Unlock()

	if exists {
		room.RemoveClient(client)

		client.mu.Lock()
		delete(client.Rooms, roomName)
		client.mu.Unlock()

		log.Printf("Client %s left room: %s", client.DeviceName, roomName)

		// Видаляємо порожню кімнату
		if room.ClientCount() == 0 {
			rm.mu.Lock()
			delete(rm.Rooms, roomName)
			rm.mu.Unlock()
			log.Printf("Room %s removed (empty)", roomName)
		}
	}

}

// BroadcastToRoom надсилає повідомлення всім клієнтам у кімнаті
func (rm *RoomManager) BroadcastToRoom(roomName string, message interface{}, excludeClient *Client) {
	rm.mu.Lock()
	room, exists := rm.Rooms[roomName]
	rm.mu.Unlock()

	if exists {
		room.Broadcast(roomName, message, excludeClient)
	}
}

// GetRoom повертає кімнату за ім'ям
func (rm *RoomManager) GetRoom(roomName string) *Room {
	rm.mu.Lock()
	defer rm.mu.Unlock()
	return rm.Rooms[roomName]
}

// IsClientInRoom проверяет, находится ли клиент в указанной комнате
func (rm *RoomManager) IsClientInRoom(roomName string, client *Client) bool {
	rm.mu.Lock()
	defer rm.mu.Unlock()

	room, exists := rm.Rooms[roomName]
	if !exists {
		return false
	}

	_, inRoom := room.Clients[client]
	return inRoom
}

// RemoveClientFromAllRooms удаляет клиента из всех комнат
func (rm *RoomManager) RemoveClientFromAllRooms(client *Client) {
	rm.mu.Lock()
	defer rm.mu.Unlock()

	for name, room := range rm.Rooms {
		if _, exists := room.Clients[client]; exists {
			delete(room.Clients, client)
			log.Printf("Client %s removed from room %s", client.DeviceName, name)
		}
	}
}
