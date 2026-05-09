package collectors

import (
	"log/slog"
	"sync"
	"time"
)

const (
	// CollectorInterval defines how often system data is sampled.
	CollectorInterval = 2 * time.Second
)

// CollectorManager coordinates the lifecycle of data collectors based on active room participation.
type CollectorManager struct {
	metricsCollector   *MetricsCollector
	mediaCollector     *MediaCollector
	clipboardCollector *ClipboardCollector
	activeRooms        map[string]int // Tracks active client counts per room
	mu                 sync.Mutex
}

// NewCollectorManager initializes the manager with the required collector instances.
func NewCollectorManager(
	metricsCollector *MetricsCollector,
	mediaCollector *MediaCollector,
	clipboardCollector *ClipboardCollector,
) *CollectorManager {
	return &CollectorManager{
		metricsCollector:   metricsCollector,
		mediaCollector:     mediaCollector,
		clipboardCollector: clipboardCollector,
		activeRooms:        make(map[string]int),
	}
}

// OnFirstClientJoined satisfies the RoomListener interface to start collectors when needed.
func (cm *CollectorManager) OnFirstClientJoined(roomName string) {
	cm.mu.Lock()
	defer cm.mu.Unlock()

	cm.activeRooms[roomName] = 1

	// Activate the appropriate collector based on the room joined.
	switch roomName {
	case "metrics":
		if !cm.metricsCollector.IsRunning() {
			slog.Info("Starting metrics collector because first client joined metrics room")
			cm.metricsCollector.Start()
		}
	case "media":
		if !cm.mediaCollector.IsRunning() {
			slog.Info("Starting media collector because first client joined media room")
			cm.mediaCollector.Start()
		}
	case "clipboard":
		if !cm.clipboardCollector.IsRunning() {
			slog.Info("Starting clipboard collector because first client joined clipboard room")
			cm.clipboardCollector.Start()
		}
	}
}

// OnLastClientLeft satisfies the RoomListener interface to stop collectors when no longer needed.
func (cm *CollectorManager) OnLastClientLeft(roomName string) {
	cm.mu.Lock()
	defer cm.mu.Unlock()

	delete(cm.activeRooms, roomName)

	// Deactivate the appropriate collector based on the room vacated.
	switch roomName {
	case "metrics":
		if cm.metricsCollector.IsRunning() {
			slog.Info("Stopping metrics collector because last client left metrics room")
			cm.metricsCollector.Stop()
		}
	case "media":
		if cm.mediaCollector.IsRunning() {
			slog.Info("Stopping media collector because last client left media room")
			cm.mediaCollector.Stop()
		}
	case "clipboard":
		if cm.clipboardCollector.IsRunning() {
			slog.Info("Stopping clipboard collector because last client left clipboard room")
			cm.clipboardCollector.Stop()
		}
	}
}
