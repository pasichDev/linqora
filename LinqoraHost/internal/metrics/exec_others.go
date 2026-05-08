//go:build !windows

package metrics

import (
	"context"
	"os/exec"
)

func hiddenCmd(name string, args ...string) *exec.Cmd {
	return exec.Command(name, args...)
}

func hiddenCmdCtx(ctx context.Context, name string, args ...string) *exec.Cmd {
	return exec.CommandContext(ctx, name, args...)
}
