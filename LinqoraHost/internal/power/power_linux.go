package power

import (
	"fmt"
	"log"
	"os/exec"
)

func executePlatformAction(action Action) error {
	var cmd *exec.Cmd

	switch action {
	case Shutdown:
		cmd = exec.Command("systemctl", "poweroff")
	case Restart:
		cmd = exec.Command("systemctl", "reboot")
	case Lock:
		if _, err := exec.LookPath("gnome-screensaver-command"); err == nil {
			cmd = exec.Command("gnome-screensaver-command", "--lock")
		} else if _, err := exec.LookPath("loginctl"); err == nil {
			cmd = exec.Command("loginctl", "lock-session")
		} else if _, err := exec.LookPath("xdg-screensaver"); err == nil {
			cmd = exec.Command("xdg-screensaver", "lock")
		} else {
			return fmt.Errorf("no suitable screen lock command found")
		}
	case Sleep:
		cmd = exec.Command("systemctl", "suspend")
	default:
		return fmt.Errorf("unknown power action: %d", action)
	}

	log.Printf("Executing Linux power command: %v", cmd.Args)
	return cmd.Run()
}
