package power

import (
	"fmt"
	"log"
)

type PowerCommand struct {
	Action Action `json:"action"`
}

// Action represents the type of power action.
type Action int

const (
	Shutdown Action = iota
	Restart
	Lock
	Sleep
)

// ExecutePowerAction performs a power management action.
// Actual platform implementation is in power_<os>.go.
func ExecutePowerAction(action Action) error {
	if action != Lock {
		locked, err := IsSystemLocked()
		if err != nil {
			log.Printf("Warning: Failed to check system lock state: %v", err)
			locked = IsDeviceLocked()
		}

		if locked {
			return fmt.Errorf("device is locked, power action %d not permitted", action)
		}
	}

	return executePlatformAction(action)
}
