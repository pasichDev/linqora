package scheduler

import (
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

func TestManagerListEmpty(t *testing.T) {
	m := NewManagerWithScripts(nil)
	if got := m.List(); len(got) != 0 {
		t.Fatalf("expected empty list, got %d scripts", len(got))
	}
}

func TestManagerListReturnsCopy(t *testing.T) {
	scripts := []Script{{ID: "s1", Name: "Script 1", Command: "echo"}}
	m := NewManagerWithScripts(scripts)

	list := m.List()
	list[0].Name = "Modified"

	if m.scripts[0].Name == "Modified" {
		t.Fatal("List should return a copy, not a reference to internal slice")
	}
}

func TestManagerExecuteUnknown(t *testing.T) {
	m := NewManagerWithScripts(nil)
	_, err := m.Execute("does-not-exist")
	if err == nil {
		t.Fatal("expected error for unknown script id")
	}
}

func TestManagerExecuteSimple(t *testing.T) {
	cmd := "true"
	if runtime.GOOS == "windows" {
		cmd = "cmd"
	}
	args := []string{}
	if runtime.GOOS == "windows" {
		args = []string{"/C", "exit 0"}
	}

	m := NewManagerWithScripts([]Script{
		{ID: "noop", Name: "No-op", Command: cmd, Args: args},
	})

	result, err := m.Execute("noop")
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	if result.ID != "noop" {
		t.Errorf("expected id %q, got %q", "noop", result.ID)
	}
	if result.ExitCode != 0 {
		t.Errorf("expected exit code 0, got %d", result.ExitCode)
	}
}

func TestNewManagerLoadsFromFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "scripts.json")

	content := `[{"id":"s1","name":"Echo","command":"echo","args":["hello"]}]`
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}

	m := NewManager(path)
	list := m.List()
	if len(list) != 1 {
		t.Fatalf("expected 1 script, got %d", len(list))
	}
	if list[0].ID != "s1" {
		t.Errorf("expected id %q, got %q", "s1", list[0].ID)
	}
}

func TestNewManagerMissingFile(t *testing.T) {
	m := NewManager("/nonexistent/path/scripts.json")
	if got := m.List(); len(got) != 0 {
		t.Fatalf("expected empty list for missing file, got %d", len(got))
	}
}
