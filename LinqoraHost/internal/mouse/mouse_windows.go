//go:build windows

package mouse

import (
	"fmt"

	"golang.org/x/sys/windows"
)

var (
	modUser32Mouse   = windows.NewLazySystemDLL("user32.dll")
	procMouseEvent   = modUser32Mouse.NewProc("mouse_event")
	procKeybdEvtMse  = modUser32Mouse.NewProc("keybd_event")
)

const (
	vkControl         = byte(0x11)
	keyeventfKeyupMse = uint32(0x0002)
)

const (
	mouseeventfMove       = uint32(0x0001)
	mouseeventfLeftdown   = uint32(0x0002)
	mouseeventfLeftup     = uint32(0x0004)
	mouseeventfRightdown  = uint32(0x0008)
	mouseeventfRightup    = uint32(0x0010)
	mouseeventfMiddledown = uint32(0x0020)
	mouseeventfMiddleup   = uint32(0x0040)
	mouseeventfWheel      = uint32(0x0800)

	wheelDelta = int32(120)
)

func sendMouseEvent(flags, dx, dy uint32, data int32) {
	procMouseEvent.Call(
		uintptr(flags),
		uintptr(dx),
		uintptr(dy),
		// data is passed as its raw bits; Windows treats WHEEL data as signed DWORD
		uintptr(uint32(data)),
		0,
	)
}

func platformHandleMouse(cmd MouseCommand) error {
	switch cmd.Action {
	case ActionMove:
		sendMouseEvent(mouseeventfMove, uint32(cmd.DX), uint32(cmd.DY), 0)
	case ActionLeftClick:
		sendMouseEvent(mouseeventfLeftdown, 0, 0, 0)
		sendMouseEvent(mouseeventfLeftup, 0, 0, 0)
	case ActionRightClick:
		sendMouseEvent(mouseeventfRightdown, 0, 0, 0)
		sendMouseEvent(mouseeventfRightup, 0, 0, 0)
	case ActionMiddleClick:
		sendMouseEvent(mouseeventfMiddledown, 0, 0, 0)
		sendMouseEvent(mouseeventfMiddleup, 0, 0, 0)
	case ActionScroll:
		sendMouseEvent(mouseeventfWheel, 0, 0, int32(cmd.Delta)*wheelDelta)
	case ActionDoubleClick:
		sendMouseEvent(mouseeventfLeftdown, 0, 0, 0)
		sendMouseEvent(mouseeventfLeftup, 0, 0, 0)
		sendMouseEvent(mouseeventfLeftdown, 0, 0, 0)
		sendMouseEvent(mouseeventfLeftup, 0, 0, 0)
	case ActionPinchZoom:
		procKeybdEvtMse.Call(uintptr(vkControl), 0, 0, 0)
		sendMouseEvent(mouseeventfWheel, 0, 0, int32(cmd.Delta)*wheelDelta)
		procKeybdEvtMse.Call(uintptr(vkControl), 0, uintptr(keyeventfKeyupMse), 0)
	default:
		return fmt.Errorf("mouse: unknown action %d", cmd.Action)
	}
	return nil
}
