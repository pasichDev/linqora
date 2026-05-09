//go:build linux

package capabilities

func platformFeatures() Features {
	return Features{
		KeyboardHotkeys: true, KeyboardType: true, Clipboard: true,
		DisplayBrightness: true, DisplaySleepWake: true,
		ProcessManager: true, MonitorControl: true,
		FileBrowser: true, Scripts: true,
	}
}
