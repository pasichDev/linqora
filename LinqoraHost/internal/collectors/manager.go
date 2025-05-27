package collectors

import (
	"log"
	"sync"
	"time"
)

const (
	CollectorInterval = 2 * time.Second
)

// CollectorManager управляет запуском/остановкой коллекторов
type CollectorManager struct {
	metricsCollector *MetricsCollector
	mediaCollector   *MediaCollector
	activeRooms      map[string]int // Счетчик активных клиентов в комнатах
	mu               sync.Mutex
}

// NewCollectorManager создает новый менеджер коллекторов
func NewCollectorManager(
	metricsCollector *MetricsCollector,
	mediaCollector *MediaCollector,
) *CollectorManager {
	return &CollectorManager{
		metricsCollector: metricsCollector,
		mediaCollector:   mediaCollector,
		activeRooms:      make(map[string]int),
	}
}

// Реализация интерфейса RoomListener
func (cm *CollectorManager) OnFirstClientJoined(roomName string) {
	cm.mu.Lock()
	defer cm.mu.Unlock()

	cm.activeRooms[roomName] = 1

	// Запускаем соответствующий коллектор в зависимости от имени комнаты
	switch roomName {
	case "metrics":
		if !cm.metricsCollector.IsRunning() {
			log.Println("Starting metrics collector because first client joined metrics room")
			cm.metricsCollector.Start()
		}
	case "media":
		if !cm.mediaCollector.IsRunning() {
			log.Println("Starting media collector because first client joined media room")
			cm.mediaCollector.Start()
		}
	}
}

func (cm *CollectorManager) OnLastClientLeft(roomName string) {
	cm.mu.Lock()
	defer cm.mu.Unlock()

	delete(cm.activeRooms, roomName)

	// Останавливаем соответствующий коллектор в зависимости от имени комнаты
	switch roomName {
	case "metrics":
		if cm.metricsCollector.IsRunning() {
			log.Println("Stopping metrics collector because last client left metrics room")
			cm.metricsCollector.Stop()
		}
	case "media":
		if cm.mediaCollector.IsRunning() {
			log.Println("Stopping media collector because last client left media room")
			cm.mediaCollector.Stop()
		}
	}
}
