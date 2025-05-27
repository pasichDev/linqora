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

// MetricsMessage представляет сообщение с метриками системы
type MetricsMessage struct {
	Type    string      `json:"type"`
	Metrics interface{} `json:"metrics"`
}

// MediaMessage представляет сообщение с информацией о медиа
type MediaMessage struct {
	Type  string      `json:"type"`
	Media interface{} `json:"media"`
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

// BroadcastMetrics отправляет метрики всем клиентам в комнате metrics
func (b *Broadcaster) BroadcastMetrics(metricsData []byte) {
	var payload interface{}
	if err := json.Unmarshal(metricsData, &payload); err != nil {
		log.Printf("Error unmarshaling metrics data: %v", err)
		return
	}

	// Рассылаем всем клиентам в комнате
	b.roomManager.SendToRoom("metrics", "metrics", payload, nil)
}

// BroadcastMedia отправляет медиаданные всем клиентам в комнате media
func (b *Broadcaster) BroadcastMedia(mediaData []byte) {
	var payload interface{}
	if err := json.Unmarshal(mediaData, &payload); err != nil {
		log.Printf("Error unmarshaling media data: %v", err)
		return
	}
	b.roomManager.SendToRoom("media", "media", payload, nil)
}

// GetMetricsBroadcaster возвращает функцию для трансляции метрик
func (b *Broadcaster) GetMetricsBroadcaster() func([]byte) {
	return b.BroadcastMetrics
}

// GetMediaBroadcaster возвращает функцию для трансляции медиаданных
func (b *Broadcaster) GetMediaBroadcaster() func([]byte) {
	return b.BroadcastMedia
}
