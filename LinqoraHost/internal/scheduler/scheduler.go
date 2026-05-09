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
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
)

const maxRuntime = 5 * time.Minute // Increased for more complex tasks

// Script describes a server-registered runnable command.
// Schedule follows a simple syntax: "", "@daily", "@hourly",
// "@every 30m", "@every 2h", or "HH:MM" for a daily fixed time.
type Script struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Description string   `json:"description"`
	Command     string   `json:"command"`
	Args        []string `json:"args,omitempty"`
	WorkDir     string   `json:"work_dir,omitempty"`
	Schedule    string   `json:"schedule,omitempty"`
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

// DefaultScripts returns example scripts appropriate for the current platform.
func DefaultScripts() []Script {
	if runtime.GOOS == "windows" {
		return []Script{
			{ID: "default-sysinfo", Name: "System Info", Description: "Display basic system information", Command: "systeminfo", Args: []string{}},
			{ID: "default-ipconfig", Name: "IP Config", Description: "Show network interfaces", Command: "ipconfig", Args: []string{"/all"}},
			{ID: "default-tasklist", Name: "Task List", Description: "List all running processes", Command: "tasklist", Args: []string{}},
			{ID: "default-whoami", Name: "Who Am I", Description: "Current user and groups", Command: "whoami", Args: []string{"/all"}},
			{ID: "default-diskspace", Name: "Disk Space", Description: "Show disk usage", Command: "wmic", Args: []string{"logicaldisk", "get", "size,freespace,caption"}},
		}
	}
	return []Script{
		{ID: "default-uname", Name: "System Info", Description: "Kernel and OS information", Command: "uname", Args: []string{"-a"}},
		{ID: "default-ifconfig", Name: "Network Info", Description: "Network interfaces", Command: "ip", Args: []string{"addr"}},
		{ID: "default-ps", Name: "Process List", Description: "Running processes (top 20 by CPU)", Command: "sh", Args: []string{"-c", "ps aux --sort=-%cpu | head -21"}},
		{ID: "default-whoami", Name: "Who Am I", Description: "Current user", Command: "whoami", Args: []string{}},
		{ID: "default-df", Name: "Disk Space", Description: "Disk usage summary", Command: "df", Args: []string{"-h"}},
	}
}

// SeedDefaults writes DefaultScripts to the file if the script list is empty.
func (m *Manager) SeedDefaults() {
	m.mu.RLock()
	empty := len(m.scripts) == 0
	m.mu.RUnlock()
	if !empty {
		return
	}
	defaults := DefaultScripts()
	for _, s := range defaults {
		_ = m.Add(s)
	}
}

// DefaultScriptsPath remains the same
func DefaultScriptsPath() string {
	configDir, err := os.UserConfigDir()
	if err != nil {
		configDir = "."
	}
	return filepath.Join(configDir, "linqora", "scripts.json")
}

// ─── Cron engine ─────────────────────────────────────────────────────────────

type triggerKind int

const (
	triggerNone    triggerKind = iota
	triggerDaily               // @daily / @midnight — 00:00 each day
	triggerHourly              // @hourly — :00 of each hour
	triggerEvery               // @every <duration> — interval from epoch
	triggerAtTime              // HH:MM — fixed time each day
)

type parsedSchedule struct {
	kind     triggerKind
	every    time.Duration
	atHour   int
	atMinute int
}

// parseSchedule converts a schedule string into a parsedSchedule.
// Valid formats: "", "@daily", "@midnight", "@hourly",
// "@every 30m", "@every 2h", "09:00".
func parseSchedule(s string) (parsedSchedule, error) {
	if s == "" {
		return parsedSchedule{kind: triggerNone}, nil
	}
	switch s {
	case "@daily", "@midnight":
		return parsedSchedule{kind: triggerDaily}, nil
	case "@hourly":
		return parsedSchedule{kind: triggerHourly}, nil
	}
	if strings.HasPrefix(s, "@every ") {
		raw := strings.TrimPrefix(s, "@every ")
		dur, err := time.ParseDuration(raw)
		if err != nil || dur < time.Minute {
			return parsedSchedule{}, fmt.Errorf("invalid @every duration %q (min 1m)", raw)
		}
		return parsedSchedule{kind: triggerEvery, every: dur}, nil
	}
	// HH:MM format
	parts := strings.SplitN(s, ":", 2)
	if len(parts) == 2 {
		h, err1 := strconv.Atoi(parts[0])
		m, err2 := strconv.Atoi(parts[1])
		if err1 == nil && err2 == nil && h >= 0 && h < 24 && m >= 0 && m < 60 {
			return parsedSchedule{kind: triggerAtTime, atHour: h, atMinute: m}, nil
		}
	}
	return parsedSchedule{}, fmt.Errorf("unrecognised schedule %q", s)
}

func shouldFire(ps parsedSchedule, now time.Time) bool {
	switch ps.kind {
	case triggerNone:
		return false
	case triggerDaily:
		return now.Hour() == 0 && now.Minute() == 0
	case triggerHourly:
		return now.Minute() == 0
	case triggerEvery:
		intervalMin := int64(ps.every / time.Minute)
		if intervalMin == 0 {
			return false
		}
		totalMin := now.Unix() / 60
		return totalMin%intervalMin == 0
	case triggerAtTime:
		return now.Hour() == ps.atHour && now.Minute() == ps.atMinute
	}
	return false
}

// StartCronLoop starts a background goroutine aligned to whole-minute ticks.
// onTrigger is called (in a new goroutine per script) whenever a schedule fires.
func (m *Manager) StartCronLoop(ctx context.Context, onTrigger func(scriptID string)) {
	go func() {
		for {
			now := time.Now()
			next := now.Truncate(time.Minute).Add(time.Minute)
			select {
			case <-time.After(time.Until(next)):
			case <-ctx.Done():
				return
			}
			m.checkSchedules(time.Now(), onTrigger)
		}
	}()
}

func (m *Manager) checkSchedules(now time.Time, onTrigger func(string)) {
	m.mu.RLock()
	scripts := make([]Script, len(m.scripts))
	copy(scripts, m.scripts)
	m.mu.RUnlock()

	for _, s := range scripts {
		if s.Schedule == "" {
			continue
		}
		ps, err := parseSchedule(s.Schedule)
		if err != nil {
			slog.Warn("Invalid script schedule", "id", s.ID, "schedule", s.Schedule, "err", err)
			continue
		}
		if shouldFire(ps, now) {
			id := s.ID
			go onTrigger(id)
		}
	}
}
