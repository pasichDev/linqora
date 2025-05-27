package power

import (
	"fmt"
	"log"
	"os/exec"
	"runtime"
)

type PowerCommand struct {
	Action Action `json:"action"`
}

// Action represents the type of power action
type Action int

const (
	// Shutdown - power off the computer
	Shutdown Action = iota
	// Restart - reboot the computer
	Restart
	// Lock - lock the screen
	Lock
)

// ExecutePowerAction performs a power management action
func ExecutePowerAction(action Action) error {
	// For lock action we don't need to check if the system is already locked
	if action != Lock {
		// Check the lock state
		locked, err := IsSystemLocked()
		if err != nil {
			log.Printf("Warning: Failed to check system lock state: %v", err)
			locked = IsDeviceLocked()
		}

		if locked {
			return fmt.Errorf("device is locked, power action %d not permitted", action)
		}
	}

	switch runtime.GOOS {
	case "windows":
		return executeWindowsAction(action)
	case "linux":
		return executeLinuxAction(action)
	case "darwin":
		return executeMacOSAction(action)
	default:
		return fmt.Errorf("unsupported operating system: %s", runtime.GOOS)
	}
}

// executeWindowsAction performs a power command in Windows
func executeWindowsAction(action Action) error {
	var cmd *exec.Cmd

	switch action {
	case Shutdown:
		cmd = exec.Command("shutdown", "/s", "/t", "0")
	case Restart:
		cmd = exec.Command("shutdown", "/r", "/t", "0")
	case Lock:
		cmd = exec.Command("rundll32.exe", "user32.dll,LockWorkStation")
	default:
		return fmt.Errorf("unknown power action: %d", action)
	}

	log.Printf("Executing Windows power command: %v", cmd.Args)
	return cmd.Run()
}

// executeLinuxAction performs a power command in Linux
func executeLinuxAction(action Action) error {
	var cmd *exec.Cmd

	switch action {
	case Shutdown:
		cmd = exec.Command("systemctl", "poweroff")
	case Restart:
		cmd = exec.Command("systemctl", "reboot")
	case Lock:
		// Try several screen locking methods for different desktop environments
		if _, err := exec.LookPath("gnome-screensaver-command"); err == nil {
			cmd = exec.Command("gnome-screensaver-command", "--lock")
		} else if _, err := exec.LookPath("loginctl"); err == nil {
			cmd = exec.Command("loginctl", "lock-session")
		} else if _, err := exec.LookPath("xdg-screensaver"); err == nil {
			cmd = exec.Command("xdg-screensaver", "lock")
		} else {
			return fmt.Errorf("no suitable screen lock command found")
		}
	default:
		return fmt.Errorf("unknown power action: %d", action)
	}

	log.Printf("Executing Linux power command: %v", cmd.Args)
	return cmd.Run()
}

// executeMacOSAction performs a power command in macOS
func executeMacOSAction(action Action) error {
	var cmd *exec.Cmd

	switch action {
	case Shutdown:
		cmd = exec.Command("osascript", "-e", "tell app \"System Events\" to shut down")
	case Restart:
		cmd = exec.Command("osascript", "-e", "tell app \"System Events\" to restart")
	case Lock:
		cmd = exec.Command("osascript", "-e", "tell application \"System Events\" to keystroke \"q\" using {command down, control down}")
	default:
		return fmt.Errorf("unknown power action: %d", action)
	}

	log.Printf("Executing macOS power command: %v", cmd.Args)
	return cmd.Run()
}
