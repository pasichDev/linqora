package config

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
)

const (
	// Name and folder for the configuration file
	ConfigFileName = "linqora/linqora_config.json"
)

// ServerConfig stores the configuration for the Linqora Host server
type ServerConfig struct {
	Port           int                   // Port ws server
	AuthorizedDevs map[string]DeviceAuth // Auth devices

	EnableTLS bool   // Enable TLS
	CertFile  string // Path to the TLS certificate file
	KeyFile   string // Path to the TLS key file
}

// DeviceAuth зберігає інформацію про авторизовані пристрої
type DeviceAuth struct {
	DeviceName string `json:"device_name"`
	DeviceID   string `json:"device_id"`
	LastAuth   string `json:"last_auth"`
}

// Get returns default configuration for the server
func DefaultConfig() *ServerConfig {
	return &ServerConfig{
		Port:           8070,
		AuthorizedDevs: make(map[string]DeviceAuth),
	}
}

// Get Directory for the configuration file
func getConfigDir() string {
	configDir, err := os.UserConfigDir()
	if err != nil {
		configDir = "."
	}

	linqoraDir := filepath.Join(configDir, "linqora")
	if err := os.MkdirAll(linqoraDir, 0755); err != nil {
		log.Printf("Failed to create config dir: %v", err)
		linqoraDir = "."
	}

	return filepath.Join(configDir, ConfigFileName)
}

// SaveConfig saves the current configuration to a file
func (c *ServerConfig) SaveConfig() error {
	data, err := json.MarshalIndent(c, "", "  ")
	configPath := getConfigDir()
	if err != nil {
		return fmt.Errorf("failed to marshal config: %w", err)
	}

	if err := os.WriteFile(configPath, data, 0644); err != nil {
		return fmt.Errorf("failed to write config file: %w", err)
	}

	return nil
}

// Load configuration from file
func LoadConfig() (*ServerConfig, error) {
	config := DefaultConfig()
	configPath := getConfigDir()
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
