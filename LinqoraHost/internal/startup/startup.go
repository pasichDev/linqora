package startup

// IsSupported reports whether startup management is available on this platform.
func IsSupported() bool { return isSupported() }

// IsEnabled reports whether the app is registered for auto-start on login.
func IsEnabled() (bool, error) { return isEnabled() }

// Enable registers the app to launch automatically on user login.
func Enable() error { return enable() }

// Disable removes the app from auto-start on login.
func Disable() error { return disable() }
