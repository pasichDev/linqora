package power

import (
	"context"
	"log/slog"
	"sync"
	"time"
)

var (
	deviceLocked     bool
	deviceLockedTime time.Time
	lockMutex        sync.RWMutex
)

// StartLockStateMonitor watches the OS lock state and synchronises the internal
// flag. The goroutine exits when ctx is cancelled, so it stops cleanly on
// server shutdown (previously it leaked forever with time.Sleep).
func StartLockStateMonitor(ctx context.Context) {
	go func() {
		ticker := time.NewTicker(5 * time.Second)
		defer ticker.Stop()

		for {
			select {
			case <-ticker.C:
				if IsDeviceLocked() {
					systemLocked, err := IsSystemLocked()
					if err != nil {
						slog.Error("Error checking system lock state", "err", err)
						continue
					}
					if !systemLocked {
						slog.Info("System unlock detected, updating state")
						SetDeviceLocked(false)
					}
				}
			case <-ctx.Done():
				return
			}
		}
	}()
}

// IsDeviceLocked checks if the device is locked (internal state).
func IsDeviceLocked() bool {
	lockMutex.RLock()
	defer lockMutex.RUnlock()
	return deviceLocked
}

// SetDeviceLocked updates the internal lock state.
func SetDeviceLocked(locked bool) {
	lockMutex.Lock()
	defer lockMutex.Unlock()
	deviceLocked = locked
	if locked {
		deviceLockedTime = time.Now()
	}
}

// GetLockTime returns the time the device was locked.
func GetLockTime() time.Time {
	lockMutex.RLock()
	defer lockMutex.RUnlock()
	return deviceLockedTime
}
