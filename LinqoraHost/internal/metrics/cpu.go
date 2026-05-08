package metrics

import (
	"math"
	"time"

	"github.com/shirou/gopsutil/cpu"
	"github.com/shirou/gopsutil/process"
)

type CPUMetrics struct {
	Temperature float64 `json:"temperature"`
	LoadPercent float64 `json:"loadPercent"`
	Processes   float64 `json:"processes"`
	Threads     float64 `json:"threads"`
}

type CPUInfo struct {
	Model         string
	LogicalCores  int
	PhysicalCores int
	Frequency     float64
}

func GetCPUInfo() (CPUInfo, error) {
	info := CPUInfo{Model: "Unknown"}

	logicalCores, logErr := cpu.Counts(true)
	physicalCores, psyhErr := cpu.Counts(false)
	if logErr == nil && psyhErr == nil {
		info.LogicalCores = logicalCores
		info.PhysicalCores = physicalCores
	}

	cpuArray, cpuError := cpu.Info()
	if cpuError == nil && len(cpuArray) > 0 {
		c := cpuArray[0]
		info.Model = c.ModelName
		info.Frequency = math.Round(c.Mhz*100) / 100
	}

	return info, nil
}

func GetCPUMetrics() (CPUMetrics, error) {
	m := CPUMetrics{}

	load, loadErr := GetCPULoad()
	temp, tempErr := GetCPUTemperature() // cpu_temp_windows.go / cpu_temp_others.go
	proc, thrd, prcThErr := GetProcessesAndThreads()

	if loadErr == nil {
		m.LoadPercent = load
	}
	if tempErr == nil {
		m.Temperature = temp
	}
	if prcThErr == nil {
		m.Processes = float64(proc)
		m.Threads = float64(thrd)
	}

	return m, nil
}

// InitCPUBaseline seeds the gopsutil CPU counter so the first call to
// GetCPULoad() returns a meaningful value instead of 0.
func InitCPUBaseline() {
	cpu.Percent(0, false) //nolint:errcheck
	time.Sleep(200 * time.Millisecond)
	cpu.Percent(0, false) //nolint:errcheck
}

func GetCPULoad() (float64, error) {
	percentages, err := cpu.Percent(0, false)
	if err != nil {
		return 0, err
	}
	if len(percentages) > 0 {
		return math.Round(percentages[0]), nil
	}
	return 0, nil
}

func GetProcessesAndThreads() (int, int, error) {
	procs, err := process.Processes()
	if err != nil {
		return 0, 0, err
	}
	numProcesses := len(procs)
	totalThreads := 0
	for _, p := range procs {
		threads, err := p.NumThreads()
		if err != nil {
			continue
		}
		totalThreads += int(threads)
	}
	return numProcesses, totalThreads, nil
}
