package scheduler

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

const maxRuntime = 30 * time.Second

// Script describes a server-registered runnable command.
// The command is always defined server-side; clients only supply the ID.
type Script struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Command     string `json:"command"`     // executable
	Args        []string `json:"args,omitempty"` // fixed arguments; not user-supplied
	WorkDir     string `json:"work_dir,omitempty"`
}

// RunResult contains the outcome of a script execution.
type RunResult struct {
	ID       string `json:"id"`
	ExitCode int    `json:"exit_code"`
	Stdout   string `json:"stdout"`
	Stderr   string `json:"stderr"`
	Duration int64  `json:"duration_ms"`
}

// Manager holds the list of server-registered scripts and executes them.
type Manager struct {
	scripts []Script
}

// NewManager loads scripts from [path].  If the file is absent or cannot be
// parsed a manager with an empty script list is returned.
func NewManager(path string) *Manager {
	m := &Manager{}

	data, err := os.ReadFile(path)
	if err != nil {
		return m
	}

	if err := json.Unmarshal(data, &m.scripts); err != nil {
		log.Printf("scheduler: failed to parse scripts file %s: %v", path, err)
	}

	return m
}

// NewManagerWithScripts creates a Manager from an explicit list (useful for
// tests and embedding scripts in ServerConfig).
func NewManagerWithScripts(scripts []Script) *Manager {
	return &Manager{scripts: scripts}
}

// List returns all registered scripts (without execution details).
func (m *Manager) List() []Script {
	out := make([]Script, len(m.scripts))
	copy(out, m.scripts)
	return out
}

// Execute runs the script identified by [id].
// Returns an error if the id is unknown or the process fails to start.
// Execution is capped at [maxRuntime].
func (m *Manager) Execute(id string) (RunResult, error) {
	var script *Script
	for i := range m.scripts {
		if m.scripts[i].ID == id {
			script = &m.scripts[i]
			break
		}
	}
	if script == nil {
		return RunResult{}, fmt.Errorf("script %q not found", id)
	}

	ctx, cancel := context.WithTimeout(context.Background(), maxRuntime)
	defer cancel()

	// #nosec G204 — command and args are server-registered constants, never
	// user-supplied input.
	cmd := exec.CommandContext(ctx, script.Command, script.Args...)
	if script.WorkDir != "" {
		cmd.Dir = script.WorkDir
	}

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	start := time.Now()
	err := cmd.Run()
	dur := time.Since(start).Milliseconds()

	exitCode := 0
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
		} else {
			return RunResult{}, fmt.Errorf("failed to run script %q: %w", id, err)
		}
	}

	return RunResult{
		ID:       id,
		ExitCode: exitCode,
		Stdout:   stdout.String(),
		Stderr:   stderr.String(),
		Duration: dur,
	}, nil
}

// DefaultScriptsPath returns the conventional location for the scripts JSON
// file alongside the server config.
func DefaultScriptsPath() string {
	configDir, err := os.UserConfigDir()
	if err != nil {
		configDir = "."
	}
	return filepath.Join(configDir, "linqora", "scripts.json")
}
