package startup

// IsSupported reports whether startup management is available on this platform.
func IsSupported() bool { return isSupported() }

// IsEnabled reports whether the app is registered for auto-start on login.
func IsEnabled() (bool, error) { return isEnabled() }

// Enable registers the app to launch automatically on user login.
func Enable() error { return enable() }

// Disable removes the app from auto-start on login.
func Disable() error { return disable() }

// Entry describes a single startup program registry entry.
type Entry struct {
	Name    string `json:"name"`
	Command string `json:"command"`
	Enabled bool   `json:"enabled"`
}

// ListEntries returns all startup entries visible to the current user.
// On Windows this includes both HKCU (user) and HKLM (machine-wide) Run keys.
// Entries from HKLM are included but cannot be toggled (requires elevation).
func ListEntries() ([]Entry, error) { return listEntries() }

// SetEntry enables or disables a startup entry by name.
// enable=true adds or updates the entry in the HKCU Run key;
// enable=false deletes the value from HKCU Run.
func SetEntry(name string, enabled bool) error { return setEntry(name, enabled) }
