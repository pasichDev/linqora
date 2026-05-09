package keyboard

import (
	"strings"
	"testing"
)

func TestValidKey_known(t *testing.T) {
	keys := []string{"ctrl", "alt", "shift", "win", "tab", "esc", "enter",
		"backspace", "delete", "space", "home", "end", "pageup", "pagedown",
		"up", "down", "left", "right",
		"f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12",
		"insert", "printscreen",
	}
	for _, k := range keys {
		if !ValidKey(k) {
			t.Errorf("ValidKey(%q) = false, want true", k)
		}
	}
}

func TestValidKey_unknown(t *testing.T) {
	if ValidKey("unknown_key") {
		t.Error("ValidKey(\"unknown_key\") = true, want false")
	}
}

func TestHandleKeyCommand_unknownKey(t *testing.T) {
	err := HandleKeyCommand(KeyCommand{Key: "notakey", Modifiers: nil})
	if err == nil {
		t.Fatal("expected error for unknown key, got nil")
	}
	if !strings.Contains(err.Error(), "notakey") {
		t.Errorf("error %q should mention the unknown key", err.Error())
	}
}

func TestTypeText_empty(t *testing.T) {
	if err := TypeText(""); err != nil {
		t.Errorf("TypeText(\"\") returned unexpected error: %v", err)
	}
}
