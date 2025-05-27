package power

import (
	"log"
	"sync"
	"time"
)

var (
	deviceLocked     bool
	deviceLockedTime time.Time
	lockMutex        sync.RWMutex
)

// Start monitoring the lock state of the device
func StartLockStateMonitor() {
	go func() {
		for {
			if IsDeviceLocked() {
				// If the internal state is locked, check the system state
				systemLocked, err := IsSystemLocked()
				if err != nil {
					log.Printf("Error checking system lock state: %v", err)
				} else if !systemLocked {
					// System unlocked, update internal state
					log.Printf("System unlock detected, updating state")
					SetDeviceLocked(false)
				}
			}
			time.Sleep(5 * time.Second)
		}
	}()
}

// Checks if the device is locked
func IsDeviceLocked() bool {
	lockMutex.RLock()
	defer lockMutex.RUnlock()
	return deviceLocked
}

// Sets the locking status of the device
func SetDeviceLocked(locked bool) {
	lockMutex.Lock()
	defer lockMutex.Unlock()
	deviceLocked = locked
	if locked {
		deviceLockedTime = time.Now()
	}
}

// Returns the time when the device was locked
func GetLockTime() time.Time {
	lockMutex.RLock()
	defer lockMutex.RUnlock()
	return deviceLockedTime
}
