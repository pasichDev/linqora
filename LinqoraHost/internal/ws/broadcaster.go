package ws

import (
	"encoding/json"
	"log"
)

// BroadcastMessage defines a common interface for messages distributed across rooms.
type BroadcastMessage interface {
	GetType() string
	ToJSON() ([]byte, error)
}

// MetricsMessage encapsulates system performance metrics for broadcasting.
type MetricsMessage struct {
	Type    string      `json:"type"`
	Metrics interface{} `json:"metrics"`
}

// MediaMessage encapsulates multimedia state information for broadcasting.
type MediaMessage struct {
	Type  string      `json:"type"`
	Media interface{} `json:"media"`
}

// GetType returns the message type for MetricsMessage.
func (m MetricsMessage) GetType() string {
	return m.Type
}

// ToJSON serialises the MetricsMessage to a byte slice.
func (m MetricsMessage) ToJSON() ([]byte, error) {
	return json.Marshal(m)
}

// GetType returns the message type for MediaMessage.
func (m MediaMessage) GetType() string {
	return m.Type
}

// ToJSON serialises the MediaMessage to a byte slice.
func (m MediaMessage) ToJSON() ([]byte, error) {
	return json.Marshal(m)
}

// Broadcaster provides high-level methods to distribute messages into specific rooms.
type Broadcaster struct {
	roomManager *RoomManager
}

// NewBroadcaster creates a new Broadcaster instance associated with a RoomManager.
func NewBroadcaster(roomManager *RoomManager) *Broadcaster {
	return &Broadcaster{
		roomManager: roomManager,
	}
}

// BroadcastMetrics sends system metrics to all clients subscribed to the "metrics" room.
func (b *Broadcaster) BroadcastMetrics(metricsData []byte) {
	var payload interface{}
	if err := json.Unmarshal(metricsData, &payload); err != nil {
		log.Printf("Error unmarshaling metrics data: %v", err)
		return
	}

	b.roomManager.SendToRoom("metrics", "metrics", payload, nil)
}

// BroadcastMedia sends multimedia state to all clients subscribed to the "media" room.
func (b *Broadcaster) BroadcastMedia(mediaData []byte) {
	var payload interface{}
	if err := json.Unmarshal(mediaData, &payload); err != nil {
		log.Printf("Error unmarshaling media data: %v", err)
		return
	}
	b.roomManager.SendToRoom("media", "media", payload, nil)
}

// GetMetricsBroadcaster returns a callback function for broadcasting metrics.
func (b *Broadcaster) GetMetricsBroadcaster() func([]byte) {
	return b.BroadcastMetrics
}

// GetMediaBroadcaster returns a callback function for broadcasting media data.
func (b *Broadcaster) GetMediaBroadcaster() func([]byte) {
	return b.BroadcastMedia
}
