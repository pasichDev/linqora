package monitors

import (
	"fmt"
	"syscall"
	"unsafe"
)

var (
	user32                      = syscall.NewLazyDLL("user32.dll")
	procEnumDisplayMonitors     = user32.NewProc("EnumDisplayMonitors")
	procGetMonitorInfo          = user32.NewProc("GetMonitorInfoW")
	procEnumDisplaySettings     = user32.NewProc("EnumDisplaySettingsW")
	procChangeDisplaySettingsEx = user32.NewProc("ChangeDisplaySettingsExW")
)

type rect struct {
	Left, Top, Right, Bottom int32
}

type monitorInfoExW struct {
	Size    uint32
	Monitor rect
	Work    rect
	Flags   uint32
	Device  [32]uint16
}

type devModeW struct {
	DeviceName       [32]uint16
	SpecVersion      uint16
	DriverVersion    uint16
	Size             uint16
	DriverExtra      uint16
	Fields           uint32
	Orientation      int16
	PaperSize        int16
	PaperLength      int16
	PaperWidth       int16
	Scale            int16
	Copies           int16
	DefaultSource    int16
	PrintQuality     int16
	Color            int16
	Duplex           int16
	YResolution      int16
	TTOption         int16
	Collate          int16
	FormName         [32]uint16
	LogPixels        uint16
	BitsPerPel       uint32
	PelsWidth        uint32
	PelsHeight       uint32
	DisplayFlags     uint32
	DisplayFrequency uint32
	// ... more fields omitted for brevity
}

func platformGetMonitors() ([]MonitorInfo, error) {
	var monitors []MonitorInfo

	callback := syscall.NewCallback(func(hMonitor uintptr, hdcMonitor uintptr, lprcMonitor *rect, dwData uintptr) uintptr {
		var info monitorInfoExW
		info.Size = uint32(unsafe.Sizeof(info))

		ret, _, _ := procGetMonitorInfo.Call(hMonitor, uintptr(unsafe.Pointer(&info)))
		if ret == 0 {
			return 1
		}

		deviceName := syscall.UTF16ToString(info.Device[:])

		var dm devModeW
		dm.Size = uint16(unsafe.Sizeof(dm))
		ret, _, _ = procEnumDisplaySettings.Call(uintptr(unsafe.Pointer(&info.Device[0])), 0xFFFFFFFF, uintptr(unsafe.Pointer(&dm)))

		isPrimary := (info.Flags & 1) != 0

		monitors = append(monitors, MonitorInfo{
			ID:          deviceName,
			Name:        deviceName,
			IsPrimary:   isPrimary,
			Width:       int(dm.PelsWidth),
			Height:      int(dm.PelsHeight),
			RefreshRate: int(dm.DisplayFrequency),
			X:           int(info.Monitor.Left),
			Y:           int(info.Monitor.Top),
		})

		return 1
	})

	procEnumDisplayMonitors.Call(0, 0, callback, 0)

	return monitors, nil
}

func platformSetResolution(monitorID string, width, height, refreshRate int) error {
	// Implementation requires more complex devModeW filling and ChangeDisplaySettingsEx calls
	// For now, return not implemented error or a simplified version
	return fmt.Errorf("setting resolution is not yet implemented for Windows in this version")
}

func platformSetPrimary(monitorID string) error {
	return fmt.Errorf("setting primary monitor is not yet implemented for Windows")
}
