package collectors

import (
	"LinqoraHost/internal/metrics"
	"context"
	"encoding/json"
	"log"
	"sync"
	"time"
)

// SystemMetrics представляє метрики системи
type SystemMetrics struct {
	CPUUMetrics metrics.CPUMetrics `json:"cpuMetrics"`
	RamMetrics  metrics.RamMetrics `json:"ramMetrics"`
	Timestamp   int64              `json:"timestamp"`
}

// MetricsCollector збирає системні метрики
type MetricsCollector struct {
	broadcaster func([]byte)
	ctx         context.Context
	cancel      context.CancelFunc
	isRunning   bool
	mu          sync.Mutex
}

// NewMetricsCollector створює новий колектор метрик
func NewMetricsCollector(broadcaster func([]byte)) *MetricsCollector {
	return &MetricsCollector{
		broadcaster: broadcaster,
		isRunning:   false,
	}
}

// Start запускає збір метрик
func (mc *MetricsCollector) Start() {
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

	log.Println("Starting metrics collector")

	// Запускаем сбор в отдельной горутине
	go mc.collectLoop(ctx)
}

// Stop останавливает сбор метрик
func (mc *MetricsCollector) Stop() {
	mc.mu.Lock()
	defer mc.mu.Unlock()

	if !mc.isRunning {
		return // Коллектор уже остановлен
	}

	// Отмена контекста останавливает цикл сбора
	mc.cancel()
	mc.isRunning = false
	log.Println("Stopped metrics collector")
}

// IsRunning возвращает статус активности коллектора
func (mc *MetricsCollector) IsRunning() bool {
	mc.mu.Lock()
	defer mc.mu.Unlock()
	return mc.isRunning
}

// collectLoop выполняет цикл сбора метрик
func (mc *MetricsCollector) collectLoop(ctx context.Context) {
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

// collectAndSend собирает и отправляет метрики
func (mc *MetricsCollector) collectAndSend() {
	metrics, err := mc.collectMetrics()
	if err != nil {
		log.Printf("Error collecting metrics: %v", err)
		return
	}

	metricsJSON, err := json.Marshal(metrics)
	if err != nil {
		log.Printf("Error marshaling metrics: %v", err)
		return
	}

	// Отправляем метрики через функцию отправки
	mc.broadcaster(metricsJSON)
}

// collectMetrics збирає системні метрики
func (mc *MetricsCollector) collectMetrics() (*SystemMetrics, error) {
	cpuMetrics, err := metrics.GetCPUMetrics()
	if err != nil {
		return nil, err
	}

	ramMetrics, err := metrics.GetRamMetrics()
	if err != nil {
		return nil, err
	}

	// Формуємо структуру метрик
	metrics := &SystemMetrics{
		CPUUMetrics: cpuMetrics,
		RamMetrics:  ramMetrics,
		Timestamp:   time.Now().Unix(),
	}

	return metrics, nil
}
