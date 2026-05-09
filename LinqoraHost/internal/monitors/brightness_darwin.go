//go:build darwin

package monitors

import (
	"fmt"
	"os/exec"
)

func platformSleepDisplay() error {
	return exec.Command("pmset", "displaysleepnow").Run()
}

func platformWakeDisplay() error {
	// caffeinate -u asserts user-active for 2 s, which powers on the display
	return exec.Command("caffeinate", "-u", "-t", "2").Run()
}

func platformSetBrightness(level int) error {
	if level < 0 || level > 100 {
		return fmt.Errorf("brightness: level %d out of range [0,100]", level)
	}
	frac := fmt.Sprintf("%.2f", float64(level)/100.0)
	// Prefer the 'brightness' CLI (brew install brightness)
	if out, err := exec.Command("brightness", frac).CombinedOutput(); err == nil {
		_ = out
		return nil
	}
	// Fallback: osascript – requires Accessibility/Screen Recording permission
	script := fmt.Sprintf(
		`tell application "System Events" to set brightness to %s`,
		frac,
	)
	if out, err := exec.Command("osascript", "-e", script).CombinedOutput(); err != nil {
		return fmt.Errorf("brightness: set failed (%w: %s); install 'brightness' via Homebrew for reliable control", err, out)
	}
	return nil
}
