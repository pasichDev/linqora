package metrics

import (
	"fmt"
	"math"
	"strings"
	"time"

	"github.com/shirou/gopsutil/cpu"
	"github.com/shirou/gopsutil/process"
	"github.com/shirou/gopsutil/v4/sensors"
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
	info := CPUInfo{
		Model:         "Unknown",
		LogicalCores:  0,
		PhysicalCores: 0,
		Frequency:     0.0,
	}

	logicalCores, logErr := cpu.Counts(true)
	physicalCores, psyhErr := cpu.Counts(false)

	if logErr == nil && psyhErr == nil {
		info.LogicalCores = logicalCores
		info.PhysicalCores = physicalCores
	}

	cpuArray, cpuError := cpu.Info()
	if cpuError == nil {
		if len(cpuArray) > 0 {
			c := cpuArray[0]
			info.Model = c.ModelName
			info.Frequency = math.Round(c.Mhz*100) / 100
		}
	}

	return info, nil
}

func GetCPUMetrics() (CPUMetrics, error) {
	cpu := CPUMetrics{}

	load, loadErr := GetCPULoad()
	temp, tempErr := GetCPUTemperature()
	proc, thrd, prcThErr := GetProcessesAndThreads()

	if loadErr == nil {
		cpu.LoadPercent = load
	}
	if tempErr == nil {
		cpu.Temperature = temp
	}
	if prcThErr == nil {
		cpu.Processes = float64(proc)
		cpu.Threads = float64(thrd)
	}

	return cpu, nil
}

// InitCPUBaseline seeds the gopsutil CPU counter so that the first call to
// GetCPULoad() returns a meaningful value instead of 0.
// Call once when the metrics collector starts.
func InitCPUBaseline() {
	cpu.Percent(0, false) //nolint:errcheck — baseline seed, result discarded
	// Small sleep so the OS has time to record a non-zero interval
	time.Sleep(200 * time.Millisecond)
	cpu.Percent(0, false) //nolint:errcheck
}

// GetCPULoad returns overall CPU usage percent.
// Uses interval=0 which measures since the previous call — non-blocking.
// InitCPUBaseline must be called once before the first call to this function.
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

// GetCPUTemperature finds the most relevant CPU temperature sensor.
func GetCPUTemperature() (float64, error) {
	temps, err := sensors.SensorsTemperatures()
	if err != nil {
		return 0, err
	}

	var cpuTemp float64
	var found bool

	for _, t := range temps {
		key := strings.ToLower(t.SensorKey)

		if strings.Contains(key, "tctl") ||
			strings.Contains(key, "package") ||
			strings.Contains(key, "core") ||
			strings.Contains(key, "cpu") {

			if strings.Contains(key, "acpitz") {
				continue
			}

			cpuTemp = math.Round(t.Temperature)
			found = true
			break
		}
	}

	if !found {
		return 0, fmt.Errorf("CPU temperature not found")
	}

	return cpuTemp, nil
}

// GetProcessesAndThreads returns the total number of processes and threads.
// A process that exits between the snapshot and the NumThreads call is skipped
// rather than aborting the whole collection.
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
			// The process likely exited between Processes() and NumThreads().
			// Skip it instead of failing the entire collection.
			continue
		}
		totalThreads += int(threads)
	}

	return numProcesses, totalThreads, nil
}
