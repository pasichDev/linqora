package collectors

import (
	"LinqoraHost/internal/metrics"
	"context"
	"encoding/json"
	"log/slog"
	"sync"
	"time"

	"github.com/shirou/gopsutil/v4/disk"
	gopsnet "github.com/shirou/gopsutil/v4/net"
)

// SystemMetrics represents a snapshot of the system's performance metrics.
type SystemMetrics struct {
	CPUUMetrics    metrics.CPUMetrics `json:"cpuMetrics"`
	RamMetrics     metrics.RamMetrics `json:"ramMetrics"`
	GpuLoadPercent int                `json:"gpuLoadPercent"`
	GpuTemperature int                `json:"gpuTemperature"`
	DiskReadBps    uint64             `json:"diskReadBps"`
	DiskWriteBps   uint64             `json:"diskWriteBps"`
	NetSentBps     uint64             `json:"netSentBps"`
	NetRecvBps     uint64             `json:"netRecvBps"`
	Timestamp      int64              `json:"timestamp"`
}

// MetricsCollector periodically gathers and broadcasts system performance data.
type MetricsCollector struct {
	broadcaster  func([]byte)
	ctx          context.Context
	cancel       context.CancelFunc
	isRunning    bool
	mu           sync.Mutex
	prevDiskRead  uint64
	prevDiskWrite uint64
	prevNetSent   uint64
	prevNetRecv   uint64
	prevTime      time.Time
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

// collectMetrics retrieves CPU, RAM, GPU, disk I/O, and network performance data.
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

	now := time.Now()
	var diskReadBps, diskWriteBps, netSentBps, netRecvBps uint64

	// Compute disk I/O per-second deltas.
	if diskCounters, err := disk.IOCounters(); err == nil {
		var totalRead, totalWrite uint64
		for _, c := range diskCounters {
			totalRead += c.ReadBytes
			totalWrite += c.WriteBytes
		}
		mc.mu.Lock()
		if !mc.prevTime.IsZero() {
			elapsed := now.Sub(mc.prevTime).Seconds()
			if elapsed > 0 {
				if totalRead >= mc.prevDiskRead {
					diskReadBps = uint64(float64(totalRead-mc.prevDiskRead) / elapsed)
				}
				if totalWrite >= mc.prevDiskWrite {
					diskWriteBps = uint64(float64(totalWrite-mc.prevDiskWrite) / elapsed)
				}
			}
		}
		mc.prevDiskRead = totalRead
		mc.prevDiskWrite = totalWrite
		mc.mu.Unlock()
	}

	// Compute network I/O per-second deltas.
	if netCounters, err := gopsnet.IOCounters(false); err == nil && len(netCounters) > 0 {
		var totalSent, totalRecv uint64
		for _, c := range netCounters {
			totalSent += c.BytesSent
			totalRecv += c.BytesRecv
		}
		mc.mu.Lock()
		if !mc.prevTime.IsZero() {
			elapsed := now.Sub(mc.prevTime).Seconds()
			if elapsed > 0 {
				if totalSent >= mc.prevNetSent {
					netSentBps = uint64(float64(totalSent-mc.prevNetSent) / elapsed)
				}
				if totalRecv >= mc.prevNetRecv {
					netRecvBps = uint64(float64(totalRecv-mc.prevNetRecv) / elapsed)
				}
			}
		}
		mc.prevNetSent = totalSent
		mc.prevNetRecv = totalRecv
		mc.mu.Unlock()
	}

	mc.mu.Lock()
	mc.prevTime = now
	mc.mu.Unlock()

	result := &SystemMetrics{
		CPUUMetrics:    cpuMetrics,
		RamMetrics:     ramMetrics,
		GpuLoadPercent: gpuLoad,
		GpuTemperature: gpuTemp,
		DiskReadBps:    diskReadBps,
		DiskWriteBps:   diskWriteBps,
		NetSentBps:     netSentBps,
		NetRecvBps:     netRecvBps,
		Timestamp:      now.Unix(),
	}

	return result, nil
}
