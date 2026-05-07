package power

// IsSystemLocked delegates to the platform-specific implementation in lock_<os>.go.
func IsSystemLocked() (bool, error) {
	return isPlatformSystemLocked()
}
