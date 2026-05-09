//go:build !windows && !linux && !darwin

package capabilities

func platformFeatures() Features {
	return Features{ProcessManager: true, FileBrowser: true, Scripts: true}
}
