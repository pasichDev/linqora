package config

import (
	"embed"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
)

//go:embed certificates
var embeddedCerts embed.FS

const (
	// ConfigFileName ім'я файлу конфігурації
	ConfigFileName = "linqora/linqora_config.json"
)

// ServerConfig містить конфігурацію сервера
type ServerConfig struct {
	Port           int                   // Порт для WebSocket сервера
	AuthorizedDevs map[string]DeviceAuth // Авторизовані пристрої

	EnableTLS bool   // Включити TLS
	CertFile  string // Шлях до файлу сертифікату
	KeyFile   string // Шлях до файлу ключа
}

// DeviceAuth зберігає інформацію про авторизовані пристрої
type DeviceAuth struct {
	DeviceName string `json:"device_name"` // Ім'я пристрою
	DeviceID   string `json:"device_id"`   // Унікальний ідентифікатор пристрою
	LastAuth   string `json:"last_auth"`   // Час останньої авторизації
}

// DefaultConfig повертає конфігурацію за замовчуванням
func DefaultConfig() *ServerConfig {

	return &ServerConfig{
		Port:           8070,
		AuthorizedDevs: make(map[string]DeviceAuth),
	}
}

// Отримання директорії для конфігурації
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

// SaveConfig зберігає конфігурацію у файл
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

// LoadConfig завантажує конфігурацію з файлу
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

// EnsureCertsExist проверяет наличие сертификатов и извлекает их из встроенных данных при необходимости
func (c *ServerConfig) EnsureCertsExist() {
	// Проверяем наличие сертификатов по указанным в конфигурации путям
	certExists := fileExists(c.CertFile)
	keyExists := fileExists(c.KeyFile)

	// Если оба файла существуют, ничего делать не нужно
	if certExists && keyExists {
		return
	}

	log.Println("TLS certificates not found at specified paths, extracting embedded certificates...")

	// Создаем директорию для сертификатов
	certDir := filepath.Dir(c.CertFile)
	if err := os.MkdirAll(certDir, 0755); err != nil {
		log.Printf("Failed to create certificates directory: %v", err)
		c.EnableTLS = false
		return
	}

	// Извлекаем сертификат
	if !certExists {
		if err := extractEmbeddedFile("certificates/dev_cert.pem", c.CertFile); err != nil {
			log.Printf("Failed to extract certificate: %v", err)
			c.EnableTLS = false
			return
		}
		log.Printf("Certificate extracted to %s", c.CertFile)
	}

	// Извлекаем ключ
	if !keyExists {
		if err := extractEmbeddedFile("certificates/dev_key.pem", c.KeyFile); err != nil {
			log.Printf("Failed to extract key: %v", err)
			c.EnableTLS = false
			return
		}
		log.Printf("Key extracted to %s", c.KeyFile)
	}

	log.Println("TLS certificates successfully extracted, TLS enabled")
	c.EnableTLS = true
}

// Извлечение файла из встроенных ресурсов
func extractEmbeddedFile(embedPath, outputPath string) error {
	data, err := embeddedCerts.ReadFile(embedPath)
	if err != nil {
		return err
	}

	return os.WriteFile(outputPath, data, 0644)
}

// Проверка существования файла
func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
