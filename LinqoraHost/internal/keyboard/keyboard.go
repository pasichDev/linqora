package keyboard

// KeyCommand is the WS payload for a keyboard event.
type KeyCommand struct {
	Key       string   `json:"key"`
	Modifiers []string `json:"modifiers"`
}

// HandleKeyCommand dispatches to the platform implementation.
func HandleKeyCommand(cmd KeyCommand) error {
	return platformHandleKey(cmd)
}

// TypeText sends each character in text as a keystroke sequence.
func TypeText(text string) error {
	if text == "" {
		return nil
	}
	return platformTypeText(text)
}

// ValidKey reports whether name is in the supported key set.
func ValidKey(name string) bool {
	_, ok := supportedKeys[name]
	return ok
}

// supportedKeys is the canonical set of allowed key names (shared across platforms).
var supportedKeys = map[string]struct{}{
	"ctrl": {}, "alt": {}, "shift": {}, "win": {},
	"tab": {}, "esc": {}, "enter": {}, "backspace": {},
	"delete": {}, "space": {}, "home": {}, "end": {},
	"pageup": {}, "pagedown": {},
	"up": {}, "down": {}, "left": {}, "right": {},
	"f1": {}, "f2": {}, "f3": {}, "f4": {}, "f5": {}, "f6": {},
	"f7": {}, "f8": {}, "f9": {}, "f10": {}, "f11": {}, "f12": {},
	"insert": {}, "printscreen": {},
}
