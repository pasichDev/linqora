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

type MediaResponse struct {
	NowPlaying        *media.NowPlaying        `json:"nowPlaying"`
	MediaCapabilities *media.MediaCapabilities `json:"mediaCapabilities"`
}

type MediaCollector struct {
	broadcaster   func([]byte)
	ctx           context.Context
	cancel        context.CancelFunc
	lastMediaInfo media.NowPlaying
	isRunning     bool
	mu            sync.Mutex
}

func NewMediaCollector(broadcaster func([]byte)) *MediaCollector {

	return &MediaCollector{
		broadcaster: broadcaster,
		isRunning:   false,
	}
}

func (mc *MediaCollector) Start() {
	mc.mu.Lock()
	defer mc.mu.Unlock()

	if mc.isRunning {
		return
	}

	// Создаем новый контекст с возможностью отмены
	ctx, cancel := context.WithCancel(context.Background())
	mc.ctx = ctx
	mc.cancel = cancel
	mc.isRunning = true

	log.Println("Starting media collector")

	// Запускаем сбор в отдельной горутине
	go mc.collectLoop(ctx)
}

// Stop останавливает сбор метрик
func (mc *MediaCollector) Stop() {
	mc.mu.Lock()
	defer mc.mu.Unlock()

	if !mc.isRunning {
		return // Коллектор уже остановлен
	}

	// Отмена контекста останавливает цикл сбора
	mc.cancel()
	mc.isRunning = false
	log.Println("Stopped media collector")
}

// IsRunning возвращает статус активности коллектора
func (mc *MediaCollector) IsRunning() bool {
	mc.mu.Lock()
	defer mc.mu.Unlock()
	return mc.isRunning
}

// collectLoop выполняет цикл сбора метрик
func (mc *MediaCollector) collectLoop(ctx context.Context) {
	ticker := time.NewTicker(CollectorInterval)
	defer ticker.Stop()

	// Собираем метрики сразу при запуске
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

// Метод для збору та надсилання інформації про медіа
func (mc *MediaCollector) collectAndSend() {
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
		log.Printf("[MediaCollector:] Нет данных для отправки, выход из метода")
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
func (mc *MediaCollector) collectMediaInfo() (*media.NowPlaying, error) {
	currentInfo, err := media.GetMediaInfo()
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
func (mc *MediaCollector) collectAudioCapabilities() (*media.MediaCapabilities, error) {
	currentInfo, err := media.GetAudioCapabilities()
	if err != nil {
		return nil, fmt.Errorf("Помилка отримання інформації: %w", err)
	}

	return &currentInfo, nil
}

// isEqualMediaInfo порівнює дві структури MediaInfo
func (m *MediaCollector) isEqualMediaInfo(old, new media.NowPlaying) bool {
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
