package collectors

import (
	"LinqoraHost/internal/clipboard"
	"context"
	"log/slog"
	"sync"
	"time"
)

const clipboardPollInterval = 500 * time.Millisecond

// ClipboardCollector watches the host clipboard and broadcasts changes.
type ClipboardCollector struct {
	broadcaster func([]byte)
	ctx         context.Context
	cancel      context.CancelFunc
	isRunning   bool
	mu          sync.Mutex
}

// NewClipboardCollector creates a collector that invokes broadcaster on each clipboard change.
func NewClipboardCollector(broadcaster func([]byte)) *ClipboardCollector {
	return &ClipboardCollector{broadcaster: broadcaster}
}

// Start begins clipboard watching in a background goroutine.
func (cc *ClipboardCollector) Start() {
	cc.mu.Lock()
	defer cc.mu.Unlock()
	if cc.isRunning {
		return
	}
	ctx, cancel := context.WithCancel(context.Background())
	cc.ctx = ctx
	cc.cancel = cancel
	cc.isRunning = true
	slog.Info("Starting clipboard collector")
	go cc.watchLoop(ctx)
}

// Stop terminates clipboard watching.
func (cc *ClipboardCollector) Stop() {
	cc.mu.Lock()
	defer cc.mu.Unlock()
	if !cc.isRunning {
		return
	}
	cc.cancel()
	cc.isRunning = false
	slog.Info("Stopped clipboard collector")
}

// IsRunning reports whether the collector is active.
func (cc *ClipboardCollector) IsRunning() bool {
	cc.mu.Lock()
	defer cc.mu.Unlock()
	return cc.isRunning
}

func (cc *ClipboardCollector) watchLoop(ctx context.Context) {
	ch := make(chan string, 8)
	go clipboard.Watch(ctx, clipboardPollInterval, ch)
	for {
		select {
		case <-ctx.Done():
			return
		case text := <-ch:
			cc.broadcaster([]byte(text))
		}
	}
}
