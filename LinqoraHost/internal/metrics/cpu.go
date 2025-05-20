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

	// Отримуємо кількість логічних ядер (потоків)
	logicalCores, logErr := cpu.Counts(true)

	// Отримуємо кількість фізичних ядер
	physicalCores, psyhErr := cpu.Counts(false)

	if logErr == nil && psyhErr == nil {
		info.LogicalCores = logicalCores
		info.PhysicalCores = physicalCores
	}

	// Отримуємо інформацію про процесор
	cpuArray, cpuError := cpu.Info()
	if cpuError == nil {
		// Якщо є хоча б один процесор, заповнюємо модель, кількість ядер і потоків
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

// GetCPULoad повертає відсоток завантаження CPU
func GetCPULoad() (float64, error) {
	percentages, err := cpu.Percent(1*time.Second, false)
	if err != nil {
		return 0, err
	}
	if len(percentages) > 0 {
		// Округляем до 2 знаков после запятой
		return math.Round(percentages[0]), nil
	}
	return 0, nil
}

// GetCPUTemperature знаходить найрелевантнішу температуру CPU
func GetCPUTemperature() (float64, error) {
	temps, err := sensors.SensorsTemperatures()
	if err != nil {
		return 0, err
	}

	var cpuTemp float64
	var found bool

	// Пріоритетність за сенсорами
	for _, t := range temps {
		key := strings.ToLower(t.SensorKey)

		if strings.Contains(key, "tctl") || // AMD Tctl
			strings.Contains(key, "package") || // Intel Package
			strings.Contains(key, "core") || // Intel Core
			strings.Contains(key, "cpu") { // універсально

			// Винятки — ігноруємо "acpitz" як менш точне джерело
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
			return 0, 0, err
		}
		totalThreads += int(threads)
	}

	return numProcesses, totalThreads, nil
}
