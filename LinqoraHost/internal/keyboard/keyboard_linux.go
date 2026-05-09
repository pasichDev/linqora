//go:build linux

package keyboard

import (
	"fmt"
	"os/exec"
	"strings"
)

var xdotoolMap = map[string]string{
	"ctrl": "ctrl", "alt": "alt", "shift": "shift", "win": "super",
	"tab": "Tab", "esc": "Escape", "enter": "Return", "backspace": "BackSpace",
	"delete": "Delete", "space": "space", "home": "Home", "end": "End",
	"pageup": "Prior", "pagedown": "Next",
	"up": "Up", "down": "Down", "left": "Left", "right": "Right",
	"f1": "F1", "f2": "F2", "f3": "F3", "f4": "F4",
	"f5": "F5", "f6": "F6", "f7": "F7", "f8": "F8",
	"f9": "F9", "f10": "F10", "f11": "F11", "f12": "F12",
	"insert": "Insert", "printscreen": "Print",
}

func platformHandleKey(cmd KeyCommand) error {
	keyName, ok := xdotoolMap[cmd.Key]
	if !ok {
		return fmt.Errorf("keyboard: unknown key %q", cmd.Key)
	}

	parts := make([]string, 0, len(cmd.Modifiers)+1)
	for _, mod := range cmd.Modifiers {
		xm, ok := xdotoolMap[mod]
		if !ok {
			return fmt.Errorf("keyboard: unknown modifier %q", mod)
		}
		parts = append(parts, xm)
	}
	parts = append(parts, keyName)

	return exec.Command("xdotool", "key", strings.Join(parts, "+")).Run()
}

func platformTypeText(text string) error {
	return exec.Command("xdotool", "type", "--clearmodifiers", "--delay", "0", text).Run()
}
