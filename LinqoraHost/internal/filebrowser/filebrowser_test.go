package filebrowser

import (
	"os"
	"path/filepath"
	"testing"
)

func TestFileOperations(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "filebrowser-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	testFile := filepath.Join(tmpDir, "test.txt")
	content := []byte("hello world")

	// Test Write
	err = WriteFile(testFile, content)
	if err != nil {
		t.Fatalf("WriteFile failed: %v", err)
	}

	// Test Read
	readContent, err := ReadFile(testFile)
	if err != nil {
		t.Fatalf("ReadFile failed: %v", err)
	}
	if string(readContent) != string(content) {
		t.Errorf("Expected %s, got %s", content, readContent)
	}

	// Test ListDir
	list, err := ListDir(tmpDir)
	if err != nil {
		t.Fatalf("ListDir failed: %v", err)
	}
	if len(list) != 1 {
		t.Errorf("Expected 1 file in list, got %d", len(list))
	}
	if list[0].Name != "test.txt" {
		t.Errorf("Expected name test.txt, got %s", list[0].Name)
	}
}

func TestListNonExistentDir(t *testing.T) {
	_, err := ListDir("/non/existent/path/linqora/test")
	if err == nil {
		t.Error("Listing non-existent directory should fail")
	}
}
