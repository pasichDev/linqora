//go:build windows

package capabilities

import (
	"os/exec"
	"strings"
	"syscall"
)

func platformFeatures() Features {
	return Features{
		KeyboardHotkeys:   true,
		KeyboardType:      true,
		Clipboard:         true,
		DisplayBrightness: hasBacklight(),
		DisplaySleepWake:  true,
		StartupManager:    true,
		ProcessManager:    true,
		MonitorControl:    true,
		CpuTemperature:    true,
		FileBrowser:       true,
		Scripts:           true,
	}
}

// hasBacklight returns true if WMI reports at least one backlight-capable monitor.
func hasBacklight() bool {
	cmd := exec.Command("powershell", "-NoProfile", "-NonInteractive", "-Command",
		`(Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightness -ErrorAction SilentlyContinue).Count`)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	out, err := cmd.Output()
	if err != nil {
		return false
	}
	trimmed := strings.TrimSpace(string(out))
	return trimmed != "0" && trimmed != ""
}
