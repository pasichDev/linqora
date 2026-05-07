package monitors

// MonitorInfo represents metadata about a physical display.
type MonitorInfo struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	IsPrimary   bool   `json:"is_primary"`
	Width       int    `json:"width"`
	Height      int    `json:"height"`
	RefreshRate int    `json:"refresh_rate"`
	X           int    `json:"x"`
	Y           int    `json:"y"`
}

// Resolution represents a display mode.
type Resolution struct {
	Width       int `json:"width"`
	Height      int `json:"height"`
	RefreshRate int `json:"refresh_rate"`
}

// GetMonitors returns a list of all connected displays.
func GetMonitors() ([]MonitorInfo, error) {
	return platformGetMonitors()
}

// SetResolution changes the resolution for a specific monitor.
func SetResolution(monitorID string, width, height, refreshRate int) error {
	return platformSetResolution(monitorID, width, height, refreshRate)
}

// SetPrimary sets the specified monitor as the primary display.
func SetPrimary(monitorID string) error {
	return platformSetPrimary(monitorID)
}
