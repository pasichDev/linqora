package certutils

import (
	"embed"
	"log/slog"
	"os"
	"path/filepath"
)

//go:embed certificates
var embeddedCerts embed.FS

// Extracts certificates embedded by the developer
func EnsureCertsExist() (bool, error) {

	slog.Info("TLS certificates not found at specified paths, extracting embedded certificates...")

	// Create a directory for certificates
	certDir := filepath.Dir("./certificates/")
	if err := os.MkdirAll(certDir, 0755); err != nil {
		slog.Error("Failed to create certificates directory", "err", err)
		return false, err
	}

	// Retrieve the certificate
	if err := extractEmbeddedFile("certificates/dev_cert.pem", "./certificates/dev_cert.pem"); err != nil {
		slog.Error("Failed to extract certificate", "err", err)

		return false, err
	}

	// Retrieve the key
	if err := extractEmbeddedFile("certificates/dev_key.pem", "./certificates/dev_key.pem"); err != nil {
		slog.Error("Failed to extract key", "err", err)
		return false, err
	}

	slog.Info("TLS certificates successfully extracted, TLS enabled")
	return true, nil
}

// Retrieving a file from embedded resources
func extractEmbeddedFile(embedPath, outputPath string) error {
	data, err := embeddedCerts.ReadFile(embedPath)
	if err != nil {
		return err
	}

	// Use 0600 so that private key files are readable only by the owner.
	// 0644 would allow any local user to read the key and perform MITM attacks.
	return os.WriteFile(outputPath, data, 0600)
}

// Check if certificates are available at the paths specified in the configuration
func UserCertExists(cert string, key string) bool {
	certExists := fileExists(cert)
	keyExists := fileExists(key)

	if certExists && keyExists {
		return true
	}

	return false
}

// Check if the file exists
func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
