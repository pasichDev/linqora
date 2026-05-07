package filebrowser

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// FileInfo represents a single file or directory on the host system.
type FileInfo struct {
	Name    string    `json:"name"`
	Size    int64     `json:"size"`
	IsDir   bool      `json:"is_dir"`
	ModTime time.Time `json:"mod_time"`
}

// validatePath resolves the requested path to an absolute path and verifies that
// it stays within root, preventing path traversal attacks.
func validatePath(root, requested string) (string, error) {
	absRoot, err := filepath.Abs(root)
	if err != nil {
		return "", fmt.Errorf("invalid root path: %w", err)
	}

	absRequested, err := filepath.Abs(requested)
	if err != nil {
		return "", fmt.Errorf("invalid requested path: %w", err)
	}

	clean := filepath.Clean(absRequested)

	// Ensure the clean path starts with root (add separator to avoid partial matches)
	if !strings.HasPrefix(clean, absRoot+string(filepath.Separator)) && clean != absRoot {
		return "", fmt.Errorf("path %q escapes the allowed root %q", requested, root)
	}

	return clean, nil
}

// ListDir returns a list of files and directories at the specified path.
func ListDir(path string) ([]FileInfo, error) {
	if path == "" {
		path = GetHomeDir()
	}

	clean, err := validatePath(GetHomeDir(), path)
	if err != nil {
		return nil, err
	}

	entries, err := os.ReadDir(clean)
	if err != nil {
		return nil, fmt.Errorf("failed to read directory: %w", err)
	}

	var list []FileInfo
	for _, entry := range entries {
		info, err := entry.Info()
		if err != nil {
			continue
		}
		list = append(list, FileInfo{
			Name:    entry.Name(),
			Size:    info.Size(),
			IsDir:   entry.IsDir(),
			ModTime: info.ModTime(),
		})
	}

	return list, nil
}

// ReadFile returns the contents of a file.
func ReadFile(path string) ([]byte, error) {
	clean, err := validatePath(GetHomeDir(), path)
	if err != nil {
		return nil, err
	}
	return os.ReadFile(clean)
}

// WriteFile writes data to a file.
func WriteFile(path string, data []byte) error {
	clean, err := validatePath(GetHomeDir(), path)
	if err != nil {
		return err
	}

	// Ensure parent directory exists
	dir := filepath.Dir(clean)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create directory: %w", err)
	}

	return os.WriteFile(clean, data, 0644)
}

// DeleteFile removes a file or directory.
func DeleteFile(path string) error {
	clean, err := validatePath(GetHomeDir(), path)
	if err != nil {
		return err
	}
	return os.RemoveAll(clean)
}

// GetHomeDir returns the user's home directory.
func GetHomeDir() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return "."
	}
	return home
}
