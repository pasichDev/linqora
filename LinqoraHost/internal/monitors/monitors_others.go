//go:build !windows

package monitors

import "fmt"

func platformGetMonitors() ([]MonitorInfo, error) {
	return nil, fmt.Errorf("monitor management is not implemented for this OS")
}

func platformSetResolution(monitorID string, width, height, refreshRate int) error {
	return fmt.Errorf("monitor management is not implemented for this OS")
}

func platformSetPrimary(monitorID string) error {
	return fmt.Errorf("monitor management is not implemented for this OS")
}
