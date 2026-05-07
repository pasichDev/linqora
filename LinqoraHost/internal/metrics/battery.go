package metrics

import (
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
)

// BatteryInfo reports the system battery status.
// IsPresent is false on desktop machines without a battery.
type BatteryInfo struct {
	IsPresent  bool   `json:"isPresent"`
	Level      int    `json:"level"` // 0–100 %
	IsCharging bool   `json:"isCharging"`
	Status     string `json:"status"` // Charging | Discharging | Full | Unknown
}

// GetBatteryInfo returns battery information for the current platform.
func GetBatteryInfo() (BatteryInfo, error) {
	switch runtime.GOOS {
	case "linux":
		return getLinuxBattery()
	case "windows":
		return getWindowsBattery()
	case "darwin":
		return getMacOSBattery()
	default:
		return BatteryInfo{}, nil
	}
}

// ── Linux ────────────────────────────────────────────────────────────────────

func getLinuxBattery() (BatteryInfo, error) {
	const batDir = "/sys/class/power_supply/"

	entries, err := os.ReadDir(batDir)
	if err != nil {
		return BatteryInfo{}, nil
	}

	for _, e := range entries {
		if !strings.HasPrefix(e.Name(), "BAT") {
			continue
		}

		base := batDir + e.Name() + "/"
		info := BatteryInfo{IsPresent: true}

		if data, err := os.ReadFile(base + "capacity"); err == nil {
			info.Level, _ = strconv.Atoi(strings.TrimSpace(string(data)))
		}
		if data, err := os.ReadFile(base + "status"); err == nil {
			status := strings.TrimSpace(string(data))
			info.Status = status
			info.IsCharging = status == "Charging" || status == "Full"
		}
		return info, nil
	}

	return BatteryInfo{}, nil
}

// ── Windows ──────────────────────────────────────────────────────────────────

func getWindowsBattery() (BatteryInfo, error) {
	out, err := exec.Command(
		"powershell", "-NoProfile", "-Command",
		`$b = Get-WmiObject -Class Win32_Battery;
		if ($b) { Write-Host "$($b.EstimatedChargeRemaining)|$($b.BatteryStatus)" }`,
	).Output()
	if err != nil || len(strings.TrimSpace(string(out))) == 0 {
		return BatteryInfo{}, nil
	}

	parts := strings.SplitN(strings.TrimSpace(string(out)), "|", 2)
	if len(parts) < 2 {
		return BatteryInfo{}, nil
	}

	level, _ := strconv.Atoi(parts[0])
	// BatteryStatus: 1=Other, 2=Unknown, 3=Fully Charged, 4=Low, 5=Critical,
	//                6=Charging, 7=Charging+High, 8=Charging+Low, 9=Charging+Critical, ...
	battStatus, _ := strconv.Atoi(strings.TrimSpace(parts[1]))

	var status string
	isCharging := false
	switch battStatus {
	case 3:
		status = "Full"
		isCharging = true
	case 6, 7, 8, 9:
		status = "Charging"
		isCharging = true
	default:
		status = "Discharging"
	}

	return BatteryInfo{
		IsPresent:  true,
		Level:      level,
		IsCharging: isCharging,
		Status:     status,
	}, nil
}

// ── macOS ────────────────────────────────────────────────────────────────────

func getMacOSBattery() (BatteryInfo, error) {
	out, err := exec.Command("pmset", "-g", "batt").Output()
	if err != nil {
		return BatteryInfo{}, nil
	}

	s := string(out)
	if !strings.Contains(s, "InternalBattery") {
		return BatteryInfo{}, nil
	}

	info := BatteryInfo{IsPresent: true, Status: "Unknown"}

	// Example line: "-InternalBattery-0 (id=...)	87%; discharging; 3:12 remaining"
	for _, line := range strings.Split(s, "\n") {
		if !strings.Contains(line, "InternalBattery") {
			continue
		}
		if idx := strings.Index(line, "%"); idx > 0 {
			// walk backwards to find the start of the number
			start := idx
			for start > 0 && (line[start-1] >= '0' && line[start-1] <= '9') {
				start--
			}
			info.Level, _ = strconv.Atoi(line[start:idx])
		}
		lower := strings.ToLower(line)
		if strings.Contains(lower, "charging") || strings.Contains(lower, "ac attached") {
			info.IsCharging = true
			info.Status = "Charging"
		} else if strings.Contains(lower, "discharging") {
			info.Status = "Discharging"
		} else if strings.Contains(lower, "finishing charge") || strings.Contains(lower, "charged") {
			info.IsCharging = true
			info.Status = "Full"
		}
		break
	}

	return info, nil
}
