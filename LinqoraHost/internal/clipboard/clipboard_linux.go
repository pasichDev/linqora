//go:build linux

package clipboard

import (
	"bytes"
	"fmt"
	"os/exec"
	"strings"
)

func platformGet() (string, error) {
	out, err := exec.Command("xclip", "-selection", "clipboard", "-o").Output()
	if err != nil {
		return "", fmt.Errorf("clipboard: xclip read: %w", err)
	}
	return strings.TrimRight(string(out), "\n"), nil
}

func platformSet(text string) error {
	cmd := exec.Command("xclip", "-selection", "clipboard")
	cmd.Stdin = bytes.NewBufferString(text)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("clipboard: xclip write: %w", err)
	}
	return nil
}
