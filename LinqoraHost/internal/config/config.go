package config

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
)

const (
	ConfigFileName = "linqora/linqora_config.json"
)

// ServerConfig stores the configuration for the Linqora Host server.
// All fields have explicit json tags so the config file is readable when
// edited manually and is forward-compatible with external tooling.
type ServerConfig struct {
	Port           int                   `json:"port"`
	AuthorizedDevs map[string]DeviceAuth `json:"authorized_devs"`
	EnableTLS      bool                  `json:"enable_tls"`
	CertFile       string                `json:"cert_file"`
	KeyFile        string                `json:"key_file"`
	// SharedSecret enables HMAC-SHA256 challenge-response authentication.
	// Empty string = disabled (fallback to manual approval flow).
	SharedSecret string `json:"shared_secret,omitempty"`
}

// DeviceAuth stores information about an authorised device.
type DeviceAuth struct {
	DeviceName string `json:"device_name"`
	DeviceID   string `json:"device_id"`
	LastAuth   string `json:"last_auth"`
}

// DefaultConfig returns default configuration for the server.
func DefaultConfig() *ServerConfig {
	return &ServerConfig{
		Port:           8070,
		AuthorizedDevs: make(map[string]DeviceAuth),
	}
}

// getConfigPath returns the full path to the config file and ensures the
// parent directory exists.
func getConfigPath() string {
	configDir, err := os.UserConfigDir()
	if err != nil {
		configDir = "."
	}

	linqoraDir := filepath.Join(configDir, "linqora")
	if err := os.MkdirAll(linqoraDir, 0755); err != nil {
		log.Printf("Failed to create config dir: %v", err)
		return filepath.Join(".", "linqora_config.json")
	}

	return filepath.Join(linqoraDir, "linqora_config.json")
}

// SaveConfig saves the current configuration to a file.
func (c *ServerConfig) SaveConfig() error {
	data, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal config: %w", err)
	}

	configPath := getConfigPath()
	if err := os.WriteFile(configPath, data, 0644); err != nil {
		return fmt.Errorf("failed to write config file: %w", err)
	}

	return nil
}

// LoadConfig loads configuration from file, creating a default one if absent.
func LoadConfig() (*ServerConfig, error) {
	config := DefaultConfig()
	configPath := getConfigPath()

	if _, err := os.Stat(configPath); err == nil {
		data, err := os.ReadFile(configPath)
		if err != nil {
			return config, fmt.Errorf("failed to read config file: %w", err)
		}

		if err := json.Unmarshal(data, config); err != nil {
			return config, fmt.Errorf("failed to parse config file: %w", err)
		}
	} else {
		if err := config.SaveConfig(); err != nil {
			log.Printf("Failed to create initial config: %v", err)
		}
	}

	return config, nil
}
