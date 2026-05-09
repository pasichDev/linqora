//go:build darwin

package startup

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

const (
	plistLabel    = "com.linqora.host"
	plistFilename = plistLabel + ".plist"
)

func isSupported() bool { return true }

func launchAgentsDir() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, "Library", "LaunchAgents"), nil
}

func plistPath() (string, error) {
	dir, err := launchAgentsDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, plistFilename), nil
}

func isEnabled() (bool, error) {
	err := exec.Command("launchctl", "list", plistLabel).Run()
	return err == nil, nil
}

func enable() error {
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	dir, err := launchAgentsDir()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	plist := fmt.Sprintf(`<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>%s</string>
	<key>ProgramArguments</key>
	<array>
		<string>%s</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<false/>
</dict>
</plist>
`, plistLabel, exe)

	path, err := plistPath()
	if err != nil {
		return err
	}
	if err := os.WriteFile(path, []byte(plist), 0644); err != nil {
		return err
	}
	out, err := exec.Command("launchctl", "load", path).CombinedOutput()
	if err != nil {
		return fmt.Errorf("launchctl load: %w: %s", err, out)
	}
	return nil
}

func disable() error {
	path, err := plistPath()
	if err != nil {
		return err
	}
	exec.Command("launchctl", "unload", path).Run() //nolint:errcheck
	if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
		return err
	}
	return nil
}

func listEntries() ([]Entry, error) {
	path, err := plistPath()
	if err != nil {
		return nil, err
	}
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return []Entry{}, nil
	}
	enabled, _ := isEnabled()
	exe, _ := os.Executable()
	return []Entry{{Name: "LinqoraHost", Command: exe, Enabled: enabled}}, nil
}

func setEntry(name string, enabled bool) error {
	if name != "LinqoraHost" {
		return fmt.Errorf("startup: unknown entry %q", name)
	}
	if enabled {
		return enable()
	}
	return disable()
}
