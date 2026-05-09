//go:build windows

package clipboard

import (
	"fmt"
	"syscall"
	"unsafe"

	"golang.org/x/sys/windows"
)

var (
	modUser32Clip      = windows.NewLazySystemDLL("user32.dll")
	modKernel32Clip    = windows.NewLazySystemDLL("kernel32.dll")
	procOpenClipboard  = modUser32Clip.NewProc("OpenClipboard")
	procCloseClipboard = modUser32Clip.NewProc("CloseClipboard")
	procEmptyClipboard = modUser32Clip.NewProc("EmptyClipboard")
	procGetClipData    = modUser32Clip.NewProc("GetClipboardData")
	procSetClipData    = modUser32Clip.NewProc("SetClipboardData")
	procGlobalAlloc    = modKernel32Clip.NewProc("GlobalAlloc")
	procGlobalLock     = modKernel32Clip.NewProc("GlobalLock")
	procGlobalUnlock   = modKernel32Clip.NewProc("GlobalUnlock")
	procLstrcpyW       = modKernel32Clip.NewProc("lstrcpyW")
)

const (
	cfUnicodeText = 13
	gmemMoveable  = 0x0002
)

func platformGet() (string, error) {
	r, _, err := procOpenClipboard.Call(0)
	if r == 0 {
		return "", fmt.Errorf("clipboard: OpenClipboard: %w", err)
	}
	defer procCloseClipboard.Call()

	h, _, _ := procGetClipData.Call(cfUnicodeText)
	if h == 0 {
		return "", nil
	}
	ptr, _, _ := procGlobalLock.Call(h)
	if ptr == 0 {
		return "", fmt.Errorf("clipboard: GlobalLock failed")
	}
	defer procGlobalUnlock.Call(h)

	text := syscall.UTF16ToString((*[1 << 20]uint16)(unsafe.Pointer(ptr))[:])
	return text, nil
}

func platformSet(text string) error {
	r, _, err := procOpenClipboard.Call(0)
	if r == 0 {
		return fmt.Errorf("clipboard: OpenClipboard: %w", err)
	}
	defer procCloseClipboard.Call()

	procEmptyClipboard.Call()

	utf16, _ := syscall.UTF16FromString(text)
	size := uintptr(len(utf16) * 2)
	h, _, _ := procGlobalAlloc.Call(gmemMoveable, size)
	if h == 0 {
		return fmt.Errorf("clipboard: GlobalAlloc failed")
	}
	ptr, _, _ := procGlobalLock.Call(h)
	if ptr == 0 {
		return fmt.Errorf("clipboard: GlobalLock failed")
	}
	procLstrcpyW.Call(ptr, uintptr(unsafe.Pointer(&utf16[0])))
	procGlobalUnlock.Call(h)

	r, _, err = procSetClipData.Call(cfUnicodeText, h)
	if r == 0 {
		return fmt.Errorf("clipboard: SetClipboardData: %w", err)
	}
	return nil
}
