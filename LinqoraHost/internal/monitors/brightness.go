package monitors

// SetBrightness sets the display brightness (0-100).
func SetBrightness(level int) error { return platformSetBrightness(level) }

// SleepDisplay turns off the display.
func SleepDisplay() error { return platformSleepDisplay() }

// WakeDisplay turns on the display.
func WakeDisplay() error { return platformWakeDisplay() }
