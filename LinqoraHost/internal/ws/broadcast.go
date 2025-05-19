package ws

import (
	"encoding/json"
	"log"
)

// BroadcastMessage - общий интерфейс для сообщений трансляции
type BroadcastMessage interface {
	GetType() string
	ToJSON() ([]byte, error)
}

func (m MetricsMessage) GetType() string {
	return m.Type
}

func (m MetricsMessage) ToJSON() ([]byte, error) {
	return json.Marshal(m)
}

func (m MediaMessage) GetType() string {
	return m.Type
}

func (m MediaMessage) ToJSON() ([]byte, error) {
	return json.Marshal(m)
}

// Broadcaster предоставляет методы для трансляции сообщений в комнаты
type Broadcaster struct {
	roomManager *RoomManager
}

// NewBroadcaster создает новый экземпляр транслятора сообщений
func NewBroadcaster(roomManager *RoomManager) *Broadcaster {
	return &Broadcaster{
		roomManager: roomManager,
	}
}

// BroadcastToRoom отправляет сообщение всем клиентам в указанной комнате
func (b *Broadcaster) BroadcastToRoom(roomName string, message BroadcastMessage, excludeClient *Client) {
	// Проверяем, существует ли комната и есть ли в ней клиенты
	room := b.roomManager.GetRoom(roomName)
	if room == nil || room.ClientCount() == 0 {
		return
	}

	// Преобразуем сообщение в JSON
	messageJSON, err := message.ToJSON()
	if err != nil {
		log.Printf("Error marshaling %s message: %v", message.GetType(), err)
		return
	}

	// Отправляем сообщение всем клиентам в комнате
	b.roomManager.BroadcastToRoom(roomName, messageJSON, excludeClient)
}

// BroadcastMetrics отправляет метрики всем клиентам в комнате metrics
func (b *Broadcaster) BroadcastMetrics(metricsData []byte) {
	var payload interface{}
	if err := json.Unmarshal(metricsData, &payload); err != nil {
		log.Printf("Error unmarshaling metrics data: %v", err)
		return
	}

	// Рассылаем всем клиентам в комнате
	b.roomManager.BroadcastToRoom("metrics", payload, nil)
}

// BroadcastMedia отправляет медиаданные всем клиентам в комнате media
func (b *Broadcaster) BroadcastMedia(mediaData []byte) {
	var payload interface{}
	if err := json.Unmarshal(mediaData, &payload); err != nil {
		log.Printf("Error unmarshaling metrics data: %v", err)
		return
	}
	b.roomManager.BroadcastToRoom("media", payload, nil)
}
