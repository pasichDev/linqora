package power

import (
	"log"
	"os/exec"
	"strings"
)

func isPlatformSystemLocked() (bool, error) {
	log.Println("Checking Linux lock state...")

	if _, err := exec.LookPath("gnome-screensaver-command"); err == nil {
		cmd := exec.Command("gnome-screensaver-command", "--query")
		if output, err := cmd.Output(); err == nil {
			return strings.Contains(string(output), "active"), nil
		}
	}

	if _, err := exec.LookPath("loginctl"); err == nil {
		sessionCmd := exec.Command("bash", "-c", "loginctl | grep $(whoami) | awk '{print $1}'")
		if sessionID, err := sessionCmd.Output(); err == nil && len(sessionID) > 0 {
			id := strings.TrimSpace(string(sessionID))
			cmd := exec.Command("loginctl", "show-session", id, "--property=LockedHint")
			if output, err := cmd.Output(); err == nil {
				return strings.Contains(string(output), "LockedHint=yes"), nil
			}
		}
	}

	if _, err := exec.LookPath("dbus-send"); err == nil {
		cmd := exec.Command("bash", "-c",
			"dbus-send --session --dest=org.gnome.ScreenSaver --type=method_call --print-reply "+
				"/org/gnome/ScreenSaver org.gnome.ScreenSaver.GetActive | grep 'boolean true'")
		if err := cmd.Run(); err == nil {
			return true, nil
		}
		return false, nil
	}

	if _, err := exec.LookPath("xdg-screensaver"); err == nil {
		cmd := exec.Command("xdg-screensaver", "status")
		if output, err := cmd.Output(); err == nil {
			return strings.Contains(string(output), "on"), nil
		}
	}

	return IsDeviceLocked(), nil
}
