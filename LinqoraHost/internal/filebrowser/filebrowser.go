package filebrowser

import (
	"fmt"
	"os"
	"path/filepath"
	"time"
)

// FileInfo represents a single file or directory on the host system.
type FileInfo struct {
	Name    string    `json:"name"`
	Size    int64     `json:"size"`
	IsDir   bool      `json:"is_dir"`
	ModTime time.Time `json:"mod_time"`
}

// ListDir returns a list of files and directories at the specified path.
func ListDir(path string) ([]FileInfo, error) {
	if path == "" {
		path = "."
	}

	entries, err := os.ReadDir(path)
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
	return os.ReadFile(path)
}

// WriteFile writes data to a file.
func WriteFile(path string, data []byte) error {
	// Ensure parent directory exists
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create directory: %w", err)
	}

	return os.WriteFile(path, data, 0644)
}

// DeleteFile removes a file or directory.
func DeleteFile(path string) error {
	return os.RemoveAll(path)
}

// GetHomeDir returns the user's home directory.
func GetHomeDir() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return "."
	}
	return home
}
