package metrics

import (
	"context"
	"encoding/json"
	"log"
	"time"

	"LinqoraHost/internal/config"
)

// SystemMetrics представляє метрики системи
type SystemMetrics struct {
	CPUUMetrics CPUMetrics `json:"cpuMetrics"`
	RamMetrics  RamMetrics `json:"ramMetrics"`
	Timestamp   int64      `json:"timestamp"`
}

// MetricsCollector збирає системні метрики
type MetricsCollector struct {
	config      *config.ServerConfig
	broadcaster func([]byte)
}

// NewMetricsCollector створює новий колектор метрик
func NewMetricsCollector(config *config.ServerConfig, broadcaster func([]byte)) *MetricsCollector {
	return &MetricsCollector{
		config:      config,
		broadcaster: broadcaster,
	}
}

// Start запускає збір метрик
func (mc *MetricsCollector) Start(ctx context.Context) {
	ticker := time.NewTicker(mc.config.MetricsInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			metrics, err := mc.collectMetrics()
			if err != nil {
				log.Printf("Error collecting metrics: %v", err)
				continue
			}

			metricsJSON, err := json.Marshal(metrics)
			if err != nil {
				log.Printf("Error marshaling metrics: %v", err)
				continue
			}

			// Відправляємо метрики через функцію відправки
			mc.broadcaster(metricsJSON)

		case <-ctx.Done():
			return
		}
	}
}

// collectMetrics збирає системні метрики
func (mc *MetricsCollector) collectMetrics() (*SystemMetrics, error) {
	cpuMetrics, err := GetCPUMetrics()
	if err != nil {
		return nil, err
	}

	ramMetrics, err := GetRamMetrics()
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
