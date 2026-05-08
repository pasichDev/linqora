//go:build windows

package startup

import (
	"os"
	"os/exec"
)

const (
	regPath = `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
	appName = "LinqoraHost"
)

func isSupported() bool { return true }

func isEnabled() (bool, error) {
	err := exec.Command("reg", "query", regPath, "/v", appName).Run()
	return err == nil, nil
}

func enable() error {
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	// --minimized so the window starts hidden in the system tray.
	value := `"` + exe + `" --minimized`
	return exec.Command("reg", "add", regPath, "/v", appName, "/t", "REG_SZ", "/d", value, "/f").Run()
}

func disable() error {
	// reg delete exits with code 1 when the value doesn't exist — treat as success.
	exec.Command("reg", "delete", regPath, "/v", appName, "/f").Run() //nolint:errcheck
	return nil
}
