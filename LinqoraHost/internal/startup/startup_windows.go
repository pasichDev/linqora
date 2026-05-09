//go:build windows

package startup

import (
	"bufio"
	"bytes"
	"os"
	"os/exec"
	"strings"
	"syscall"
)

const (
	regPath     = `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
	regPathHKLM = `HKLM\Software\Microsoft\Windows\CurrentVersion\Run`
	appName     = "LinqoraHost"
)

func hiddenCmd(name string, args ...string) *exec.Cmd {
	cmd := exec.Command(name, args...)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	return cmd
}

func isSupported() bool { return true }

func isEnabled() (bool, error) {
	err := hiddenCmd("reg", "query", regPath, "/v", appName).Run()
	return err == nil, nil
}

func enable() error {
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	// --minimized so the window starts hidden in the system tray.
	value := `"` + exe + `" --minimized`
	return hiddenCmd("reg", "add", regPath, "/v", appName, "/t", "REG_SZ", "/d", value, "/f").Run()
}

func disable() error {
	// reg delete exits with code 1 when the value doesn't exist — treat as success.
	hiddenCmd("reg", "delete", regPath, "/v", appName, "/f").Run() //nolint:errcheck
	return nil
}

// parseRegQueryOutput parses `reg query <path>` output and extracts name→value pairs.
// Each data line looks like:
//
//	    AppName    REG_SZ    C:\path\to\app.exe
func parseRegQueryOutput(output []byte) map[string]string {
	result := make(map[string]string)
	scanner := bufio.NewScanner(bytes.NewReader(output))
	for scanner.Scan() {
		line := scanner.Text()
		// Skip header lines (the key path itself and blank lines).
		if !strings.Contains(line, "REG_SZ") {
			continue
		}
		// Tokenise on whitespace runs; format: <name> REG_SZ <value…>
		parts := strings.SplitN(strings.TrimSpace(line), "REG_SZ", 2)
		if len(parts) != 2 {
			continue
		}
		name := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])
		if name != "" {
			result[name] = value
		}
	}
	return result
}

func listEntries() ([]Entry, error) {
	entries := make([]Entry, 0)

	// Read HKCU entries (user-level, can be toggled).
	hkcuEntries := make(map[string]string)
	if out, err := hiddenCmd("reg", "query", regPath).Output(); err == nil {
		hkcuEntries = parseRegQueryOutput(out)
	}
	for name, cmd := range hkcuEntries {
		entries = append(entries, Entry{Name: name, Command: cmd, Enabled: true})
	}

	// Read HKLM entries (machine-wide, read-only for normal users).
	// Only include entries not already listed from HKCU.
	if out, err := hiddenCmd("reg", "query", regPathHKLM).Output(); err == nil {
		hklmEntries := parseRegQueryOutput(out)
		for name, cmd := range hklmEntries {
			if _, inHKCU := hkcuEntries[name]; !inHKCU {
				// HKLM entries are always "enabled" (we can't easily disable them without elevation).
				entries = append(entries, Entry{Name: name, Command: cmd, Enabled: true})
			}
		}
	}

	return entries, nil
}

func setEntry(name string, enabled bool) error {
	if enabled {
		// We need to know the command — fetch the current value first.
		out, err := hiddenCmd("reg", "query", regPath, "/v", name).Output()
		if err != nil {
			// Value does not exist; cannot enable without a command.
			return err
		}
		entries := parseRegQueryOutput(out)
		cmd, ok := entries[name]
		if !ok || cmd == "" {
			// Also try to find it in HKLM to re-add to HKCU.
			out2, err2 := hiddenCmd("reg", "query", regPathHKLM, "/v", name).Output()
			if err2 != nil {
				return err
			}
			entries2 := parseRegQueryOutput(out2)
			cmd, ok = entries2[name]
			if !ok || cmd == "" {
				return err
			}
		}
		return hiddenCmd("reg", "add", regPath, "/v", name, "/t", "REG_SZ", "/d", cmd, "/f").Run()
	}

	// Disable: remove the HKCU value (ignore "not found" errors).
	hiddenCmd("reg", "delete", regPath, "/v", name, "/f").Run() //nolint:errcheck
	return nil
}
