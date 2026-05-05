//go:build linux

package mouse

import (
	"fmt"
	"os/exec"
	"strconv"
)

func platformHandleMouse(cmd MouseCommand) error {
	switch cmd.Action {
	case ActionMove:
		return exec.Command(
			"xdotool", "mousemove_relative", "--",
			strconv.Itoa(cmd.DX), strconv.Itoa(cmd.DY),
		).Run()
	case ActionLeftClick:
		return exec.Command("xdotool", "click", "1").Run()
	case ActionRightClick:
		return exec.Command("xdotool", "click", "3").Run()
	case ActionMiddleClick:
		return exec.Command("xdotool", "click", "2").Run()
	case ActionScroll:
		button := "4" // scroll up
		if cmd.Delta < 0 {
			button = "5" // scroll down
		}
		return exec.Command("xdotool", "click", button).Run()
	case ActionDoubleClick:
		return exec.Command("xdotool", "click", "--repeat", "2", "1").Run()
	default:
		return fmt.Errorf("mouse: unknown action %d", cmd.Action)
	}
}
