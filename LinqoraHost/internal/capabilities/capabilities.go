package capabilities

import "runtime"

// Features holds boolean flags for each supported host capability.
type Features struct {
	KeyboardHotkeys   bool `json:"keyboard_hotkeys"`
	KeyboardType      bool `json:"keyboard_type"`
	Clipboard         bool `json:"clipboard"`
	DisplayBrightness bool `json:"display_brightness"`
	DisplaySleepWake  bool `json:"display_sleep_wake"`
	StartupManager    bool `json:"startup_manager"`
	ProcessManager    bool `json:"process_manager"`
	MonitorControl    bool `json:"monitor_control"`
	CpuTemperature    bool `json:"cpu_temperature"`
	FileBrowser       bool `json:"file_browser"`
	Scripts           bool `json:"scripts"`
}

// Get returns the capability flags for the current platform.
func Get() Features { return platformFeatures() }

// Platform returns the GOOS string ("windows", "linux", "darwin", …).
func Platform() string { return runtime.GOOS }
