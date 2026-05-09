package clipboard

import (
	"context"
	"time"
)

// Get returns the current clipboard text content.
func Get() (string, error) { return platformGet() }

// Set writes text to the clipboard.
func Set(text string) error { return platformSet(text) }

// Watch emits clipboard text to ch whenever it changes.
// Polls every interval. Stops when ctx is cancelled.
func Watch(ctx context.Context, interval time.Duration, ch chan<- string) {
	watchWithGetter(ctx, interval, platformGet, ch)
}

func watchWithGetter(ctx context.Context, interval time.Duration, getter func() (string, error), ch chan<- string) {
	last, _ := getter()
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			text, err := getter()
			if err != nil || text == last {
				continue
			}
			last = text
			select {
			case ch <- text:
			case <-ctx.Done():
				return
			}
		}
	}
}
