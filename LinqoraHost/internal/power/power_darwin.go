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
		cmd = exec.Command("osascript", "-e", "tell app \"System Events\" to shut down")
	case Restart:
		cmd = exec.Command("osascript", "-e", "tell app \"System Events\" to restart")
	case Lock:
		cmd = exec.Command("osascript", "-e",
			"tell application \"System Events\" to keystroke \"q\" using {command down, control down}")
	case Sleep:
		cmd = exec.Command("pmset", "sleepnow")
	default:
		return fmt.Errorf("unknown power action: %d", action)
	}

	log.Printf("Executing macOS power command: %v", cmd.Args)
	return cmd.Run()
}
