package media

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"
)

const (
	MediaInterval = 2 * time.Second
)

type MediaResponse struct {
	NowPlaying        *NowPlaying        `json:"nowPlaying"`
	MediaCapabilities *MediaCapabilities `json:"mediaCapabilities"`
}

type MediaCollector struct {
	broadcaster   func([]byte)
	lastMediaInfo NowPlaying
	mu            sync.Mutex
}

func NewMediaCollector(broadcaster func([]byte)) *MediaCollector {

	return &MediaCollector{
		broadcaster: broadcaster,
	}
}

// Start запускає збір
func (mc *MediaCollector) Start(ctx context.Context) {

	interval := MediaInterval
	if interval <= 0 {
		interval = 2 * time.Second
		log.Printf("Попередженя: MediasInterval не встановлено, використовується 2 сек")
	}

	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	// Запускаємо перший збір інформації
	mc.collectAndSendInfo()

	for {
		select {
		case <-ticker.C:
			mc.collectAndSendInfo()
		case <-ctx.Done():
			log.Println("MediaCollector зупинено")
			return
		}
	}

}

// Метод для збору та надсилання інформації про медіа
func (mc *MediaCollector) collectAndSendInfo() {
	// Збираємо інформацію про медіа
	nowPlaying, err := mc.collectMediaInfo()
	if err != nil {
		log.Printf("Ошибка сбора медиа-информации: %v", err)
	}

	// Збираємо інформацію про аудіо-можливості
	mediaCapabilities, err := mc.collectAudioCapabilities()
	if err != nil {
		log.Printf("Ошибка сбора аудио-настроек: %v", err)
	}

	if mediaCapabilities == nil && nowPlaying == nil {
		return
	}

	if mc.broadcaster == nil {
		log.Printf("Попердження: broadcaster не встановлено")
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
		log.Printf("Помилки медіа: %v", err)
		return
	}

	mc.broadcaster(metricsJSON)
}

// CollectMediaInfo збирає інформацію про медіа
func (mc *MediaCollector) collectMediaInfo() (*NowPlaying, error) {
	currentInfo, err := GetMediaInfo()
	if err != nil {
		return nil, fmt.Errorf("Помилка отримання інформації: %w", err)
	}

	mc.mu.Lock()
	defer mc.mu.Unlock()

	if !mc.isEqualMediaInfo(mc.lastMediaInfo, currentInfo) {
		mc.lastMediaInfo = currentInfo
		return &currentInfo, nil
	}
	return nil, nil
}

// AudioCapabilities збирає інформацію про аудіо-можливості
func (mc *MediaCollector) collectAudioCapabilities() (*MediaCapabilities, error) {
	currentInfo, err := GetAudioCapabilities()
	if err != nil {
		return nil, fmt.Errorf("Помилка отримання інформації: %w", err)
	}

	return &currentInfo, nil
}

// isEqualMediaInfo порівнює дві структури MediaInfo
func (m *MediaCollector) isEqualMediaInfo(old, new NowPlaying) bool {
	return old.Title == new.Title &&
		old.Artist == new.Artist &&
		old.Album == new.Album &&
		old.IsPlaying == new.IsPlaying &&
		old.Application == new.Application &&

		(old.Duration == 0 || abs(old.Position-new.Position) < 2)
}

func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}
