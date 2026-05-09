//go:build darwin

package keyboard

import (
	"fmt"
	"os/exec"
	"strings"
)

var osxKeyCode = map[string]int{
	"tab": 48, "esc": 53, "enter": 36, "backspace": 51,
	"delete": 117, "space": 49, "home": 115, "end": 119,
	"pageup": 116, "pagedown": 121,
	"up": 126, "down": 125, "left": 123, "right": 124,
	"f1": 122, "f2": 120, "f3": 99, "f4": 118,
	"f5": 96, "f6": 97, "f7": 98, "f8": 100,
	"f9": 101, "f10": 109, "f11": 103, "f12": 111,
	"insert": 114, "printscreen": 105,
}

var osxModifier = map[string]string{
	"ctrl": "control down", "alt": "option down",
	"shift": "shift down", "win": "command down",
}

func platformHandleKey(cmd KeyCommand) error {
	if _, ok := osxModifier[cmd.Key]; ok {
		return nil // single modifier tap is a no-op on macOS
	}

	code, ok := osxKeyCode[cmd.Key]
	if !ok {
		return fmt.Errorf("keyboard: unknown key %q", cmd.Key)
	}

	mods := make([]string, 0, len(cmd.Modifiers))
	for _, m := range cmd.Modifiers {
		om, ok := osxModifier[m]
		if !ok {
			return fmt.Errorf("keyboard: unknown modifier %q", m)
		}
		mods = append(mods, om)
	}

	var script string
	if len(mods) > 0 {
		script = fmt.Sprintf(
			`tell application "System Events" to key code %d using {%s}`,
			code, strings.Join(mods, ", "))
	} else {
		script = fmt.Sprintf(
			`tell application "System Events" to key code %d`, code)
	}
	return exec.Command("osascript", "-e", script).Run()
}

func platformTypeText(text string) error {
	script := fmt.Sprintf(`tell application "System Events" to keystroke %q`, text)
	return exec.Command("osascript", "-e", script).Run()
}
