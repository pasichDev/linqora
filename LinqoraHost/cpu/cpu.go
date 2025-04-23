package cpu

import (
	"time"

	"github.com/shirou/gopsutil/cpu"
	"github.com/shirou/gopsutil/host"
	"github.com/shirou/gopsutil/process"
)

type CPUMetrics struct {
	ID          int     `json:"id"`
	Timestamp   string  `json:"timestamp"`
	Temperature float64 `json:"temperature"`
	LoadPercent float64 `json:"loadPercent"`
	Processes   float64 `json:"processes"`
	Threads     float64 `json:"threads"`
	Frequencies float64 `json:"freq"`
}

func GetCPUMetricsRealTime() (CPUMetrics, error) {
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
	// отримуємо навантаження за 1 секунду
	percentages, err := cpu.Percent(1*time.Second, false)
	if err != nil {
		return 0, err
	}
	if len(percentages) > 0 {
		return percentages[0], nil
	}
	return 0, nil
}

// GetCPUTemperature повертає температуру CPU, якщо можливо
func GetCPUTemperature() (float64, error) {
	sensors, err := host.SensorsTemperatures()
	if err != nil {
		return 0, err
	}
	for _, sensor := range sensors {
		// Спробуємо знайти щось, що схоже на температуру CPU
		if sensor.SensorKey == "Package id 0" || sensor.SensorKey == "Tdie" || sensor.SensorKey == "Core 0" {
			return sensor.Temperature, nil
		}
	}
	// Якщо не знайшли нічого специфічного — повернемо перший
	if len(sensors) > 0 {
		return sensors[0].Temperature, nil
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
			return 0, 0, err
		}
		totalThreads += int(threads)
	}

	return numProcesses, totalThreads, nil
}
