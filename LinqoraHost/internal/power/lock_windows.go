package power

import (
	"strings"
	"unsafe"

	"golang.org/x/sys/windows"
)

// isPlatformSystemLocked checks whether the Windows workstation is locked by
// scanning the running process list for LogonUI.exe. This avoids a subprocess
// spawn and is faster than the previous PowerShell + Get-Process approach.
func isPlatformSystemLocked() (bool, error) {
	snapshot, err := windows.CreateToolhelp32Snapshot(windows.TH32CS_SNAPPROCESS, 0)
	if err != nil {
		return false, err
	}
	defer windows.CloseHandle(snapshot)

	var pe windows.ProcessEntry32
	pe.Size = uint32(unsafe.Sizeof(pe))

	if err := windows.Process32First(snapshot, &pe); err != nil {
		return false, err
	}

	for {
		name := windows.UTF16ToString(pe.ExeFile[:])
		if strings.EqualFold(name, "LogonUI.exe") {
			return true, nil
		}
		if err := windows.Process32Next(snapshot, &pe); err != nil {
			break
		}
	}

	return false, nil
}
