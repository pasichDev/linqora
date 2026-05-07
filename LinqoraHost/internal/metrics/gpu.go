package metrics

import (
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
)

// GPUInfo holds basic GPU identification and memory data.
type GPUInfo struct {
	Model  string `json:"model"`
	Memory int    `json:"memory"` // MiB
}

// GetGPUInfo returns GPU information for the current platform.
func GetGPUInfo() (GPUInfo, error) {
	switch runtime.GOOS {
	case "linux":
		return getLinuxGPUInfo()
	case "windows":
		return getWindowsGPUInfo()
	case "darwin":
		return getMacOSGPUInfo()
	default:
		return GPUInfo{Model: "Unknown"}, nil
	}
}

// ── Linux ────────────────────────────────────────────────────────────────────

func getLinuxGPUInfo() (GPUInfo, error) {
	// NVIDIA: fastest path.
	if info, ok := nvidiaGPUInfo(); ok {
		return info, nil
	}

	// AMD / Intel: parse lspci.
	out, err := exec.Command("lspci", "-v").Output()
	if err != nil {
		return GPUInfo{Model: "Unknown"}, nil
	}

	for _, line := range strings.Split(string(out), "\n") {
		if !strings.Contains(line, "VGA") && !strings.Contains(line, "3D controller") {
			continue
		}
		info := GPUInfo{Model: extractGPUModel(line)}
		if strings.Contains(line, "AMD") || strings.Contains(line, "ATI") {
			info.Model = cleanAMDModel(line)
			info.Memory = amdVRAMMiB()
		}
		return info, nil
	}

	return GPUInfo{Model: "Unknown"}, nil
}

func nvidiaGPUInfo() (GPUInfo, bool) {
	out, err := exec.Command(
		"nvidia-smi",
		"--query-gpu=name,memory.total",
		"--format=csv,noheader",
	).Output()
	if err != nil || len(out) == 0 {
		return GPUInfo{}, false
	}
	parts := strings.SplitN(strings.TrimSpace(string(out)), ", ", 2)
	if len(parts) < 2 {
		return GPUInfo{}, false
	}
	memStr := strings.TrimSuffix(strings.TrimSpace(parts[1]), " MiB")
	mem, _ := strconv.Atoi(memStr)
	return GPUInfo{Model: strings.TrimSpace(parts[0]), Memory: mem}, true
}

func amdVRAMMiB() int {
	data, err := os.ReadFile("/sys/class/drm/card0/device/mem_info_vram_total")
	if err != nil {
		return 0
	}
	bytes, _ := strconv.ParseInt(strings.TrimSpace(string(data)), 10, 64)
	return int(bytes / (1024 * 1024))
}

func cleanAMDModel(line string) string {
	parts := strings.SplitN(line, ": ", 2)
	if len(parts) < 2 {
		return "Unknown AMD GPU"
	}
	m := parts[1]
	m = strings.TrimPrefix(m, "Advanced Micro Devices, Inc. [AMD/ATI] ")
	m = strings.TrimPrefix(m, "Advanced Micro Devices [AMD/ATI] ")
	m = strings.TrimPrefix(m, "AMD ")

	// Prefer glxinfo device name when available.
	if out, err := exec.Command("glxinfo", "-B").Output(); err == nil {
		for _, l := range strings.Split(string(out), "\n") {
			if strings.HasPrefix(l, "Device: ") {
				if name := strings.TrimPrefix(l, "Device: "); name != "" {
					return strings.SplitN(name, " (", 2)[0]
				}
			}
		}
	}
	return m
}

// ── Windows ──────────────────────────────────────────────────────────────────

func getWindowsGPUInfo() (GPUInfo, error) {
	out, err := exec.Command(
		"powershell", "-NoProfile", "-Command",
		"Get-WmiObject Win32_VideoController | Select-Object Name, AdapterRAM | Format-List",
	).Output()
	if err != nil {
		return GPUInfo{Model: "Unknown"}, nil
	}

	info := GPUInfo{Model: "Unknown"}
	s := string(out)

	if parts := strings.SplitN(s, "Name : ", 2); len(parts) == 2 {
		info.Model = strings.TrimSpace(strings.SplitN(parts[1], "\n", 2)[0])
	}
	if parts := strings.SplitN(s, "AdapterRAM : ", 2); len(parts) == 2 {
		memStr := strings.TrimSpace(strings.SplitN(parts[1], "\n", 2)[0])
		if v, err := strconv.ParseInt(memStr, 10, 64); err == nil {
			info.Memory = int(v / (1024 * 1024))
		}
	}
	return info, nil
}

// ── macOS ────────────────────────────────────────────────────────────────────

func getMacOSGPUInfo() (GPUInfo, error) {
	out, err := exec.Command(
		"system_profiler", "SPDisplaysDataType", "-detailLevel", "mini",
	).Output()
	if err != nil {
		return GPUInfo{Model: "Unknown"}, nil
	}

	info := GPUInfo{Model: "Unknown"}
	for _, line := range strings.Split(string(out), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "Chipset Model: ") {
			info.Model = strings.TrimPrefix(line, "Chipset Model: ")
		}
		if strings.HasPrefix(line, "VRAM (Total): ") {
			v := strings.TrimPrefix(line, "VRAM (Total): ")
			v = strings.TrimSuffix(v, " MB")
			v = strings.TrimSuffix(v, " GB")
			if strings.HasSuffix(line, " GB") {
				if gb, err := strconv.Atoi(strings.TrimSpace(v)); err == nil {
					info.Memory = gb * 1024
				}
			} else {
				info.Memory, _ = strconv.Atoi(strings.TrimSpace(v))
			}
		}
	}
	return info, nil
}

// ── helpers ──────────────────────────────────────────────────────────────────

func extractGPUModel(line string) string {
	parts := strings.SplitN(line, ": ", 2)
	if len(parts) < 2 {
		return "Unknown"
	}
	return strings.TrimSpace(parts[1])
}
