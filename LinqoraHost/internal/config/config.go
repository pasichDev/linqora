package config

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"
)

// ServerConfig містить конфігурацію сервера
type ServerConfig struct {
	Port            int                   // Порт для WebSocket сервера
	MDNSDomain      string                // Домен mDNS сервісу
	AuthorizedDevs  map[string]DeviceAuth // Авторизовані пристрої
	ValidDeviceIDs  map[string]bool       // Список разрешенных DeviceID
	MetricsInterval time.Duration         // Інтервал надсилання метрик
	MediasInterval  time.Duration         // Інтервал надсилання медіа
	ConfigPath      string                // Путь к файлу конфигурации

	EnableTLS bool   // Включити TLS
	CertFile  string // Шлях до файлу сертифікату
	KeyFile   string // Шлях до файлу ключа
}

// DeviceAuth содержит информацию об авторизованном устройстве
type DeviceAuth struct {
	DeviceName string    `json:"device_name"` // Имя устройства
	DeviceID   string    `json:"device_id"`   // Уникальный ID устройства
	LastAuth   time.Time `json:"last_auth"`   // Время последней авторизации
}

// DefaultConfig повертає конфігурацію за замовчуванням
func DefaultConfig() *ServerConfig {
	// Путь к файлу конфигурации
	configDir := getConfigDir()
	configPath := filepath.Join(configDir, "linqora_config.json")

	return &ServerConfig{
		Port:            8070,
		MDNSDomain:      "local.",
		AuthorizedDevs:  make(map[string]DeviceAuth),
		ValidDeviceIDs:  make(map[string]bool), // Новое поле
		MetricsInterval: 2 * time.Second,
		MediasInterval:  2 * time.Second,
		ConfigPath:      configPath,
	}
}

// Получение директории для конфигурации
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

	return linqoraDir
}

// SaveConfig сохраняет конфигурацию в файл
func (c *ServerConfig) SaveConfig() error {
	data, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal config: %w", err)
	}

	if err := os.WriteFile(c.ConfigPath, data, 0644); err != nil {
		return fmt.Errorf("failed to write config file: %w", err)
	}

	return nil
}

// LoadConfig загружает конфигурацию из файла
func LoadConfig() (*ServerConfig, error) {
	config := DefaultConfig()

	// Если файл конфигурации существует, загружаем его
	if _, err := os.Stat(config.ConfigPath); err == nil {
		data, err := os.ReadFile(config.ConfigPath)
		if err != nil {
			return config, fmt.Errorf("failed to read config file: %w", err)
		}

		if err := json.Unmarshal(data, config); err != nil {
			return config, fmt.Errorf("failed to parse config file: %w", err)
		}
	} else {
		// Если файл не существует, создаем его
		if err := config.SaveConfig(); err != nil {
			log.Printf("Failed to create initial config: %v", err)
		}
	}

	return config, nil
}
