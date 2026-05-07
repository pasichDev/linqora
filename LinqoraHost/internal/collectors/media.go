package collectors

import (
	"LinqoraHost/internal/media"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"
)

// MediaResponse contains information about the currently playing media and system audio settings.
type MediaResponse struct {
	NowPlaying        *media.NowPlaying        `json:"nowPlaying"`
	MediaCapabilities *media.MediaCapabilities `json:"mediaCapabilities"`
}

// MediaCollector monitors and broadcasts changes in system media playback and audio state.
type MediaCollector struct {
	broadcaster   func([]byte)
	ctx           context.Context
	cancel        context.CancelFunc
	lastMediaInfo media.NowPlaying
	isRunning     bool
	mu            sync.Mutex
}

// NewMediaCollector creates a new collector instance for media information.
func NewMediaCollector(broadcaster func([]byte)) *MediaCollector {
	return &MediaCollector{
		broadcaster: broadcaster,
		isRunning:   false,
	}
}

// Start begins the media monitoring loop.
func (mc *MediaCollector) Start() {
	mc.mu.Lock()
	defer mc.mu.Unlock()

	if mc.isRunning {
		return
	}

	ctx, cancel := context.WithCancel(context.Background())
	mc.ctx = ctx
	mc.cancel = cancel
	mc.isRunning = true

	log.Println("Starting media collector")

	go mc.collectLoop(ctx)
}

// Stop terminates the media monitoring loop.
func (mc *MediaCollector) Stop() {
	mc.mu.Lock()
	defer mc.mu.Unlock()

	if !mc.isRunning {
		return
	}

	mc.cancel()
	mc.isRunning = false
	log.Println("Stopped media collector")
}

// IsRunning returns true if the collector is active.
func (mc *MediaCollector) IsRunning() bool {
	mc.mu.Lock()
	defer mc.mu.Unlock()
	return mc.isRunning
}

// collectLoop runs the periodic collection cycle.
func (mc *MediaCollector) collectLoop(ctx context.Context) {
	ticker := time.NewTicker(CollectorInterval)
	defer ticker.Stop()

	// Initial collection on startup.
	mc.collectAndSend()

	for {
		select {
		case <-ticker.C:
			mc.collectAndSend()
		case <-ctx.Done():
			return
		}
	}
}

// collectAndSend gathers current media info and audio capabilities, then broadcasts if changed.
func (mc *MediaCollector) collectAndSend() {
	nowPlaying, err := mc.collectMediaInfo()
	if err != nil {
		log.Printf("Error collecting media info: %v", err)
	}

	mediaCapabilities, err := mc.collectAudioCapabilities()
	if err != nil {
		log.Printf("Error collecting audio settings: %v", err)
	}

	if mediaCapabilities == nil && nowPlaying == nil {
		return
	}

	if mc.broadcaster == nil {
		log.Printf("Warning: broadcaster not initialized")
		return
	}

	response := MediaResponse{}

	if nowPlaying != nil {
		response.NowPlaying = nowPlaying
	}

	if mediaCapabilities != nil {
		response.MediaCapabilities = mediaCapabilities
	}

	metricsJSON, err := json.Marshal(response)
	if err != nil {
		log.Printf("Error marshaling media info: %v", err)
		return
	}

	mc.broadcaster(metricsJSON)
}

// collectMediaInfo retrieves currently playing track information.
func (mc *MediaCollector) collectMediaInfo() (*media.NowPlaying, error) {
	currentInfo, err := media.GetMediaInfo()
	if err != nil {
		return nil, fmt.Errorf("failed to get media info: %w", err)
	}

	mc.mu.Lock()
	defer mc.mu.Unlock()

	// Only return if information has meaningfully changed to reduce bandwidth.
	if !mc.isEqualMediaInfo(mc.lastMediaInfo, currentInfo) {
		mc.lastMediaInfo = currentInfo
		return &currentInfo, nil
	}
	return nil, nil
}

// collectAudioCapabilities retrieves system audio status (volume, mute).
func (mc *MediaCollector) collectAudioCapabilities() (*media.MediaCapabilities, error) {
	currentInfo, err := media.GetAudioCapabilities()
	if err != nil {
		return nil, fmt.Errorf("failed to get audio settings: %w", err)
	}

	return &currentInfo, nil
}

// isEqualMediaInfo compares two snapshots of media playback state.
func (m *MediaCollector) isEqualMediaInfo(old, new media.NowPlaying) bool {
	return old.Title == new.Title &&
		old.Artist == new.Artist &&
		old.Album == new.Album &&
		old.IsPlaying == new.IsPlaying &&
		old.Application == new.Application &&
		(old.Duration == 0 || abs(old.Position-new.Position) < 2)
}

// abs returns the absolute value of an integer.
func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}
