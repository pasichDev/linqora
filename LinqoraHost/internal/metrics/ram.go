package metrics

import (
	"math"

	"github.com/shirou/gopsutil/mem"
)

type RamMetrics struct {
	ID          int     `json:"id"`
	Timestamp   string  `json:"timestamp"`
	Usage       float64 `json:"usage"`
	LoadPercent float64 `json:"loadPercent"`
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

func GetRamTotal() (float64, error) {

	v, vMError := mem.VirtualMemory()
	if vMError == nil {
		return math.Round((float64(v.Total)/1_000_000_000)*100) / 100, nil
	}

	return 0, nil
}
