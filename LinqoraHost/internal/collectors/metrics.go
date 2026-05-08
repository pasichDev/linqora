package collectors

import (
	"LinqoraHost/internal/metrics"
	"context"
	"encoding/json"
	"log/slog"
	"sync"
	"time"
)

// SystemMetrics represents a snapshot of the system's performance metrics.
type SystemMetrics struct {
	CPUUMetrics    metrics.CPUMetrics `json:"cpuMetrics"`
	RamMetrics     metrics.RamMetrics `json:"ramMetrics"`
	GpuLoadPercent int                `json:"gpuLoadPercent"`
	GpuTemperature int                `json:"gpuTemperature"`
	Timestamp      int64              `json:"timestamp"`
}

// MetricsCollector periodically gathers and broadcasts system performance data.
type MetricsCollector struct {
	broadcaster func([]byte)
	ctx         context.Context
	cancel      context.CancelFunc
	isRunning   bool
	mu          sync.Mutex
}

// NewMetricsCollector creates a new collector instance with the specified broadcast function.
func NewMetricsCollector(broadcaster func([]byte)) *MetricsCollector {
	return &MetricsCollector{
		broadcaster: broadcaster,
		isRunning:   false,
	}
}

// Start initiates the metrics collection loop in a separate goroutine.
func (mc *MetricsCollector) Start() {
	mc.mu.Lock()
	defer mc.mu.Unlock()

	if mc.isRunning {
		return
	}

	ctx, cancel := context.WithCancel(context.Background())
	mc.ctx = ctx
	mc.cancel = cancel
	mc.isRunning = true

	slog.Info("Starting metrics collector")

	go func() {
		// Seed the CPU baseline before the first measurement so that
		// Percent(0,...) returns a real value instead of 0.
		metrics.InitCPUBaseline()
		mc.collectLoop(ctx)
	}()
}

// Stop terminates the metrics collection loop and releases resources.
func (mc *MetricsCollector) Stop() {
	mc.mu.Lock()
	defer mc.mu.Unlock()

	if !mc.isRunning {
		return
	}

	mc.cancel()
	mc.isRunning = false
	slog.Info("Stopped metrics collector")
}

// IsRunning returns true if the collector is currently active.
func (mc *MetricsCollector) IsRunning() bool {
	mc.mu.Lock()
	defer mc.mu.Unlock()
	return mc.isRunning
}

// collectLoop runs the ticker-based collection cycle.
func (mc *MetricsCollector) collectLoop(ctx context.Context) {
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

// collectAndSend gathers current metrics and broadcasts them to subscribers.
func (mc *MetricsCollector) collectAndSend() {
	metrics, err := mc.collectMetrics()
	if err != nil {
		slog.Error("Error collecting metrics", "err", err)
		return
	}

	metricsJSON, err := json.Marshal(metrics)
	if err != nil {
		slog.Error("Error marshaling metrics", "err", err)
		return
	}

	mc.broadcaster(metricsJSON)
}

// collectMetrics retrieves CPU, RAM, and GPU performance data.
func (mc *MetricsCollector) collectMetrics() (*SystemMetrics, error) {
	cpuMetrics, err := metrics.GetCPUMetrics()
	if err != nil {
		return nil, err
	}

	ramMetrics, err := metrics.GetRamMetrics()
	if err != nil {
		return nil, err
	}

	gpuLoad := metrics.GetGPULoadPercent()
	gpuTemp := metrics.GetGPUTemperature()

	result := &SystemMetrics{
		CPUUMetrics:    cpuMetrics,
		RamMetrics:     ramMetrics,
		GpuLoadPercent: gpuLoad,
		GpuTemperature: gpuTemp,
		Timestamp:      time.Now().Unix(),
	}

	return result, nil
}
