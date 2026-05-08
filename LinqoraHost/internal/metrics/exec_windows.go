//go:build windows

package metrics

import (
	"context"
	"os/exec"
	"syscall"
)

// hiddenCmd runs a command without spawning a visible console window on Windows.
func hiddenCmd(name string, args ...string) *exec.Cmd {
	c := exec.Command(name, args...)
	c.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	return c
}

// hiddenCmdCtx is the context-aware variant of hiddenCmd.
func hiddenCmdCtx(ctx context.Context, name string, args ...string) *exec.Cmd {
	c := exec.CommandContext(ctx, name, args...)
	c.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	return c
}
