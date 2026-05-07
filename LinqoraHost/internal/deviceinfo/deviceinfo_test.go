package deviceinfo

import "testing"

func TestGetDeviceInfo(t *testing.T) {
	info := GetDeviceInfo()
	
	if info.Hostname == "" {
		t.Error("Hostname should not be empty")
	}
	if info.OS == "" {
		t.Error("OS should not be empty")
	}
	if info.IP == "" {
		t.Error("IP should not be empty")
	}
	
	t.Logf("Running on %s (IP: %s)", info.OS, info.IP)
}
