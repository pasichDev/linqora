//go:build !windows

package metrics

import (
	"fmt"
	"math"
	"strings"

	"github.com/shirou/gopsutil/v4/sensors"
)

// GetCPUTemperature finds the most relevant CPU temperature sensor via gopsutil.
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
		return 0, fmt.Errorf("CPU temperature sensor not found")
	}
	return cpuTemp, nil
}
