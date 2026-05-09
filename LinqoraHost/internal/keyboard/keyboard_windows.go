//go:build windows

package keyboard

import (
	"fmt"
	"unsafe"

	"golang.org/x/sys/windows"
)

var (
	modUser32  = windows.NewLazySystemDLL("user32.dll")
	sendInputP = modUser32.NewProc("SendInput")
)

const inputKeyboard = uint32(1)
const (
	keyeventfKeyup   = uint32(0x0002)
	keyeventfUnicode = uint32(0x0004)
)

type keybdInput struct {
	Vk        uint16
	Scan      uint16
	Flags     uint32
	Time      uint32
	_         uint32
	ExtraInfo uintptr
}

type winInput struct {
	Type uint32
	_    uint32
	Ki   keybdInput
	_    [8]byte
}

func sendInputBatch(inputs []winInput) error {
	if len(inputs) == 0 {
		return nil
	}
	n, _, err := sendInputP.Call(
		uintptr(len(inputs)),
		uintptr(unsafe.Pointer(&inputs[0])),
		unsafe.Sizeof(inputs[0]),
	)
	if n != uintptr(len(inputs)) {
		return fmt.Errorf("SendInput: sent %d/%d: %w", n, len(inputs), err)
	}
	return nil
}

var vkMap = map[string]uint16{
	"ctrl": 0x11, "alt": 0x12, "shift": 0x10, "win": 0x5B,
	"tab": 0x09, "esc": 0x1B, "enter": 0x0D, "backspace": 0x08,
	"delete": 0x2E, "space": 0x20, "home": 0x24, "end": 0x23,
	"pageup": 0x21, "pagedown": 0x22,
	"up": 0x26, "down": 0x28, "left": 0x25, "right": 0x27,
	"f1": 0x70, "f2": 0x71, "f3": 0x72, "f4": 0x73,
	"f5": 0x74, "f6": 0x75, "f7": 0x76, "f8": 0x77,
	"f9": 0x78, "f10": 0x79, "f11": 0x7A, "f12": 0x7B,
	"insert": 0x2D, "printscreen": 0x2C,
}

func vkDown(vk uint16) winInput {
	return winInput{Type: inputKeyboard, Ki: keybdInput{Vk: vk}}
}
func vkUp(vk uint16) winInput {
	return winInput{Type: inputKeyboard, Ki: keybdInput{Vk: vk, Flags: keyeventfKeyup}}
}

func platformHandleKey(cmd KeyCommand) error {
	mainVK, ok := vkMap[cmd.Key]
	if !ok {
		return fmt.Errorf("keyboard: unknown key %q", cmd.Key)
	}
	inputs := make([]winInput, 0, (len(cmd.Modifiers)+1)*2)
	for _, mod := range cmd.Modifiers {
		vk, ok := vkMap[mod]
		if !ok {
			return fmt.Errorf("keyboard: unknown modifier %q", mod)
		}
		inputs = append(inputs, vkDown(vk))
	}
	inputs = append(inputs, vkDown(mainVK), vkUp(mainVK))
	for i := len(cmd.Modifiers) - 1; i >= 0; i-- {
		inputs = append(inputs, vkUp(vkMap[cmd.Modifiers[i]]))
	}
	return sendInputBatch(inputs)
}

func platformTypeText(text string) error {
	inputs := make([]winInput, 0, len([]rune(text))*2)
	for _, r := range text {
		if r > 0xFFFF {
			continue
		}
		scan := uint16(r)
		inputs = append(inputs,
			winInput{Type: inputKeyboard, Ki: keybdInput{Scan: scan, Flags: keyeventfUnicode}},
			winInput{Type: inputKeyboard, Ki: keybdInput{Scan: scan, Flags: keyeventfUnicode | keyeventfKeyup}},
		)
	}
	return sendInputBatch(inputs)
}
