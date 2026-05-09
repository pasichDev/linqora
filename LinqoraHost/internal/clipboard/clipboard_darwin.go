//go:build darwin

package clipboard

import (
	"bytes"
	"fmt"
	"os/exec"
	"strings"
)

func platformGet() (string, error) {
	out, err := exec.Command("pbpaste").Output()
	if err != nil {
		return "", fmt.Errorf("clipboard: pbpaste: %w", err)
	}
	return strings.TrimRight(string(out), "\n"), nil
}

func platformSet(text string) error {
	cmd := exec.Command("pbcopy")
	cmd.Stdin = bytes.NewBufferString(text)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("clipboard: pbcopy: %w", err)
	}
	return nil
}
