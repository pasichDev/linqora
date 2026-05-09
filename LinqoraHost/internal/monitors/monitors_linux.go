//go:build linux

package monitors

import (
	"bufio"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
)

func platformGetMonitors() ([]MonitorInfo, error) {
	out, err := exec.Command("xrandr", "--query").Output()
	if err != nil {
		return nil, fmt.Errorf("xrandr: %w", err)
	}

	var result []MonitorInfo
	var current *MonitorInfo

	scanner := bufio.NewScanner(strings.NewReader(string(out)))
	for scanner.Scan() {
		line := scanner.Text()

		// Display header: "eDP-1 connected [primary] 1920x1080+0+0 ..."
		if isConnectedLine(line) {
			if current != nil {
				result = append(result, *current)
			}
			current = parseConnectedLine(line)
			continue
		}

		// Mode line with active refresh rate marked by '*'
		if current != nil && strings.Contains(line, "*") {
			if rate := parseActiveRate(line); rate > 0 {
				current.RefreshRate = rate
			}
		}
	}

	if current != nil {
		result = append(result, *current)
	}
	return result, nil
}

func isConnectedLine(line string) bool {
	fields := strings.Fields(line)
	return len(fields) >= 3 && fields[1] == "connected" && fields[2] != "disconnected"
}

func parseConnectedLine(line string) *MonitorInfo {
	fields := strings.Fields(line)
	name := fields[0]
	isPrimary := false

	// Find the geometry field: "WxH+X+Y"
	var geo string
	for _, f := range fields[2:] {
		if strings.Contains(f, "x") && strings.Contains(f, "+") {
			geo = f
			break
		}
		if f == "primary" {
			isPrimary = true
		}
	}

	if geo == "" {
		return nil
	}

	// Parse "WxH+X+Y" — also handle negative offsets like "WxH+-100+0"
	plusIdx := strings.Index(geo, "+")
	wh := geo[:plusIdx]
	rest := geo[plusIdx+1:]

	whParts := strings.SplitN(wh, "x", 2)
	if len(whParts) != 2 {
		return nil
	}
	w, _ := strconv.Atoi(whParts[0])
	h, _ := strconv.Atoi(whParts[1])

	// rest is "X+Y" or "-X+Y"
	secondPlus := strings.Index(rest, "+")
	var x, y int
	if secondPlus < 0 {
		x, _ = strconv.Atoi(rest)
	} else {
		x, _ = strconv.Atoi(rest[:secondPlus])
		y, _ = strconv.Atoi(rest[secondPlus+1:])
	}

	return &MonitorInfo{
		ID:        name,
		Name:      name,
		IsPrimary: isPrimary,
		Width:     w,
		Height:    h,
		X:         x,
		Y:         y,
	}
}

func parseActiveRate(line string) int {
	for _, field := range strings.Fields(line) {
		if strings.Contains(field, "*") {
			rateStr := strings.Trim(field, "*+")
			if rate, err := strconv.ParseFloat(rateStr, 64); err == nil {
				return int(rate + 0.5)
			}
		}
	}
	return 0
}

func platformSetResolution(monitorID string, width, height, refreshRate int) error {
	args := []string{"--output", monitorID, "--mode", fmt.Sprintf("%dx%d", width, height)}
	if refreshRate > 0 {
		args = append(args, "--rate", strconv.Itoa(refreshRate))
	}
	out, err := exec.Command("xrandr", args...).CombinedOutput()
	if err != nil {
		return fmt.Errorf("xrandr: %w: %s", err, string(out))
	}
	return nil
}

func platformSetPrimary(monitorID string) error {
	out, err := exec.Command("xrandr", "--output", monitorID, "--primary").CombinedOutput()
	if err != nil {
		return fmt.Errorf("xrandr: %w: %s", err, string(out))
	}
	return nil
}
