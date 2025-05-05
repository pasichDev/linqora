package metrics

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/shirou/gopsutil/cpu"
	"github.com/shirou/gopsutil/disk"
	"github.com/shirou/gopsutil/mem"

	"LinqoraHost/internal/config"
)

// SystemMetrics представляє метрики системи
type SystemMetrics struct {
	CPUUsage    float64 `json:"cpuUsage"`
	MemoryTotal uint64  `json:"memoryTotal"`
	MemoryUsed  uint64  `json:"memoryUsed"`
	MemoryFree  uint64  `json:"memoryFree"`
	DiskTotal   uint64  `json:"diskTotal"`
	DiskFree    uint64  `json:"diskFree"`
	DiskUsed    uint64  `json:"diskUsed"`
	Timestamp   int64   `json:"timestamp"`
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
	// Отримуємо CPU використання
	cpuPercent, err := cpu.Percent(time.Second, false)
	if err != nil {
		return nil, fmt.Errorf("failed to get CPU usage: %v", err)
	}

	// Отримуємо інформацію про пам'ять
	v, err := mem.VirtualMemory()
	if err != nil {
		return nil, fmt.Errorf("failed to get memory info: %v", err)
	}

	// Отримуємо інформацію про диск
	d, err := disk.Usage("/") // Для Windows використовуйте "C:\\"
	if err != nil {
		return nil, fmt.Errorf("failed to get disk info: %v", err)
	}

	// Формуємо структуру метрик
	metrics := &SystemMetrics{
		CPUUsage:    cpuPercent[0],
		MemoryTotal: v.Total,
		MemoryUsed:  v.Used,
		MemoryFree:  v.Free,
		DiskTotal:   d.Total,
		DiskFree:    d.Free,
		DiskUsed:    d.Used,
		Timestamp:   time.Now().Unix(),
	}

	return metrics, nil
}
