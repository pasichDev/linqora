package metrics

import (
	"LinqoraHost/internal/privileges"
	"math"
	"os/exec"
	"runtime"
	"strconv"
	"strings"

	"github.com/shirou/gopsutil/mem"
)

type RamMetrics struct {
	Timestamp   string  `json:"timestamp"`
	Usage       float64 `json:"usage"`
	LoadPercent float64 `json:"loadPercent"`
}

type RAMInfo struct {
	Type      string  // Memory type (DDR3, DDR4, etc)
	Frequency int     // Frequency in MHz
	Slots     int     // Number of slots
	Used      float64 // Used memory in GB
	Total     float64 // Total memory in GB
}

func GetRamMetrics() (RamMetrics, error) {

	v, _ramErr := mem.VirtualMemory()

	if _ramErr != nil {
		return RamMetrics{}, _ramErr
	}

	ram := RamMetrics{
		LoadPercent: math.Round(v.UsedPercent),
		Usage:       math.Round((float64(v.Used)/1_000_000_000)*100) / 100,
	}
	return ram, nil
}

// GetRAMInfo returns information about the system RAM.
func GetRAMInfo() (RAMInfo, error) {
	info := RAMInfo{
		Type:      "Unknown",
		Frequency: 0,
		Slots:     0,
	}

	// Get used/total memory
	v, err := mem.VirtualMemory()
	if err == nil {
		info.Used = math.Round((float64(v.Used)/1_000_000_000)*100) / 100
		info.Total = math.Round((float64(v.Total)/1_000_000_000)*100) / 100
	}

	switch runtime.GOOS {
	case "linux":
		if privileges.CheckAdminPrivileges() || privileges.CanExecuteSudo() {
			// Build the command correctly: exec.Command never passes through a shell,
			// so "sudo dmidecode" as a single string would look for a binary literally
			// named "sudo dmidecode". We must pass them as separate arguments.
			var cmd *exec.Cmd
			if privileges.CheckAdminPrivileges() {
				cmd = exec.Command("dmidecode", "--type", "memory")
			} else {
				cmd = exec.Command("sudo", "dmidecode", "--type", "memory")
			}

			output, err := cmd.Output()
			if err == nil {
				outputStr := string(output)

				if strings.Contains(outputStr, "DDR5") {
					info.Type = "DDR5"
				} else if strings.Contains(outputStr, "DDR4") {
					info.Type = "DDR4"
				} else if strings.Contains(outputStr, "DDR3") {
					info.Type = "DDR3"
				}

				// Count memory slots
				info.Slots = strings.Count(outputStr, "Memory Device")

				// Parse frequency
				freqLines := strings.Split(outputStr, "Speed: ")
				if len(freqLines) > 1 {
					freqStr := strings.Split(freqLines[1], " ")[0]
					freq, err := strconv.Atoi(freqStr)
					if err == nil {
						info.Frequency = freq
					}
				}
			}
		}

	case "windows":
		cmd := exec.Command("powershell", "-Command",
			"Get-WmiObject -Class Win32_PhysicalMemory | Select-Object Speed, MemoryType, DeviceLocator | Format-List")
		output, err := cmd.Output()
		if err == nil {
			outputStr := string(output)

			// Count slots
			info.Slots = strings.Count(outputStr, "DeviceLocator")

			// Parse frequency
			freqLines := strings.Split(outputStr, "Speed : ")
			if len(freqLines) > 1 {
				freqStr := strings.TrimSpace(strings.Split(freqLines[1], "\n")[0])
				freq, err := strconv.Atoi(freqStr)
				if err == nil {
					info.Frequency = freq
				}
			}

			// Determine memory type by MemoryType code
			if strings.Contains(outputStr, "MemoryType : 24") {
				info.Type = "DDR3"
			} else if strings.Contains(outputStr, "MemoryType : 26") {
				info.Type = "DDR4"
			} else if strings.Contains(outputStr, "MemoryType : 28") {
				info.Type = "DDR5"
			}
		}
	}

	return info, nil
}
