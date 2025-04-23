package ram

import (
	"math"

	"github.com/shirou/gopsutil/mem"
)

type RAMMetrics struct {
	ID          int     `json:"id"`
	Timestamp   string  `json:"timestamp"`
	Usage       float64 `json:"usage"`
	LoadPercent float64 `json:"loadPercent"`
}

func GetRAMMetricsRealTime() (RAMMetrics, error) {

	v, _ramErr := mem.VirtualMemory()

	if _ramErr != nil {
		return RAMMetrics{}, _ramErr
	}

	ram := RAMMetrics{
		LoadPercent: v.UsedPercent,
		Usage:       math.Round((float64(v.Used)/1_000_000_000)*100) / 100,
	}
	return ram, nil
}
