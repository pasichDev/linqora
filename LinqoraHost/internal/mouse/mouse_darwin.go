//go:build darwin

package mouse

import (
	"fmt"
	"os/exec"
)

// jxa runs a JXA (JavaScript for Automation) snippet via osascript.
// We use CoreGraphics ObjC bridging to control the mouse without extra tools.
func jxa(script string) error {
	return exec.Command("osascript", "-l", "JavaScript", "-e", script).Run()
}

const (
	kCGEventMouseMoved     = 5
	kCGEventLeftMouseDown  = 1
	kCGEventLeftMouseUp    = 2
	kCGEventRightMouseDown = 3
	kCGEventRightMouseUp   = 4
	kCGEventOtherMouseDown = 25
	kCGEventOtherMouseUp   = 26
	kCGEventScrollWheel    = 22
	kCGMouseButtonLeft     = 0
	kCGMouseButtonRight    = 1
	kCGMouseButtonCenter   = 2
	kCGHIDEventTap         = 0
)

func currentPosScript() string {
	return `ObjC.import('CoreGraphics');
var _e = $.CGEventCreate(null);
var _p = $.CGEventGetLocation(_e);
$.CFRelease(_e);`
}

func postMouseMoveScript(dx, dy int) string {
	return fmt.Sprintf(`%s
var _mv = $.CGEventCreateMouseEvent(null, %d, {x: _p.x + %d, y: _p.y + %d}, %d);
$.CGEventPost(%d, _mv);
$.CFRelease(_mv);`,
		currentPosScript(), kCGEventMouseMoved, dx, dy, kCGMouseButtonLeft, kCGHIDEventTap)
}

func postClickScript(downType, upType, button int) string {
	return fmt.Sprintf(`%s
var _d = $.CGEventCreateMouseEvent(null, %d, _p, %d);
$.CGEventPost(%d, _d);
$.CFRelease(_d);
var _u = $.CGEventCreateMouseEvent(null, %d, _p, %d);
$.CGEventPost(%d, _u);
$.CFRelease(_u);`,
		currentPosScript(), downType, button, kCGHIDEventTap,
		upType, button, kCGHIDEventTap)
}

func platformHandleMouse(cmd MouseCommand) error {
	switch cmd.Action {
	case ActionMove:
		return jxa(postMouseMoveScript(cmd.DX, cmd.DY))
	case ActionLeftClick:
		return jxa(postClickScript(kCGEventLeftMouseDown, kCGEventLeftMouseUp, kCGMouseButtonLeft))
	case ActionRightClick:
		return jxa(postClickScript(kCGEventRightMouseDown, kCGEventRightMouseUp, kCGMouseButtonRight))
	case ActionMiddleClick:
		return jxa(postClickScript(kCGEventOtherMouseDown, kCGEventOtherMouseUp, kCGMouseButtonCenter))
	case ActionScroll:
		return jxa(fmt.Sprintf(`ObjC.import('CoreGraphics');
var _s = $.CGEventCreateScrollWheelEvent(null, 0, 1, %d);
$.CGEventPost(%d, _s);
$.CFRelease(_s);`, cmd.Delta*3, kCGHIDEventTap))
	case ActionDoubleClick:
		script := fmt.Sprintf(`%s
var _d1 = $.CGEventCreateMouseEvent(null, %d, _p, %d);
$.CGEventSetIntegerValueField(_d1, 1, 2);
$.CGEventPost(%d, _d1);
$.CFRelease(_d1);
var _u1 = $.CGEventCreateMouseEvent(null, %d, _p, %d);
$.CGEventSetIntegerValueField(_u1, 1, 2);
$.CGEventPost(%d, _u1);
$.CFRelease(_u1);`,
			currentPosScript(),
			kCGEventLeftMouseDown, kCGMouseButtonLeft, kCGHIDEventTap,
			kCGEventLeftMouseUp, kCGMouseButtonLeft, kCGHIDEventTap)
		return jxa(script)
	case ActionPinchZoom:
		// Ctrl+scroll simulates pinch zoom universally (browser zoom, map zoom, etc.)
		return jxa(fmt.Sprintf(`ObjC.import('CoreGraphics');
var _s = $.CGEventCreateScrollWheelEvent(null, 0, 1, %d);
$.CGEventSetFlags(_s, 0x40000); // kCGEventFlagMaskControl
$.CGEventPost(%d, _s);
$.CFRelease(_s);`, cmd.Delta*3, kCGHIDEventTap))
	default:
		return fmt.Errorf("mouse: unknown action %d", cmd.Action)
	}
}
