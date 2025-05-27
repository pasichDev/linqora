package ws

import (
	"log"
	"sync"
)

// RoomListener определяет интерфейс для слушателей событий комнаты
type RoomListener interface {
	OnFirstClientJoined(roomName string)
	OnLastClientLeft(roomName string)
}

// RoomManager управляет комнатами
type RoomManager struct {
	Rooms     map[string]*Room
	mu        sync.Mutex
	listeners []RoomListener
}

// NewRoomManager создает новый менеджер комнат
func NewRoomManager() *RoomManager {
	return &RoomManager{
		Rooms:     make(map[string]*Room),
		listeners: make([]RoomListener, 0),
	}
}

// AddRoomListener добавляет слушателя событий комнаты
func (rm *RoomManager) AddRoomListener(listener RoomListener) {
	rm.mu.Lock()
	defer rm.mu.Unlock()
	rm.listeners = append(rm.listeners, listener)
}

// notifyFirstClientJoined уведомляет слушателей о подключении первого клиента
func (rm *RoomManager) notifyFirstClientJoined(roomName string) {
	for _, listener := range rm.listeners {
		listener.OnFirstClientJoined(roomName)
	}
}

// notifyLastClientLeft уведомляет слушателей о отключении последнего клиента
func (rm *RoomManager) notifyLastClientLeft(roomName string) {
	for _, listener := range rm.listeners {
		listener.OnLastClientLeft(roomName)
	}
}

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

// IsClientInRoom проверяет, находится ли клиент в указанной комнате
func (rm *RoomManager) IsClientInRoom(roomName string, client *Client) bool {
	rm.mu.Lock()
	room, exists := rm.Rooms[roomName]
	rm.mu.Unlock()

	if !exists {
		return false
	}

	return room.HasClient(client)
}

// GetRoom получает комнату по имени (только для чтения)
func (rm *RoomManager) GetRoom(roomName string) *Room {
	rm.mu.Lock()
	defer rm.mu.Unlock()
	return rm.Rooms[roomName]
}

// SendToRoom отправляет сообщение всем клиентам в комнате
func (rm *RoomManager) SendToRoom(roomName string, messageType string, message interface{}, excludeClient *Client) {
	rm.mu.Lock()
	room, exists := rm.Rooms[roomName]
	rm.mu.Unlock()

	if exists {
		room.SendToAllClients(messageType, message, excludeClient)
	}
}

// AddClientToRoom добавляет клиента в комнату
func (rm *RoomManager) AddClientToRoom(roomName string, client *Client) {
	room := rm.GetOrCreateRoom(roomName)

	// Проверяем, был ли это первый клиент
	isFirst := room.ClientCount() == 0

	// Добавляем клиента в комнату
	room.AddClient(client)

	// Обновляем состояние клиента
	client.Lock()
	client.Rooms[roomName] = true
	client.Unlock()

	log.Printf("Client %s joined room: %s", client.DeviceName, roomName)

	// Если это первый клиент, уведомляем слушателей
	if isFirst {
		rm.notifyFirstClientJoined(roomName)
	}
}

// RemoveClientFromRoom удаляет клиента из комнаты
func (rm *RoomManager) RemoveClientFromRoom(roomName string, client *Client) {
	rm.mu.Lock()
	room, exists := rm.Rooms[roomName]
	rm.mu.Unlock()

	if exists {
		// Проверяем, является ли клиент последним в комнате
		isLast := room.ClientCount() == 1 && room.HasClient(client)

		// Удаляем клиента из комнаты
		room.RemoveClient(client)

		// Обновляем состояние клиента
		client.Lock()
		delete(client.Rooms, roomName)
		client.Unlock()

		log.Printf("Client %s left room: %s", client.DeviceName, roomName)

		// Удаляем пустую комнату и уведомляем, если это был последний клиент
		if room.ClientCount() == 0 {
			rm.mu.Lock()
			delete(rm.Rooms, roomName)
			rm.mu.Unlock()
			log.Printf("Room %s removed (empty)", roomName)

			if isLast {
				rm.notifyLastClientLeft(roomName)
			}
		}
	}
}

// RemoveClientFromAllRooms удаляет клиента из всех комнат
func (rm *RoomManager) RemoveClientFromAllRooms(client *Client) {
	// Получаем список комнат без долгой блокировки
	rm.mu.Lock()
	clientRooms := make([]string, 0)
	for roomName, room := range rm.Rooms {
		if room.HasClient(client) {
			clientRooms = append(clientRooms, roomName)
		}
	}
	rm.mu.Unlock()

	// Теперь удаляем клиента из каждой комнаты
	for _, roomName := range clientRooms {
		rm.RemoveClientFromRoom(roomName, client)
	}
}

// BroadcastToRoom отправляет сообщение всем клиентам в комнате
func (rm *RoomManager) BroadcastToRoom(roomName string, messageType string, message interface{}, excludeClient *Client) {
	room := rm.GetRoom(roomName)
	if room != nil {
		room.SendToAllClients(messageType, message, excludeClient)
	}
}
