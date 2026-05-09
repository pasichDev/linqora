//go:build linux

package startup

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const desktopFileName = "linqorahost.desktop"

func isSupported() bool { return true }

func xdgAutostartDir() string {
	if dir := os.Getenv("XDG_CONFIG_HOME"); dir != "" {
		return filepath.Join(dir, "autostart")
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "autostart")
}

func desktopFilePath() string {
	return filepath.Join(xdgAutostartDir(), desktopFileName)
}

func isEnabled() (bool, error) {
	data, err := os.ReadFile(desktopFilePath())
	if os.IsNotExist(err) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	scanner := bufio.NewScanner(strings.NewReader(string(data)))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if strings.EqualFold(line, "hidden=true") || strings.EqualFold(line, "x-gnome-autostart-enabled=false") {
			return false, nil
		}
	}
	return true, nil
}

func enable() error {
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	dir := xdgAutostartDir()
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	content := fmt.Sprintf("[Desktop Entry]\nType=Application\nName=LinqoraHost\nExec=%s\nHidden=false\nX-GNOME-Autostart-enabled=true\n", exe)
	return os.WriteFile(desktopFilePath(), []byte(content), 0644)
}

func disable() error {
	path := desktopFilePath()
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return nil
	}
	return os.Remove(path)
}

func listEntries() ([]Entry, error) {
	dirs := []string{"/etc/xdg/autostart", xdgAutostartDir()}
	seen := make(map[string]Entry)

	for _, dir := range dirs {
		files, _ := filepath.Glob(filepath.Join(dir, "*.desktop"))
		for _, f := range files {
			e, ok := parseDesktopFile(f)
			if ok {
				seen[e.Name] = e
			}
		}
	}

	result := make([]Entry, 0, len(seen))
	for _, e := range seen {
		result = append(result, e)
	}
	return result, nil
}

func parseDesktopFile(path string) (Entry, bool) {
	data, err := os.ReadFile(path)
	if err != nil {
		return Entry{}, false
	}
	var name, command string
	enabled := true
	scanner := bufio.NewScanner(strings.NewReader(string(data)))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		switch {
		case strings.HasPrefix(line, "Name="):
			name = strings.TrimPrefix(line, "Name=")
		case strings.HasPrefix(line, "Exec="):
			command = strings.TrimPrefix(line, "Exec=")
		case strings.EqualFold(line, "hidden=true"):
			enabled = false
		case strings.EqualFold(line, "x-gnome-autostart-enabled=false"):
			enabled = false
		}
	}
	if name == "" {
		name = strings.TrimSuffix(filepath.Base(path), ".desktop")
	}
	return Entry{Name: name, Command: command, Enabled: enabled}, true
}

func setEntry(name string, enabled bool) error {
	userDir := xdgAutostartDir()
	files, _ := filepath.Glob(filepath.Join(userDir, "*.desktop"))
	for _, f := range files {
		if e, ok := parseDesktopFile(f); ok && e.Name == name {
			return toggleDesktopFile(f, enabled)
		}
	}

	// Look in system dir and create a user-level override
	sysFile := filepath.Join("/etc/xdg/autostart", name+".desktop")
	if e, ok := parseDesktopFile(sysFile); ok {
		if err := os.MkdirAll(userDir, 0755); err != nil {
			return err
		}
		content := fmt.Sprintf("[Desktop Entry]\nType=Application\nName=%s\nExec=%s\nHidden=%v\nX-GNOME-Autostart-enabled=%v\n",
			e.Name, e.Command, !enabled, enabled)
		return os.WriteFile(filepath.Join(userDir, filepath.Base(sysFile)), []byte(content), 0644)
	}
	return fmt.Errorf("startup: entry %q not found", name)
}

func toggleDesktopFile(path string, enabled bool) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	lines := strings.Split(string(data), "\n")
	hiddenFound := false
	gnomeFound := false
	for i, line := range lines {
		switch {
		case strings.HasPrefix(strings.TrimSpace(line), "Hidden="):
			lines[i] = fmt.Sprintf("Hidden=%v", !enabled)
			hiddenFound = true
		case strings.HasPrefix(strings.TrimSpace(line), "X-GNOME-Autostart-enabled="):
			lines[i] = fmt.Sprintf("X-GNOME-Autostart-enabled=%v", enabled)
			gnomeFound = true
		}
	}
	if !hiddenFound {
		lines = append(lines, fmt.Sprintf("Hidden=%v", !enabled))
	}
	if !gnomeFound {
		lines = append(lines, fmt.Sprintf("X-GNOME-Autostart-enabled=%v", enabled))
	}
	return os.WriteFile(path, []byte(strings.Join(lines, "\n")), 0644)
}
