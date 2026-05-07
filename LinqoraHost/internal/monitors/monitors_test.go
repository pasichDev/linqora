package monitors

import "testing"

func TestGetMonitors(t *testing.T) {
	// This will call platformGetMonitors
	list, err := GetMonitors()
	if err != nil {
		// On some headless CI it might fail, but let's see
		t.Logf("GetMonitors returned error: %v (expected on headless)", err)
		return
	}

	for _, m := range list {
		if m.ID == "" {
			t.Error("Monitor ID should not be empty")
		}
		t.Logf("Found monitor: %s (%dx%d)", m.Name, m.Width, m.Height)
	}
}

func TestResolutionStruct(t *testing.T) {
	r := Resolution{Width: 1920, Height: 1080, RefreshRate: 60}
	if r.Width != 1920 {
		t.Errorf("Expected 1920, got %d", r.Width)
	}
}
