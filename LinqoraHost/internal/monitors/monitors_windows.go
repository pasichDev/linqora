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
	// Convert monitorID to UTF-16 pointer
	devicePtr, err := syscall.UTF16PtrFromString(monitorID)
	if err != nil {
		return fmt.Errorf("invalid monitor ID: %w", err)
	}

	var dm devModeW
	dm.Size = uint16(unsafe.Sizeof(dm))

	// Query current settings first
	ret, _, _ := procEnumDisplaySettings.Call(
		uintptr(unsafe.Pointer(devicePtr)), 0xFFFFFFFF,
		uintptr(unsafe.Pointer(&dm)),
	)
	if ret == 0 {
		return fmt.Errorf("failed to query display settings for %s", monitorID)
	}

	// DEVMODE field flags for resolution + refresh rate
	const (
		DM_PELSWIDTH           = 0x00080000
		DM_PELSHEIGHT          = 0x00100000
		DM_DISPLAYFREQUENCY    = 0x00400000
		CDS_UPDATEREGISTRY     = 0x00000001
		DISP_CHANGE_SUCCESSFUL = 0
	)

	dm.PelsWidth = uint32(width)
	dm.PelsHeight = uint32(height)
	if refreshRate > 0 {
		dm.DisplayFrequency = uint32(refreshRate)
		dm.Fields = DM_PELSWIDTH | DM_PELSHEIGHT | DM_DISPLAYFREQUENCY
	} else {
		dm.Fields = DM_PELSWIDTH | DM_PELSHEIGHT
	}

	ret, _, _ = procChangeDisplaySettingsEx.Call(
		uintptr(unsafe.Pointer(devicePtr)),
		uintptr(unsafe.Pointer(&dm)),
		0,
		CDS_UPDATEREGISTRY,
		0,
	)
	if int32(ret) != DISP_CHANGE_SUCCESSFUL {
		return fmt.Errorf("ChangeDisplaySettingsExW failed with code %d", int32(ret))
	}
	return nil
}

func platformSetPrimary(monitorID string) error {
	monitors, err := platformGetMonitors()
	if err != nil {
		return fmt.Errorf("failed to enumerate monitors: %w", err)
	}

	// Find the target monitor's position
	var targetX, targetY int
	found := false
	for _, m := range monitors {
		if m.ID == monitorID {
			targetX, targetY = m.X, m.Y
			found = true
			break
		}
	}
	if !found {
		return fmt.Errorf("monitor %s not found", monitorID)
	}

	const (
		DM_POSITION            = 0x00000020
		CDS_SET_PRIMARY        = 0x00000010
		CDS_UPDATEREGISTRY     = 0x00000001
		CDS_NORESET            = 0x10000000
		DISP_CHANGE_SUCCESSFUL = 0
	)

	// Shift all monitors so the target becomes (0,0)
	for _, m := range monitors {
		devicePtr, err := syscall.UTF16PtrFromString(m.ID)
		if err != nil {
			continue
		}

		var dm devModeW
		dm.Size = uint16(unsafe.Sizeof(dm))
		procEnumDisplaySettings.Call(
			uintptr(unsafe.Pointer(devicePtr)), 0xFFFFFFFF,
			uintptr(unsafe.Pointer(&dm)),
		)

		// Reposition relative to new primary
		// Position union starts at byte 28 in DEVMODEW (dmPosition)
		// We encode X,Y into the struct via the union offset manually
		newX := int32(m.X - targetX)
		newY := int32(m.Y - targetY)
		// Write position via unsafe pointer arithmetic into devModeW union
		// The union for display settings starts at offset of Orientation field
		// DEVMODEW: dmPosition is at offset 28 bytes after dmDeviceName+dmSpecVersion+...
		// Simpler: re-query and set fields
		dm.Fields = DM_POSITION
		// Set position bits in the struct union (bytes 28-35 in the display-device union)
		*(*int32)(unsafe.Pointer(uintptr(unsafe.Pointer(&dm)) + 28)) = newX
		*(*int32)(unsafe.Pointer(uintptr(unsafe.Pointer(&dm)) + 32)) = newY

		flags := uint32(CDS_UPDATEREGISTRY | CDS_NORESET)
		if m.ID == monitorID {
			flags |= CDS_SET_PRIMARY
		}

		procChangeDisplaySettingsEx.Call(
			uintptr(unsafe.Pointer(devicePtr)),
			uintptr(unsafe.Pointer(&dm)),
			0, uintptr(flags), 0,
		)
	}

	// Apply all changes
	procChangeDisplaySettingsEx.Call(0, 0, 0, 0, 0)
	return nil
}
