package collectors

import (
	"context"
	"log/slog"
	"sync"
	"time"

	"LinqoraHost/internal/metrics"
)

const (
	// batteryPollInterval is how often the battery level is sampled.
	batteryPollInterval = 60 * time.Second
	// defaultBatteryThreshold is the percent below which an alert fires.
	defaultBatteryThreshold = 20
)

// BatteryAlertCollector monitors battery level and broadcasts an alert when
// the battery falls below the configured threshold while discharging.
type BatteryAlertCollector struct {
	// broadcaster is called with (msgType, data) to reach all connected clients.
	broadcaster func(string, interface{})
	threshold   int
	lastPercent int
	// alerted tracks whether we have already sent an alert in the current
	// drain cycle. Reset to false when the device starts charging.
	alerted   bool
	ctx       context.Context
	cancel    context.CancelFunc
	isRunning bool
	mu        sync.Mutex
}

// NewBatteryAlertCollector creates a new collector that will call broadcaster
// whenever it needs to push a battery_alert message to all clients.
func NewBatteryAlertCollector(broadcaster func(string, interface{})) *BatteryAlertCollector {
	return &BatteryAlertCollector{
		broadcaster: broadcaster,
		threshold:   defaultBatteryThreshold,
	}
}

// Start begins the background polling goroutine.
func (c *BatteryAlertCollector) Start() {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.isRunning {
		return
	}

	ctx, cancel := context.WithCancel(context.Background())
	c.ctx = ctx
	c.cancel = cancel
	c.isRunning = true

	slog.Info("Starting battery alert collector", "threshold", c.threshold)

	go c.pollLoop(ctx)
}

// Stop terminates the background polling goroutine.
func (c *BatteryAlertCollector) Stop() {
	c.mu.Lock()
	defer c.mu.Unlock()

	if !c.isRunning {
		return
	}

	c.cancel()
	c.isRunning = false
	slog.Info("Stopped battery alert collector")
}

// IsRunning returns true if the collector is currently active.
func (c *BatteryAlertCollector) IsRunning() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.isRunning
}

// SetThreshold updates the alert threshold percentage (0–100).
func (c *BatteryAlertCollector) SetThreshold(pct int) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.threshold = pct
	slog.Info("Battery alert threshold updated", "threshold", pct)
}

// pollLoop runs the periodic battery check.
func (c *BatteryAlertCollector) pollLoop(ctx context.Context) {
	ticker := time.NewTicker(batteryPollInterval)
	defer ticker.Stop()

	// Run an immediate check on start.
	c.checkBattery()

	for {
		select {
		case <-ticker.C:
			c.checkBattery()
		case <-ctx.Done():
			return
		}
	}
}

// checkBattery reads the current battery status and fires an alert if needed.
func (c *BatteryAlertCollector) checkBattery() {
	info, err := metrics.GetBatteryInfo()
	if err != nil || !info.IsPresent {
		return
	}

	c.mu.Lock()
	threshold := c.threshold
	alerted := c.alerted
	c.lastPercent = info.Level
	c.mu.Unlock()

	if info.IsCharging {
		// Reset alert state so we fire again on the next drain cycle.
		c.mu.Lock()
		c.alerted = false
		c.mu.Unlock()
		return
	}

	// Discharge path: fire once per drain cycle when below threshold.
	if info.Level <= threshold && !alerted {
		c.mu.Lock()
		c.alerted = true
		c.mu.Unlock()

		slog.Info("Battery low alert", "percent", info.Level, "threshold", threshold)
		c.broadcaster("battery_alert", map[string]interface{}{
			"percent":   info.Level,
			"threshold": threshold,
		})
	}
}
