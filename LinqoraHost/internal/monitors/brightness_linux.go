//go:build linux

package monitors

import (
	"fmt"
	"os/exec"
)

func platformSleepDisplay() error {
	return exec.Command("xset", "dpms", "force", "off").Run()
}

func platformWakeDisplay() error {
	return exec.Command("xset", "dpms", "force", "on").Run()
}

func platformSetBrightness(level int) error {
	if level < 0 || level > 100 {
		return fmt.Errorf("brightness: level %d out of range [0,100]", level)
	}
	frac := fmt.Sprintf("%.2f", float64(level)/100.0)
	out, err := exec.Command("xrandr", "--output", "eDP-1", "--brightness", frac).CombinedOutput()
	if err != nil {
		// Try LVDS-1 as fallback name
		out2, err2 := exec.Command("xrandr", "--output", "LVDS-1", "--brightness", frac).CombinedOutput()
		if err2 != nil {
			return fmt.Errorf("brightness: xrandr: %w: %s / %s", err, out, out2)
		}
	}
	return nil
}
