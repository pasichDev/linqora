//go:build darwin

package monitors

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
)

// system_profiler JSON shapes
type spDisplaysRoot struct {
	SPDisplaysDataType []spGPUEntry `json:"SPDisplaysDataType"`
}
type spGPUEntry struct {
	Displays []spDisplayEntry `json:"spdisplays_ndrvs"`
}
type spDisplayEntry struct {
	Name       string `json:"_name"`
	Resolution string `json:"_spdisplays_resolution"`
	Main       string `json:"spdisplays_main"`
	Online     string `json:"spdisplays_online"`
	DisplayID  string `json:"_spdisplays_displayID"`
}

func platformGetMonitors() ([]MonitorInfo, error) {
	out, err := exec.Command("system_profiler", "SPDisplaysDataType", "-json").Output()
	if err != nil {
		return nil, fmt.Errorf("system_profiler: %w", err)
	}

	var root spDisplaysRoot
	if err := json.Unmarshal(out, &root); err != nil {
		return nil, fmt.Errorf("system_profiler parse: %w", err)
	}

	var result []MonitorInfo
	idx := 0
	for _, gpu := range root.SPDisplaysDataType {
		for _, d := range gpu.Displays {
			if d.Online == "spdisplays_no" {
				continue
			}
			id := d.DisplayID
			if id == "" {
				id = fmt.Sprintf("display-%d", idx)
			}
			info := MonitorInfo{
				ID:        id,
				Name:      d.Name,
				IsPrimary: d.Main == "spdisplays_yes",
			}
			// Resolution string: "2560 x 1600 Retina" or "1920 x 1080"
			parts := strings.Fields(d.Resolution)
			if len(parts) >= 3 && parts[1] == "x" {
				info.Width, _ = strconv.Atoi(parts[0])
				info.Height, _ = strconv.Atoi(strings.TrimRight(parts[2], ","))
			}
			result = append(result, info)
			idx++
		}
	}
	return result, nil
}

func platformSetResolution(monitorID string, width, height, refreshRate int) error {
	// displayplacer is the standard tool for this on macOS.
	// Install: brew install jakehilborn/jakehilborn/displayplacer
	mode := fmt.Sprintf("%dx%d", width, height)
	if refreshRate > 0 {
		mode = fmt.Sprintf("%dx%d:%d", width, height, refreshRate)
	}
	out, err := exec.Command("displayplacer",
		fmt.Sprintf("id:%s", monitorID),
		fmt.Sprintf("mode:%s", mode),
	).CombinedOutput()
	if err != nil {
		return fmt.Errorf("displayplacer: %w: %s\nhint: brew install jakehilborn/jakehilborn/displayplacer", err, out)
	}
	return nil
}

func platformSetPrimary(monitorID string) error {
	out, err := exec.Command("displayplacer",
		fmt.Sprintf("id:%s", monitorID),
		"origin:(0,0)",
	).CombinedOutput()
	if err != nil {
		return fmt.Errorf("displayplacer: %w: %s\nhint: brew install jakehilborn/jakehilborn/displayplacer", err, out)
	}
	return nil
}
