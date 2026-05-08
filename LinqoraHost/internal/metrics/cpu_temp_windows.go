//go:build windows

package metrics

import (
	"fmt"
	"math"

	"github.com/yusufpapurcu/wmi"
)

// wmiThermalZone maps MSAcpi_ThermalZoneTemperature in root\wmi.
// CurrentTemperature is in tenths of Kelvin (e.g. 3231 = 50.0 °C).
type wmiThermalZone struct {
	CurrentTemperature uint32
}

// GetCPUTemperature reads CPU temperature via the WMI Go package.
// No PowerShell process is spawned — no console window flashing.
func GetCPUTemperature() (float64, error) {
	var zones []wmiThermalZone
	if err := wmi.QueryNamespace(
		"SELECT CurrentTemperature FROM MSAcpi_ThermalZoneTemperature",
		&zones,
		`root\wmi`,
	); err != nil || len(zones) == 0 {
		return 0, fmt.Errorf("WMI thermal zone unavailable: %v", err)
	}

	celsius := float64(zones[0].CurrentTemperature)/10.0 - 273.15
	if celsius < -20 || celsius > 150 {
		return 0, fmt.Errorf("temperature %.1f°C outside plausible range", celsius)
	}
	return math.Round(celsius), nil
}
