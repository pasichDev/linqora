package scheduler

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"time"
)

const maxRuntime = 5 * time.Minute // Increased for more complex tasks

// Script describes a server-registered runnable command.
type Script struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Description string   `json:"description"`
	Command     string   `json:"command"`
	Args        []string `json:"args,omitempty"`
	WorkDir     string   `json:"work_dir,omitempty"`
}

// RunResult contains the final outcome of a script execution.
type RunResult struct {
	ID       string `json:"id"`
	ExitCode int    `json:"exit_code"`
	Stdout   string `json:"stdout"`
	Stderr   string `json:"stderr"`
	Duration int64  `json:"duration_ms"`
}

// OutputChunk represents a real-time output line.
type OutputChunk struct {
	ID     string `json:"id"`
	Stream string `json:"stream"` // "stdout" or "stderr"
	Text   string `json:"text"`
}

// Manager holds the list of server-registered scripts and manages their execution.
type Manager struct {
	path    string
	scripts []Script
	mu      sync.RWMutex
	running map[string]context.CancelFunc
}

// NewManager loads scripts from [path].
func NewManager(path string) *Manager {
	m := &Manager{
		path:    path,
		running: make(map[string]context.CancelFunc),
	}
	m.load()
	return m
}

func (m *Manager) load() {
	if m.path == "" {
		return
	}
	data, err := os.ReadFile(m.path)
	if err != nil {
		return
	}

	m.mu.Lock()
	defer m.mu.Unlock()
	if err := json.Unmarshal(data, &m.scripts); err != nil {
		slog.Error("Failed to parse scripts file", "path", m.path, "err", err)
	}
}

// NewManagerWithScripts creates a Manager from an explicit list (useful for tests).
func NewManagerWithScripts(scripts []Script) *Manager {
	return &Manager{
		scripts: scripts,
		running: make(map[string]context.CancelFunc),
	}
}

func (m *Manager) save() error {
	m.mu.RLock()
	data, err := json.MarshalIndent(m.scripts, "", "  ")
	m.mu.RUnlock()
	if err != nil {
		return err
	}

	if err := os.MkdirAll(filepath.Dir(m.path), 0755); err != nil {
		return err
	}

	return os.WriteFile(m.path, data, 0644)
}

// CRUD Operations

func (m *Manager) List() []Script {
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := make([]Script, len(m.scripts))
	copy(out, m.scripts)
	return out
}

func (m *Manager) Add(s Script) error {
	m.mu.Lock()
	for _, existing := range m.scripts {
		if existing.ID == s.ID {
			m.mu.Unlock()
			return fmt.Errorf("script with ID %s already exists", s.ID)
		}
	}
	m.scripts = append(m.scripts, s)
	m.mu.Unlock()
	return m.save()
}

func (m *Manager) Update(s Script) error {
	m.mu.Lock()
	found := false
	for i, existing := range m.scripts {
		if existing.ID == s.ID {
			m.scripts[i] = s
			found = true
			break
		}
	}
	m.mu.Unlock()
	if !found {
		return fmt.Errorf("script with ID %s not found", s.ID)
	}
	return m.save()
}

func (m *Manager) Delete(id string) error {
	m.mu.Lock()
	found := false
	for i, existing := range m.scripts {
		if existing.ID == id {
			m.scripts = append(m.scripts[:i], m.scripts[i+1:]...)
			found = true
			break
		}
	}
	m.mu.Unlock()
	if !found {
		return fmt.Errorf("script with ID %s not found", id)
	}
	return m.save()
}

// Execution

func (m *Manager) Stop(id string) {
	m.mu.Lock()
	if cancel, ok := m.running[id]; ok {
		cancel()
		delete(m.running, id)
	}
	m.mu.Unlock()
}

// Execute runs the script and streams output via the onOutput callback.
func (m *Manager) Execute(id string, onOutput func(OutputChunk)) (RunResult, error) {
	m.mu.RLock()
	var script *Script
	for i := range m.scripts {
		if m.scripts[i].ID == id {
			script = &m.scripts[i]
			break
		}
	}
	m.mu.RUnlock()

	if script == nil {
		return RunResult{}, fmt.Errorf("script %q not found", id)
	}

	ctx, cancel := context.WithTimeout(context.Background(), maxRuntime)
	defer cancel()

	m.mu.Lock()
	if _, busy := m.running[id]; busy {
		m.mu.Unlock()
		cancel()
		return RunResult{}, fmt.Errorf("script %q is already running", id)
	}
	m.running[id] = cancel
	m.mu.Unlock()

	defer func() {
		m.mu.Lock()
		delete(m.running, id)
		m.mu.Unlock()
	}()

	cmd := exec.CommandContext(ctx, script.Command, script.Args...)
	if script.WorkDir != "" {
		cmd.Dir = script.WorkDir
	}

	stdoutPipe, _ := cmd.StdoutPipe()
	stderrPipe, _ := cmd.StderrPipe()

	var stdoutBuf, stderrBuf bytes.Buffer
	start := time.Now()

	if err := cmd.Start(); err != nil {
		return RunResult{}, err
	}

	// Read output in goroutines
	var wg sync.WaitGroup
	wg.Add(2)

	readOutput := func(r io.Reader, stream string, buf *bytes.Buffer) {
		defer wg.Done()
		scanner := bufio.NewScanner(r)
		for scanner.Scan() {
			text := scanner.Text()
			buf.WriteString(text + "\n")
			if onOutput != nil {
				onOutput(OutputChunk{ID: id, Stream: stream, Text: text})
			}
		}
	}

	go readOutput(stdoutPipe, "stdout", &stdoutBuf)
	go readOutput(stderrPipe, "stderr", &stderrBuf)

	err := cmd.Wait()
	wg.Wait()
	dur := time.Since(start).Milliseconds()

	exitCode := 0
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
		} else if ctx.Err() == context.Canceled {
			exitCode = -1 // Indication of manual stop
		} else {
			return RunResult{}, err
		}
	}

	return RunResult{
		ID:       id,
		ExitCode: exitCode,
		Stdout:   stdoutBuf.String(),
		Stderr:   stderrBuf.String(),
		Duration: dur,
	}, nil
}

// DefaultScriptsPath remains the same
func DefaultScriptsPath() string {
	configDir, err := os.UserConfigDir()
	if err != nil {
		configDir = "."
	}
	return filepath.Join(configDir, "linqora", "scripts.json")
}
