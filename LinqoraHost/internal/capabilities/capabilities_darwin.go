//go:build darwin

package capabilities

func platformFeatures() Features {
	return Features{
		KeyboardHotkeys: true, KeyboardType: true, Clipboard: true,
		ProcessManager: true, FileBrowser: true, Scripts: true,
	}
}
