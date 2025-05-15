package media

import (
	"LinqoraHost/internal/config"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"
)

type MediaResponse struct {
	NowPlaying        *NowPlaying        `json:"nowPlaying"`
	MediaCapabilities *MediaCapabilities `json:"mediaCapabilities"`
}

type MediaCollector struct {
	config        *config.ServerConfig
	broadcaster   func([]byte)
	lastMediaInfo NowPlaying
	mu            sync.Mutex
}

func NewMediaCollector(config *config.ServerConfig, broadcaster func([]byte)) *MediaCollector {

	return &MediaCollector{
		config:      config,
		broadcaster: broadcaster,
	}
}

// Start запускає збір
func (mc *MediaCollector) Start(ctx context.Context) {
	// Проверка и установка значения по умолчанию для интервала
	interval := mc.config.MediasInterval
	if interval <= 0 {
		interval = 2 * time.Second // Значение по умолчанию для предотвращения паники
		log.Printf("Предупреждение: MediasInterval не установлен или равен нулю, используется 2 секунды")
	}

	log.Printf("MediaCollector запущен с интервалом %v", interval)

	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	// Запускаем первый сбор сразу, не дожидаясь тикера
	mc.collectAndSendInfo()

	for {
		select {
		case <-ticker.C:
			mc.collectAndSendInfo()
		case <-ctx.Done():
			log.Println("MediaCollector остановлен")
			return
		}
	}

}

// Метод для сбора и отправки информации
func (mc *MediaCollector) collectAndSendInfo() {
	// Собираем информацию о текущем медиа
	nowPlaying, err := mc.collectMediaInfo()
	if err != nil {
		log.Printf("Ошибка сбора медиа-информации: %v", err)
	}

	// Собираем информацию о настройках аудио
	mediaCapabilities, err := mc.collectAudioCapabilities()
	if err != nil {
		log.Printf("Ошибка сбора аудио-настроек: %v", err)
	}

	// Проверяем, есть ли что-то для отправки
	if mediaCapabilities == nil && nowPlaying == nil {
		return
	}

	if mc.broadcaster == nil {
		log.Printf("Предупреждение: broadcaster не установлен")
		return
	}

	// Создаем объект ответа с явным указанием null для отсутствующих данных
	response := MediaResponse{}

	if nowPlaying != nil {
		response.NowPlaying = nowPlaying
	}

	if mediaCapabilities != nil {
		response.MediaCapabilities = mediaCapabilities
	}

	metricsJSON, err := json.Marshal(response)

	// Проверяем на ошибки маршалинга
	if err != nil {
		log.Printf("Ошибка маршалинга медиа: %v", err)
		return
	}

	mc.broadcaster(metricsJSON)
}

// collectMediaInfo собирает информацию о текущем проигрываемом медиа
func (mc *MediaCollector) collectMediaInfo() (*NowPlaying, error) {
	currentInfo, err := GetMediaInfo()
	if err != nil {
		return nil, fmt.Errorf("ошибка получения медиа-информации: %w", err)
	}

	mc.mu.Lock()
	defer mc.mu.Unlock()

	if !mc.isEqualMediaInfo(mc.lastMediaInfo, currentInfo) {
		mc.lastMediaInfo = currentInfo
		return &currentInfo, nil
	}
	return nil, nil
}

// AudioCapabilities собирает информацию о настройках медиа
func (mc *MediaCollector) collectAudioCapabilities() (*MediaCapabilities, error) {
	currentInfo, err := GetAudioCapabilities()
	if err != nil {
		return nil, fmt.Errorf("ошибка получения медиа-информации: %w", err)
	}

	return &currentInfo, nil
}

// isEqualMediaInfo сравнивает две структуры MediaInfo
func (m *MediaCollector) isEqualMediaInfo(old, new NowPlaying) bool {
	return old.Title == new.Title &&
		old.Artist == new.Artist &&
		old.Album == new.Album &&
		old.IsPlaying == new.IsPlaying &&
		old.Application == new.Application &&
		// Проверка позиции с небольшим отклонением для непрерывного потока
		(old.Duration == 0 || abs(old.Position-new.Position) < 2)
}

// Вспомогательная функция для вычисления абсолютного значения
func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}
