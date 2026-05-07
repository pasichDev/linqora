package power

import (
	"fmt"
	"log"
	"os/exec"

	"golang.org/x/sys/windows"
)

var (
	modUser32           = windows.NewLazySystemDLL("user32.dll")
	procLockWorkStation = modUser32.NewProc("LockWorkStation")
)

func executePlatformAction(action Action) error {
	switch action {
	case Shutdown:
		cmd := exec.Command("shutdown", "/s", "/t", "0")
		log.Printf("Executing Windows shutdown: %v", cmd.Args)
		return cmd.Run()
	case Restart:
		cmd := exec.Command("shutdown", "/r", "/t", "0")
		log.Printf("Executing Windows restart: %v", cmd.Args)
		return cmd.Run()
	case Lock:
		return lockWorkStationAPI()
	default:
		return fmt.Errorf("unknown power action: %d", action)
	}
}

// lockWorkStationAPI calls LockWorkStation from user32.dll directly instead of
// spawning a rundll32 subprocess, which removes the process-creation overhead
// and makes the call synchronous with a proper error return.
func lockWorkStationAPI() error {
	r, _, err := procLockWorkStation.Call()
	if r == 0 {
		return fmt.Errorf("LockWorkStation failed: %w", err)
	}
	log.Println("LockWorkStation called via Win32 API")
	return nil
}
