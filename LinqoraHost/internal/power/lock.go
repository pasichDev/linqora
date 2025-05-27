package power

import (
	"fmt"
	"log"
	"os/exec"
	"runtime"
	"strings"
)

// Checks if the system is locked at the OS level
func IsSystemLocked() (bool, error) {
	switch runtime.GOOS {
	case "windows":
		return isWindowsLocked()
	case "linux":
		return isLinuxLocked()
	case "darwin":
		return isMacOSLocked()
	default:
		return false, fmt.Errorf("unsupported operating system: %s", runtime.GOOS)
	}
}

// Check if Windows is locked
func isWindowsLocked() (bool, error) {
	// Try to determine lock state by querying session state
	cmd := exec.Command("powershell", "-Command",
		"(Get-Process -Name LogonUI -ErrorAction SilentlyContinue) -ne $null")
	output, err := cmd.Output()
	if err != nil {
		return false, err
	}

	return strings.TrimSpace(string(output)) == "True", nil
}

// Fixed function to check if Linux is locked
func isLinuxLocked() (bool, error) {
	log.Println("Checking Linux lock state...")

	// For GNOME
	if _, err := exec.LookPath("gnome-screensaver-command"); err == nil {
		cmd := exec.Command("gnome-screensaver-command", "--query")
		output, err := cmd.Output()
		if err == nil {
			log.Printf("gnome-screensaver-command output: %s", string(output))
			if strings.Contains(string(output), "active") {
				return true, nil
			}
			return false, nil
		}
		log.Printf("gnome-screensaver-command error: %v", err)
	}

	// Get the current user session
	if _, err := exec.LookPath("loginctl"); err == nil {
		// First, get the session ID
		sessionCmd := exec.Command("bash", "-c", "loginctl | grep $(whoami) | awk '{print $1}'")
		sessionID, err := sessionCmd.Output()
		if err == nil && len(sessionID) > 0 {
			// Now check the lock state for this session
			id := strings.TrimSpace(string(sessionID))
			cmd := exec.Command("loginctl", "show-session", id, "--property=LockedHint")
			output, err := cmd.Output()
			if err == nil {
				log.Printf("loginctl lock check output: %s", string(output))
				if strings.Contains(string(output), "LockedHint=yes") {
					return true, nil
				}
				return false, nil
			}
			log.Printf("loginctl error: %v", err)
		}
	}

	// Alternative method to check lock state via dbus
	if _, err := exec.LookPath("dbus-send"); err == nil {
		cmd := exec.Command("bash", "-c",
			"dbus-send --session --dest=org.gnome.ScreenSaver --type=method_call --print-reply "+
				"/org/gnome/ScreenSaver org.gnome.ScreenSaver.GetActive | grep 'boolean true'")
		if err := cmd.Run(); err == nil {
			// If the command executed without errors and found 'boolean true', the screen is locked
			return true, nil
		}
		// If the command executed with an error or did not find 'boolean true', the screen is not locked
		return false, nil
	}

	// General method for many DE via xdg-screensaver status
	if _, err := exec.LookPath("xdg-screensaver"); err == nil {
		cmd := exec.Command("xdg-screensaver", "status")
		output, err := cmd.Output()
		if err == nil {
			log.Printf("xdg-screensaver output: %s", string(output))
			return strings.Contains(string(output), "on"), nil
		}
	}

	// If all lock check methods failed, fall back to internal state
	log.Println("All lock check methods failed, falling back to internal state")
	return IsDeviceLocked(), nil
}

// Check if macOS is locked
func isMacOSLocked() (bool, error) {
	cmd := exec.Command("bash", "-c",
		"/System/Library/PrivateFrameworks/login.framework/Versions/Current/Helpers/LoginUIBundle.login/Contents/MacOS/LoginUIBundle -status | grep 'CGSSessionScreenIsLocked = true'")

	output, err := cmd.Output()
	if err != nil {
		return false, err
	}

	return strings.TrimSpace(string(output)) != "", nil
}
